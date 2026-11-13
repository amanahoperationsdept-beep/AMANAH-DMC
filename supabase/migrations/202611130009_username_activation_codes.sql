-- AMANAH username registration and one-time activation codes
begin;

alter table public.profiles add column if not exists username text;
create unique index if not exists profiles_username_lower_uidx
  on public.profiles (lower(username)) where username is not null;

create table if not exists public.activation_codes (
  id uuid primary key default gen_random_uuid(),
  code_hash text not null unique,
  batch_id uuid not null,
  created_by uuid not null references auth.users(id),
  expires_at timestamptz not null,
  used_at timestamptz,
  used_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
alter table public.activation_codes enable row level security;
revoke all on public.activation_codes from anon, authenticated;
grant all on public.activation_codes to service_role;

create or replace function public.consume_amanah_activation_code(p_code_hash text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare v_id uuid;
begin
  update public.activation_codes
     set used_at = now()
   where code_hash = p_code_hash
     and used_at is null
     and expires_at > now()
  returning id into v_id;
  return v_id is not null;
end;
$$;
revoke all on function public.consume_amanah_activation_code(text) from public, anon, authenticated;
grant execute on function public.consume_amanah_activation_code(text) to service_role;

-- Store username in the profile created by the existing Auth trigger.
create or replace function public.handle_new_amanah_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sponsor_id uuid;
  v_sponsor_code text;
begin
  v_sponsor_code := nullif(trim(new.raw_user_meta_data ->> 'sponsor_code'), '');
  if v_sponsor_code is not null then
    select id into v_sponsor_id
    from public.profiles
    where member_code = v_sponsor_code and is_active = true
    limit 1;
    if v_sponsor_id is null then
      raise exception 'Active sponsor code not found';
    end if;
  end if;

  insert into public.profiles (id, full_name, phone, member_code, role, sponsor_id, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.phone, new.raw_user_meta_data ->> 'phone'),
    'AM-' || upper(substr(replace(new.id::text, '-', ''), 1, 8)),
    'distributor',
    v_sponsor_id,
    lower(nullif(trim(new.raw_user_meta_data ->> 'username'), ''))
  )
  on conflict (id) do update
    set username = coalesce(excluded.username, public.profiles.username);
  insert into public.wallets(member_id) values(new.id) on conflict do nothing;
  return new;
end;
$$;

commit;

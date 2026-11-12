-- Secure public distributor applications and administrator review.
-- Apply after 0001_initial_schema.sql and 0002_secure_monthly_closing.sql.

create table public.member_review_events (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id) on delete restrict,
  reviewer_id uuid not null references public.profiles(id) on delete restrict,
  decision text not null check (decision in ('approved', 'rejected')),
  previous_status public.member_status not null,
  new_status public.member_status not null,
  note text check (note is null or char_length(note) <= 1000),
  created_at timestamptz not null default now()
);
create unique index profiles_member_code_upper_uidx
  on public.profiles (pg_catalog.upper(member_code));

create index member_review_events_member_created_idx
  on public.member_review_events(member_id, created_at desc);
alter table public.member_review_events enable row level security;
create policy "member review events read own or admin"
  on public.member_review_events for select
  using (member_id = auth.uid() or public.is_admin());
revoke all on table public.member_review_events from anon, authenticated;
grant select on table public.member_review_events to authenticated;

create or replace function public.is_active_distributor_sponsor(p_member_code text)
returns boolean
language sql stable security definer set search_path = ''
as $
  select exists (
    select 1
    from public.profiles p
    where p_member_code is not null
      and pg_catalog.char_length(pg_catalog.btrim(p_member_code)) between 1 and 32
      and pg_catalog.upper(p.member_code) = pg_catalog.upper(pg_catalog.btrim(p_member_code))
      and p.role = 'distributor' and p.status = 'active'
  );
$;
revoke all on function public.is_active_distributor_sponsor(text) from public, anon, authenticated;
grant execute on function public.is_active_distributor_sponsor(text) to anon, authenticated;

-- Only marked public distributor signups are handled. Admins provisioned manually
-- in Supabase Auth are untouched. The client cannot select role/status/member code/sponsor UUID.
create or replace function public.handle_amanah_distributor_signup()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v_requested boolean;
  v_full_name text;
  v_phone text;
  v_sponsor_code text;
  v_sponsor_id uuid;
  v_member_code text;
  v_inserted_id uuid;
begin
  v_requested := coalesce(new.raw_user_meta_data ->> 'amanah_distributor_signup', 'false') = 'true';
  if not v_requested then return new; end if;

  if exists (select 1 from public.profiles p where p.id = new.id) then
    raise exception 'An AMANAH profile already exists for this account';
  end if;

  v_full_name := pg_catalog.btrim(coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  v_phone := nullif(pg_catalog.btrim(coalesce(new.raw_user_meta_data ->> 'phone', '')), '');
  v_sponsor_code := pg_catalog.upper(pg_catalog.btrim(coalesce(new.raw_user_meta_data ->> 'sponsor_code', '')));

  if pg_catalog.char_length(v_full_name) < 2 or pg_catalog.char_length(v_full_name) > 120 then
    raise exception 'A valid full name is required';
  end if;
  if v_phone is not null and pg_catalog.char_length(v_phone) > 40 then
    raise exception 'Phone number is too long';
  end if;
  if v_sponsor_code = '' or pg_catalog.char_length(v_sponsor_code) > 32 then
    raise exception 'An active distributor sponsor code is required';
  end if;

  -- Lock sponsor while validating status and creating the genealogy edge.
  select p.id into v_sponsor_id
  from public.profiles p
  where pg_catalog.upper(p.member_code) = v_sponsor_code
    and p.role = 'distributor' and p.status = 'active'
  for update;

  if v_sponsor_id is null then
    raise exception 'Sponsor code is invalid or the sponsor is not active';
  end if;

  loop
    v_member_code := 'AMN-' || pg_catalog.upper(
      pg_catalog.substr(pg_catalog.replace(gen_random_uuid()::text, '-', ''), 1, 10)
    );
    insert into public.profiles(id, member_code, full_name, phone, role, status, sponsor_id)
    values (new.id, v_member_code, v_full_name, v_phone, 'distributor', 'pending', v_sponsor_id)
    on conflict (member_code) do nothing
    returning id into v_inserted_id;
    exit when v_inserted_id is not null;
  end loop;

  insert into public.genealogy(ancestor_id, descendant_id, depth)
  values (new.id, new.id, 0);

  insert into public.genealogy(ancestor_id, descendant_id, depth)
  select g.ancestor_id, new.id, g.depth + 1
  from public.genealogy g
  where g.descendant_id = v_sponsor_id and g.depth < 32767;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_amanah_distributor on auth.users;
create trigger on_auth_user_created_amanah_distributor
  after insert on auth.users
  for each row execute function public.handle_amanah_distributor_signup();
revoke all on function public.handle_amanah_distributor_signup() from public, anon, authenticated;

-- Retire the older RPC that let an authenticated user choose a member code and sponsor UUID.
revoke all on function public.register_member(text, text, text, uuid)
  from public, anon, authenticated;

create or replace function public.review_member_application(
  p_member_id uuid, p_decision text, p_note text default null
)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  v_reviewer_id uuid := auth.uid();
  v_member public.profiles%rowtype;
  v_new_status public.member_status;
  v_decision text;
  v_note text;
begin
  if v_reviewer_id is null or not public.is_admin() then
    raise exception 'Active administrator permission required';
  end if;
  if p_member_id is null then raise exception 'A member ID is required'; end if;

  v_decision := pg_catalog.lower(pg_catalog.btrim(coalesce(p_decision, '')));
  v_note := nullif(pg_catalog.btrim(coalesce(p_note, '')), '');
  if v_decision not in ('approve', 'reject') then
    raise exception 'Decision must be approve or reject';
  end if;
  if v_note is not null and pg_catalog.char_length(v_note) > 1000 then
    raise exception 'Review note is too long';
  end if;

  select p.* into v_member
  from public.profiles p where p.id = p_member_id for update;
  if not found then raise exception 'Distributor application not found'; end if;
  if v_member.id = v_reviewer_id then
    raise exception 'An administrator cannot review their own account';
  end if;
  if v_member.role <> 'distributor' or v_member.status <> 'pending' then
    raise exception 'Only pending distributor applications can be reviewed';
  end if;

  if v_decision = 'approve' then
    if not exists (
      select 1 from auth.users u
      where u.id = p_member_id and u.email_confirmed_at is not null
    ) then
      raise exception 'The applicant must verify their email before approval';
    end if;
    v_new_status := 'active';
  else
    -- The review event records the explicit rejection; closed remains the profile status.
    v_new_status := 'closed';
  end if;

  update public.profiles set status = v_new_status, updated_at = now()
  where id = p_member_id;

  insert into public.member_review_events(
    member_id, reviewer_id, decision, previous_status, new_status, note
  )
  values (
    p_member_id, v_reviewer_id,
    case when v_decision = 'approve' then 'approved' else 'rejected' end,
    v_member.status, v_new_status, v_note
  );
end;
$$;
revoke all on function public.review_member_application(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.review_member_application(uuid, text, text)
  to authenticated;

comment on function public.is_active_distributor_sponsor(text) is
  'Returns only a boolean for an active distributor sponsor code; no profile details are exposed.';
comment on function public.handle_amanah_distributor_signup() is
  'Creates a pending distributor profile and genealogy rows from validated Auth metadata.';
comment on function public.review_member_application(uuid, text, text) is
  'Admin-only, email-verified approval/rejection with an append-only review event.';

-- AMANAH no-SMS username authentication
-- Synthetic internal email identities; members continue to sign in with usernames.
begin;

create or replace function public.consume_amanah_activation_code(
  p_code_hash text,
  p_user_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare v_id uuid;
begin
  update public.activation_codes
     set used_at = now(),
         used_by = p_user_id
   where code_hash = p_code_hash
     and used_at is null
     and expires_at > now()
  returning id into v_id;
  return v_id is not null;
end;
$$;

revoke all on function public.consume_amanah_activation_code(text, uuid) from public, anon, authenticated;
grant execute on function public.consume_amanah_activation_code(text, uuid) to service_role;

commit;

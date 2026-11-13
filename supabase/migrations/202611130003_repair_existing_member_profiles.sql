-- Repair AMANAH Auth users that existed before the profile trigger was installed.
-- Apply ONLY to Supabase project bqgxvnrgjmngezknqhsl.
-- Existing profiles and their roles are preserved; only missing profiles are created.
begin;

insert into public.profiles (id, full_name, phone, member_code, role, is_active)
select
  u.id,
  coalesce(nullif(u.raw_user_meta_data ->> 'full_name', ''), ''),
  nullif(u.raw_user_meta_data ->> 'phone', ''),
  'AM-' || upper(substr(replace(u.id::text, '-', ''), 1, 8)),
  'distributor'::public.amanah_role,
  true
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null
on conflict (id) do nothing;

insert into public.wallets (member_id)
select p.id
from public.profiles p
left join public.wallets w on w.member_id = p.id
where w.member_id is null
on conflict (member_id) do nothing;

commit;

-- Verification: should return 0 for missing profiles and missing wallets.
select
  (select count(*) from auth.users u
   left join public.profiles p on p.id = u.id
   where p.id is null) as users_without_profiles,
  (select count(*) from public.profiles p
   left join public.wallets w on w.member_id = p.id
   where w.member_id is null) as profiles_without_wallets;

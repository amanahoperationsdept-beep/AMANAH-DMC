-- AMANAH PV-based 10-level Unilevel + genealogy
-- Apply only to Supabase project bqgxvnrgjmngezknqhsl.
-- Commissions are recorded as PENDING only after an order is marked COMPLETED.
-- This migration does not credit wallets or implement JMO/SMO qualification.

alter table public.products
  add column if not exists point_value numeric(10,2) not null default 0
  check (point_value >= 0);

update public.products
set point_value = case
  when lower(name) like '%spirulina%' then 20
  when lower(name) like '%serpentina%' then 25
  when lower(name) like '%glutagen%' then 25
  when lower(name) like '%herbal oil%' then 15
  when lower(name) like '%herbal rub%' then 10
  when lower(name) like '%baskug%' then 20
  when lower(name) like '%barakah%' then 20
  when lower(name) like '%max% c%pro%' or lower(name) like '%maxcpro%' then 50
  else point_value
end
where lower(name) like '%spirulina%'
   or lower(name) like '%serpentina%'
   or lower(name) like '%glutagen%'
   or lower(name) like '%herbal oil%'
   or lower(name) like '%herbal rub%'
   or lower(name) like '%baskug%'
   or lower(name) like '%barakah%'
   or lower(name) like '%max% c%pro%'
   or lower(name) like '%maxcpro%';

-- Store rates as percentage numbers: 12.5 means 12.5%, not 0.125%.
update public.commission_rules
set is_active = false
where commission_type = 'unilevel';

insert into public.commission_rules
  (rule_name, commission_type, level_number, rate, is_active)
values
  ('PV Unilevel Level 1', 'unilevel', 1, 12.5, true),
  ('PV Unilevel Level 2', 'unilevel', 2, 12.5, true),
  ('PV Unilevel Level 3', 'unilevel', 3, 12.5, true),
  ('PV Unilevel Level 4', 'unilevel', 4, 12.5, true),
  ('PV Unilevel Level 5', 'unilevel', 5, 12.5, true),
  ('PV Unilevel Level 6', 'unilevel', 6, 7.5, true),
  ('PV Unilevel Level 7', 'unilevel', 7, 7.5, true),
  ('PV Unilevel Level 8', 'unilevel', 8, 7.5, true),
  ('PV Unilevel Level 9', 'unilevel', 9, 7.5, true),
  ('PV Unilevel Level 10', 'unilevel', 10, 7.5, true);

create unique index if not exists commissions_order_beneficiary_level_type_uidx
  on public.commissions(order_id, beneficiary_id, level_number, commission_type)
  where order_id is not null and level_number is not null;

create or replace function public.get_my_genealogy(p_root_member_id uuid default null)
returns table (
  level_number integer,
  member_id uuid,
  member_code text,
  full_name text,
  role public.amanah_role,
  sponsor_id uuid,
  is_active boolean,
  joined_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_root uuid := coalesce(p_root_member_id, auth.uid());
begin
  if auth.uid() is null then
    raise exception 'Sign in is required.';
  end if;
  if v_root is null then
    raise exception 'A genealogy root member is required.';
  end if;
  if v_root <> auth.uid() and not public.is_amanah_admin() then
    raise exception 'You may view only your own genealogy.';
  end if;

  return query
  with recursive tree as (
    select p.id, p.member_code, p.full_name, p.role, p.sponsor_id,
           p.is_active, p.created_at, 1 as depth, array[p.id] as visited
    from public.profiles p
    where p.sponsor_id = v_root
    union all
    select child.id, child.member_code, child.full_name, child.role,
           child.sponsor_id, child.is_active, child.created_at,
           parent.depth + 1, parent.visited || child.id
    from public.profiles child
    join tree parent on child.sponsor_id = parent.id
    where parent.depth < 10
      and not child.id = any(parent.visited)
  )
  select tree.depth, tree.id, tree.member_code, tree.full_name, tree.role,
         tree.sponsor_id, tree.is_active, tree.created_at
  from tree
  order by tree.depth, tree.created_at, tree.full_name;
end;
$$;

revoke all on function public.get_my_genealogy(uuid) from public;
revoke all on function public.get_my_genealogy(uuid) from anon;
grant execute on function public.get_my_genealogy(uuid) to authenticated;

create or replace function public.record_unilevel_pv_commissions()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.status = 'completed'
     and old.status is distinct from 'completed' then
    insert into public.commissions (
      order_id, source_member_id, beneficiary_id, level_number,
      commission_type, basis_amount, rate, amount, status
    )
    with recursive uplines as (
      select p.sponsor_id as member_id, 1 as depth,
             array[new.buyer_id, p.sponsor_id] as visited
      from public.profiles p
      where p.id = new.buyer_id and p.sponsor_id is not null
      union all
      select parent.sponsor_id, u.depth + 1,
             u.visited || parent.sponsor_id
      from uplines u
      join public.profiles parent on parent.id = u.member_id
      where u.depth < 10
        and parent.sponsor_id is not null
        and not parent.sponsor_id = any(u.visited)
    ),
    order_pv as (
      select coalesce(sum(oi.quantity * p.point_value), 0)::numeric(12,2) as pv
      from public.order_items oi
      join public.products p on p.id = oi.product_id
      where oi.order_id = new.id
    )
    select new.id, new.buyer_id, u.member_id, u.depth,
           'unilevel', op.pv, cr.rate,
           round(op.pv * cr.rate / 100.0, 2), 'pending'
    from uplines u
    cross join order_pv op
    join public.commission_rules cr
      on cr.commission_type = 'unilevel'
     and cr.level_number = u.depth
     and cr.is_active = true
    join public.profiles beneficiary
      on beneficiary.id = u.member_id and beneficiary.is_active = true
    where op.pv > 0
    on conflict do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists orders_record_unilevel_pv_commissions on public.orders;
create trigger orders_record_unilevel_pv_commissions
after update of status on public.orders
for each row
execute function public.record_unilevel_pv_commissions();

comment on column public.products.point_value is
  'AMANAH product PV. One PV is equivalent to PHP 1 for Unilevel commission calculations.';
comment on function public.get_my_genealogy(uuid) is
  'Returns the signed-in member downline through 10 sponsor levels; administrators may specify another root member.';

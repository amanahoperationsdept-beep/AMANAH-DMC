-- Unilevel Network Management System
-- Initial Supabase/PostgreSQL schema.
-- Apply in a new Supabase project using the SQL Editor or Supabase CLI.
-- IMPORTANT: commission posting is intentionally not exposed to browser clients.

create extension if not exists pgcrypto;

create type public.member_role as enum ('admin', 'distributor');
create type public.member_status as enum ('pending', 'active', 'suspended', 'closed');
create type public.order_status as enum ('draft', 'pending_payment', 'paid', 'cancelled', 'refunded');
create type public.commission_run_status as enum ('draft', 'approved', 'posted', 'void');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  member_code text not null unique,
  full_name text not null,
  phone text,
  role public.member_role not null default 'distributor',
  status public.member_status not null default 'pending',
  sponsor_id uuid references public.profiles(id) on delete restrict,
  joined_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint no_self_sponsor check (sponsor_id is null or sponsor_id <> id)
);

create index profiles_sponsor_idx on public.profiles(sponsor_id);
create index profiles_status_idx on public.profiles(status);

-- Closure table: one row for every ancestor/descendant relationship.
-- depth=0 is the member's self row; direct sponsor is depth=1.
create table public.genealogy (
  ancestor_id uuid not null references public.profiles(id) on delete restrict,
  descendant_id uuid not null references public.profiles(id) on delete restrict,
  depth smallint not null check (depth between 0 and 32767),
  created_at timestamptz not null default now(),
  primary key (ancestor_id, descendant_id),
  constraint genealogy_depth_self check ((ancestor_id = descendant_id and depth = 0)
    or (ancestor_id <> descendant_id and depth > 0))
);
create index genealogy_descendant_depth_idx on public.genealogy(descendant_id, depth);
create index genealogy_ancestor_depth_idx on public.genealogy(ancestor_id, depth);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  sku text not null unique,
  name text not null,
  description text,
  retail_price numeric(14,2) not null check (retail_price >= 0),
  pv numeric(14,2) not null check (pv >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  member_id uuid not null references public.profiles(id) on delete restrict,
  status public.order_status not null default 'draft',
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  total_pv numeric(14,2) not null default 0 check (total_pv >= 0),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index orders_member_paid_idx on public.orders(member_id, paid_at) where status = 'paid';

-- Snapshot product name, unit price and unit PV so later catalog edits
-- cannot rewrite historical sales or commission calculations.
create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  product_name_snapshot text not null,
  quantity integer not null check (quantity > 0),
  unit_price_snapshot numeric(14,2) not null check (unit_price_snapshot >= 0),
  unit_pv_snapshot numeric(14,2) not null check (unit_pv_snapshot >= 0),
  line_total numeric(14,2) generated always as (quantity * unit_price_snapshot) stored,
  line_pv numeric(14,2) generated always as (quantity * unit_pv_snapshot) stored,
  created_at timestamptz not null default now()
);
create index order_items_order_idx on public.order_items(order_id);

create table public.rank_settings (
  id smallint primary key,
  rank_name text not null unique,
  commission_rate numeric(6,5) not null check (commission_rate between 0 and 0.30),
  required_personal_pv numeric(14,2) not null default 0 check (required_personal_pv >= 0),
  required_group_pv numeric(14,2) not null default 0 check (required_group_pv >= 0),
  sort_order smallint not null unique,
  is_active boolean not null default true
);

insert into public.rank_settings
(id, rank_name, commission_rate, required_personal_pv, required_group_pv, sort_order)
values
(0, 'Member',    0.00000,   0,      0,      0),
(1, 'Bronze',    0.05000, 100,    500,      1),
(2, 'Silver',    0.08000, 100,   1500,      2),
(3, 'Gold',      0.11000, 150,   3000,      3),
(4, 'Platinum',  0.14000, 150,   6000,      4),
(5, 'Sapphire',  0.17000, 200,  12000,      5),
(6, 'Ruby',      0.20000, 200,  25000,      6),
(7, 'Emerald',   0.23000, 250,  50000,      7),
(8, 'Diamond',   0.26000, 300, 100000,      8),
(9, 'Crown',     0.30000, 300, 200000,      9);

create table public.monthly_volumes (
  period_month date not null,
  member_id uuid not null references public.profiles(id) on delete restrict,
  personal_pv numeric(14,2) not null default 0 check (personal_pv >= 0),
  group_pv numeric(14,2) not null default 0 check (group_pv >= 0),
  qualified_rank_id smallint not null references public.rank_settings(id),
  qualified_rate numeric(6,5) not null check (qualified_rate between 0 and 0.30),
  calculated_at timestamptz not null default now(),
  primary key (period_month, member_id),
  check (extract(day from period_month) = 1)
);

create table public.commission_runs (
  id uuid primary key default gen_random_uuid(),
  period_month date not null unique,
  status public.commission_run_status not null default 'draft',
  created_by uuid references public.profiles(id),
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  posted_at timestamptz,
  created_at timestamptz not null default now(),
  check (extract(day from period_month) = 1)
);

create table public.commission_ledger (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.commission_runs(id) on delete restrict,
  sale_order_id uuid not null references public.orders(id) on delete restrict,
  beneficiary_id uuid not null references public.profiles(id) on delete restrict,
  source_member_id uuid not null references public.profiles(id) on delete restrict,
  generation smallint not null check (generation between 1 and 10),
  sale_pv numeric(14,2) not null check (sale_pv >= 0),
  pv_conversion numeric(14,2) not null default 1 check (pv_conversion = 1),
  beneficiary_rate numeric(6,5) not null,
  previous_paid_rate numeric(6,5) not null,
  differential_rate numeric(6,5) not null check (differential_rate >= 0),
  commission_amount numeric(14,2) not null check (commission_amount >= 0),
  created_at timestamptz not null default now(),
  unique (run_id, sale_order_id, beneficiary_id)
);
create index commission_ledger_beneficiary_idx on public.commission_ledger(beneficiary_id, created_at);

create table public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id) on delete restrict,
  commission_ledger_id uuid references public.commission_ledger(id) on delete restrict,
  transaction_type text not null check (transaction_type in ('commission_credit','adjustment_credit','adjustment_debit','payout_debit','reversal')),
  amount numeric(14,2) not null check (amount <> 0),
  description text not null,
  reference text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index wallet_member_created_idx on public.wallet_transactions(member_id, created_at);

create table public.payout_requests (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id) on delete restrict,
  amount numeric(14,2) not null check (amount > 0),
  payout_method text not null,
  payout_details jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending','approved','rejected','paid','cancelled')),
  requested_at timestamptz not null default now(),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  paid_at timestamptz,
  payment_reference text
);

create table public.system_settings (
  setting_key text primary key,
  setting_value jsonb not null,
  description text,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id)
);
insert into public.system_settings(setting_key, setting_value, description) values
('pv_conversion', '{"peso_per_pv": 1}'::jsonb, 'One PV equals one Philippine peso for commission base calculations.'),
('commission_depth', '{"levels": 10}'::jsonb, 'Maximum payable upline generations.'),
('commission_method', '{"method": "differential"}'::jsonb, 'Differential commission based on qualified monthly rank rates.'),
('qualification', '{"requires_personal_pv": true, "requires_group_pv": true}'::jsonb, 'Both personal and group PV requirements must be met.');

-- Helper: determine whether current authenticated user is an admin.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and status = 'active'
  );
$$;

-- Safe registration function: creates profile and closure rows atomically.
-- Admin/service role should approve pending members before transactions.
create or replace function public.register_member(
  p_member_code text,
  p_full_name text,
  p_phone text default null,
  p_sponsor_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;
  if exists (select 1 from public.profiles where id = v_uid) then
    raise exception 'Profile already exists';
  end if;
  if p_sponsor_id is not null and not exists (
    select 1 from public.profiles where id = p_sponsor_id and status = 'active'
  ) then
    raise exception 'Sponsor not found or not active';
  end if;

  insert into public.profiles(id, member_code, full_name, phone, sponsor_id, status)
  values (v_uid, p_member_code, p_full_name, p_phone, p_sponsor_id, 'pending')
  returning id into v_id;

  insert into public.genealogy(ancestor_id, descendant_id, depth)
  values (v_id, v_id, 0);

  if p_sponsor_id is not null then
    insert into public.genealogy(ancestor_id, descendant_id, depth)
    select ancestor_id, v_id, depth + 1
    from public.genealogy
    where descendant_id = p_sponsor_id and depth < 32767;
  end if;

  return v_id;
end;
$$;

-- Computes monthly personal/group PV from paid, non-refunded orders.
-- Group PV excludes the member's own personal PV.
create or replace function public.calculate_monthly_volumes(p_month date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month date := date_trunc('month', p_month)::date;
begin
  if not public.is_admin() then
    raise exception 'Admin permission required';
  end if;

  delete from public.monthly_volumes where period_month = v_month;

  with personal as (
    select o.member_id, coalesce(sum(o.total_pv), 0)::numeric(14,2) as pv
    from public.orders o
    where o.status = 'paid'
      and o.paid_at >= v_month
      and o.paid_at < (v_month + interval '1 month')
    group by o.member_id
  ),
  totals as (
    select p.id as member_id,
           coalesce(me.pv, 0)::numeric(14,2) as personal_pv,
           coalesce(sum(d.pv), 0)::numeric(14,2) as group_pv
    from public.profiles p
    left join personal me on me.member_id = p.id
    left join public.genealogy g on g.ancestor_id = p.id and g.depth > 0
    left join personal d on d.member_id = g.descendant_id
    group by p.id, me.pv
  ),
  ranked as (
    select t.*,
      coalesce((
        select r.id from public.rank_settings r
        where r.is_active
          and t.personal_pv >= r.required_personal_pv
          and t.group_pv >= r.required_group_pv
        order by r.sort_order desc limit 1
      ), 0)::smallint as rank_id
    from totals t
  )
  insert into public.monthly_volumes(period_month, member_id, personal_pv, group_pv, qualified_rank_id, qualified_rate)
  select v_month, x.member_id, x.personal_pv, x.group_pv, r.id, r.commission_rate
  from ranked x
  join public.rank_settings r on r.id = x.rank_id;
end;
$$;

-- Build draft differential commission ledger for one month.
-- For each paid order, walk the source member's 10 closest uplines.
-- Each upline receives max(0, its rate - highest rate already paid closer to sale).
create or replace function public.build_monthly_commissions(p_month date)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month date := date_trunc('month', p_month)::date;
  v_run uuid;
begin
  if not public.is_admin() then
    raise exception 'Admin permission required';
  end if;

  if exists (select 1 from public.commission_runs where period_month = v_month and status in ('approved','posted')) then
    raise exception 'This commission period is already approved or posted';
  end if;

  insert into public.commission_runs(period_month, status, created_by)
  values (v_month, 'draft', auth.uid())
  on conflict (period_month) do update set status = 'draft', created_by = auth.uid()
  returning id into v_run;

  delete from public.commission_ledger where run_id = v_run;

  with paid_sales as (
    select o.id as order_id, o.member_id as source_member_id, o.total_pv
    from public.orders o
    where o.status = 'paid'
      and o.paid_at >= v_month
      and o.paid_at < (v_month + interval '1 month')
  ),
  upline_rates as (
    select s.order_id, s.source_member_id, s.total_pv,
           g.ancestor_id as beneficiary_id, g.depth as generation,
           coalesce(mv.qualified_rate, 0)::numeric(6,5) as beneficiary_rate
    from paid_sales s
    join public.genealogy g
      on g.descendant_id = s.source_member_id
     and g.depth between 1 and 10
    left join public.monthly_volumes mv
      on mv.member_id = g.ancestor_id and mv.period_month = v_month
    join public.profiles p on p.id = g.ancestor_id and p.status = 'active'
  ),
  with_previous as (
    select u.*,
      coalesce(max(u.beneficiary_rate) over (
        partition by u.order_id
        order by u.generation
        rows between unbounded preceding and 1 preceding
      ), 0)::numeric(6,5) as previous_rate
    from upline_rates u
  )
  insert into public.commission_ledger(
    run_id, sale_order_id, beneficiary_id, source_member_id, generation,
    sale_pv, pv_conversion, beneficiary_rate, previous_paid_rate,
    differential_rate, commission_amount
  )
  select v_run, order_id, beneficiary_id, source_member_id, generation,
         total_pv, 1, beneficiary_rate, previous_rate,
         greatest(beneficiary_rate - previous_rate, 0),
         round(total_pv * greatest(beneficiary_rate - previous_rate, 0), 2)
  from with_previous
  where greatest(beneficiary_rate - previous_rate, 0) > 0;

  return v_run;
end;
$$;

-- RLS: users can read their own profile and genealogy; admins can read all.
alter table public.profiles enable row level security;
alter table public.genealogy enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.rank_settings enable row level security;
alter table public.monthly_volumes enable row level security;
alter table public.commission_runs enable row level security;
alter table public.commission_ledger enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.payout_requests enable row level security;
alter table public.system_settings enable row level security;

create policy "profiles read own or admin" on public.profiles for select
using (id = auth.uid() or public.is_admin());
create policy "genealogy read own network or admin" on public.genealogy for select
using (ancestor_id = auth.uid() or descendant_id = auth.uid() or public.is_admin());
create policy "active products readable" on public.products for select
using (is_active or public.is_admin());
create policy "orders read own or admin" on public.orders for select
using (member_id = auth.uid() or public.is_admin());
create policy "order items read own order or admin" on public.order_items for select
using (exists (select 1 from public.orders o where o.id = order_id and (o.member_id = auth.uid() or public.is_admin())));
create policy "ranks readable" on public.rank_settings for select
using (true);
create policy "monthly volume read own or admin" on public.monthly_volumes for select
using (member_id = auth.uid() or public.is_admin());
create policy "commission runs admin only" on public.commission_runs for select
using (public.is_admin());
create policy "commission ledger read own or admin" on public.commission_ledger for select
using (beneficiary_id = auth.uid() or public.is_admin());
create policy "wallet read own or admin" on public.wallet_transactions for select
using (member_id = auth.uid() or public.is_admin());
create policy "payout read own or admin" on public.payout_requests for select
using (member_id = auth.uid() or public.is_admin());
create policy "system settings readable" on public.system_settings for select
using (true);

-- No browser insert/update/delete policies are granted for financial tables.
-- Use trusted server code with Supabase service role for admin mutations.
grant execute on function public.register_member(text, text, text, uuid) to authenticated;
grant execute on function public.calculate_monthly_volumes(date) to authenticated;
grant execute on function public.build_monthly_commissions(date) to authenticated;
grant execute on function public.is_admin() to authenticated;

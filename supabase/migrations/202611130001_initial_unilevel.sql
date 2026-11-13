-- AMANAH UNILEVEL SYSTEM
-- Apply ONLY to project: bqgxvnrgjmngezknqhsl
-- This migration creates new unilevel-specific objects.
-- It does not alter the corporate landing page or its old Supabase project.

create extension if not exists pgcrypto;

do $$ begin
  create type public.amanah_role as enum (
    'administrator',
    'marketing_officer',
    'branch_operator',
    'mobile_stockist',
    'distributor'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.order_status as enum (
    'draft', 'submitted', 'approved', 'processing', 'completed', 'rejected', 'cancelled'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.withdrawal_status as enum (
    'pending', 'approved', 'rejected', 'released'
  );
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  member_code text unique,
  full_name text not null default '',
  phone text,
  role public.amanah_role not null default 'distributor',
  sponsor_id uuid references public.profiles(id) on delete set null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  sku text unique,
  name text not null,
  description text,
  srp numeric(12,2) not null default 0 check (srp >= 0),
  distributor_price numeric(12,2) not null default 0 check (distributor_price >= 0),
  mobile_stockist_price numeric(12,2) not null default 0 check (mobile_stockist_price >= 0),
  branch_operator_price numeric(12,2) not null default 0 check (branch_operator_price >= 0),
  marketing_officer_price numeric(12,2) not null default 0 check (marketing_officer_price >= 0),
  cost numeric(12,2) not null default 0 check (cost >= 0),
  image_path text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text unique not null default ('AM-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  buyer_id uuid not null references public.profiles(id),
  fulfillment_role public.amanah_role,
  fulfillment_user_id uuid references public.profiles(id),
  parent_order_id uuid references public.orders(id),
  status public.order_status not null default 'submitted',
  subtotal numeric(12,2) not null default 0 check (subtotal >= 0),
  total numeric(12,2) not null default 0 check (total >= 0),
  payment_method text,
  payment_reference text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity integer not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  line_total numeric(12,2) generated always as (quantity * unit_price) stored
);

create table if not exists public.commission_rules (
  id uuid primary key default gen_random_uuid(),
  rule_name text not null,
  commission_type text not null check (commission_type in ('unilevel','jmo_pool','smo_pool','direct_referral')),
  level_number integer,
  rate numeric(8,4) not null default 0 check (rate >= 0),
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.commissions (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.orders(id),
  source_member_id uuid references public.profiles(id),
  beneficiary_id uuid not null references public.profiles(id),
  level_number integer,
  commission_type text not null,
  basis_amount numeric(12,2) not null default 0,
  rate numeric(8,4) not null default 0,
  amount numeric(12,2) not null default 0,
  status text not null default 'pending' check (status in ('pending','approved','paid','void')),
  created_at timestamptz not null default now()
);

create table if not exists public.wallets (
  member_id uuid primary key references public.profiles(id) on delete cascade,
  available_balance numeric(12,2) not null default 0 check (available_balance >= 0),
  lifetime_earned numeric(12,2) not null default 0 check (lifetime_earned >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id),
  amount numeric(12,2) not null check (amount > 0),
  payment_method text not null,
  payment_account_name text,
  payment_account_number text,
  status public.withdrawal_status not null default 'pending',
  admin_note text,
  requested_at timestamptz not null default now(),
  processed_at timestamptz
);

create table if not exists public.inventory (
  id uuid primary key default gen_random_uuid(),
  holder_id uuid not null references public.profiles(id),
  product_id uuid not null references public.products(id),
  quantity_on_hand integer not null default 0 check (quantity_on_hand >= 0),
  unique(holder_id, product_id)
);

create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  holder_id uuid not null references public.profiles(id),
  product_id uuid not null references public.products(id),
  order_id uuid references public.orders(id),
  movement_type text not null check (movement_type in ('in','out','adjustment')),
  quantity integer not null check (quantity > 0),
  note text,
  created_at timestamptz not null default now()
);

create or replace function public.current_user_role()
returns public.amanah_role
language sql stable security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_amanah_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() = 'administrator'::public.amanah_role, false)
$$;

create or replace function public.is_in_my_downline(target_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  with recursive downline(id) as (
    select id from public.profiles where sponsor_id = auth.uid()
    union all
    select p.id from public.profiles p join downline d on p.sponsor_id = d.id
  )
  select exists(select 1 from downline where id = target_id)
$$;

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists orders_set_updated_at on public.orders;
create trigger orders_set_updated_at before update on public.orders
for each row execute function public.set_updated_at();

-- New signups receive distributor role. Never accept role from user-supplied metadata.
create or replace function public.handle_new_amanah_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, member_code, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.raw_user_meta_data ->> 'phone',
    'AM-' || upper(substr(replace(new.id::text, '-', ''), 1, 8)),
    'distributor'
  )
  on conflict (id) do nothing;
  insert into public.wallets(member_id) values(new.id) on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_amanah on auth.users;
create trigger on_auth_user_created_amanah
after insert on auth.users
for each row execute procedure public.handle_new_amanah_user();

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.commission_rules enable row level security;
alter table public.commissions enable row level security;
alter table public.wallets enable row level security;
alter table public.withdrawal_requests enable row level security;
alter table public.inventory enable row level security;
alter table public.stock_movements enable row level security;

-- Profiles: users can see themselves and their downline; only admins can manage roles.
drop policy if exists "profiles_select_self_downline_admin" on public.profiles;
create policy "profiles_select_self_downline_admin" on public.profiles
for select to authenticated
using (id = auth.uid() or public.is_in_my_downline(id) or public.is_amanah_admin());

drop policy if exists "profiles_update_self_or_admin" on public.profiles;
create policy "profiles_update_self_or_admin" on public.profiles
for update to authenticated
using (id = auth.uid() or public.is_amanah_admin())
with check (
  public.is_amanah_admin()
  or (id = auth.uid() and role = public.current_user_role() and sponsor_id is not distinct from (select p.sponsor_id from public.profiles p where p.id = auth.uid()))
);

-- Products are readable to signed-in users; admin manages catalog.
drop policy if exists "products_read_authenticated" on public.products;
create policy "products_read_authenticated" on public.products
for select to authenticated using (is_active or public.is_amanah_admin());
drop policy if exists "products_admin_all" on public.products;
create policy "products_admin_all" on public.products
for all to authenticated using (public.is_amanah_admin()) with check (public.is_amanah_admin());

-- Orders: buyer, assigned fulfillment operator, downline visibility for reporting, or admin.
drop policy if exists "orders_select_related" on public.orders;
create policy "orders_select_related" on public.orders
for select to authenticated
using (buyer_id = auth.uid() or fulfillment_user_id = auth.uid()
  or public.is_in_my_downline(buyer_id) or public.is_amanah_admin());
drop policy if exists "orders_insert_buyer" on public.orders;
create policy "orders_insert_buyer" on public.orders
for insert to authenticated with check (buyer_id = auth.uid());
drop policy if exists "orders_update_admin_or_fulfillment" on public.orders;
create policy "orders_update_admin_or_fulfillment" on public.orders
for update to authenticated
using (public.is_amanah_admin() or fulfillment_user_id = auth.uid())
with check (public.is_amanah_admin() or fulfillment_user_id = auth.uid());

drop policy if exists "order_items_select_related" on public.order_items;
create policy "order_items_select_related" on public.order_items
for select to authenticated using (
  exists(select 1 from public.orders o where o.id = order_id)
);
drop policy if exists "order_items_insert_buyer" on public.order_items;
create policy "order_items_insert_buyer" on public.order_items
for insert to authenticated with check (
  exists(select 1 from public.orders o where o.id = order_id and o.buyer_id = auth.uid())
);

drop policy if exists "commission_rules_read" on public.commission_rules;
create policy "commission_rules_read" on public.commission_rules
for select to authenticated using (is_active or public.is_amanah_admin());
drop policy if exists "commission_rules_admin_all" on public.commission_rules;
create policy "commission_rules_admin_all" on public.commission_rules
for all to authenticated using (public.is_amanah_admin()) with check (public.is_amanah_admin());

drop policy if exists "commissions_select_beneficiary_admin" on public.commissions;
create policy "commissions_select_beneficiary_admin" on public.commissions
for select to authenticated using (beneficiary_id = auth.uid() or public.is_amanah_admin());
drop policy if exists "commissions_admin_manage" on public.commissions;
create policy "commissions_admin_manage" on public.commissions
for all to authenticated using (public.is_amanah_admin()) with check (public.is_amanah_admin());

drop policy if exists "wallets_select_owner_admin" on public.wallets;
create policy "wallets_select_owner_admin" on public.wallets
for select to authenticated using (member_id = auth.uid() or public.is_amanah_admin());

drop policy if exists "withdrawals_select_owner_admin" on public.withdrawal_requests;
create policy "withdrawals_select_owner_admin" on public.withdrawal_requests
for select to authenticated using (member_id = auth.uid() or public.is_amanah_admin());
drop policy if exists "withdrawals_insert_owner" on public.withdrawal_requests;
create policy "withdrawals_insert_owner" on public.withdrawal_requests
for insert to authenticated with check (member_id = auth.uid());
drop policy if exists "withdrawals_admin_update" on public.withdrawal_requests;
create policy "withdrawals_admin_update" on public.withdrawal_requests
for update to authenticated using (public.is_amanah_admin()) with check (public.is_amanah_admin());

drop policy if exists "inventory_select_owner_admin" on public.inventory;
create policy "inventory_select_owner_admin" on public.inventory
for select to authenticated using (holder_id = auth.uid() or public.is_amanah_admin());
drop policy if exists "inventory_admin_manage" on public.inventory;
create policy "inventory_admin_manage" on public.inventory
for all to authenticated using (public.is_amanah_admin()) with check (public.is_amanah_admin());

drop policy if exists "stock_movements_select_owner_admin" on public.stock_movements;
create policy "stock_movements_select_owner_admin" on public.stock_movements
for select to authenticated using (holder_id = auth.uid() or public.is_amanah_admin());
drop policy if exists "stock_movements_admin_manage" on public.stock_movements;
create policy "stock_movements_admin_manage" on public.stock_movements
for all to authenticated using (public.is_amanah_admin()) with check (public.is_amanah_admin());

-- Private storage bucket for member documents and product media.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('amanah-unilevel', 'amanah-unilevel', false, 10485760,
        array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do nothing;

drop policy if exists "unilevel_storage_read_authenticated" on storage.objects;
create policy "unilevel_storage_read_authenticated" on storage.objects
for select to authenticated
using (bucket_id = 'amanah-unilevel' and (
  owner_id = auth.uid()::text or public.is_amanah_admin()
));

drop policy if exists "unilevel_storage_upload_own_folder" on storage.objects;
create policy "unilevel_storage_upload_own_folder" on storage.objects
for insert to authenticated
with check (bucket_id = 'amanah-unilevel' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "unilevel_storage_update_own_folder" on storage.objects;
create policy "unilevel_storage_update_own_folder" on storage.objects
for update to authenticated
using (bucket_id = 'amanah-unilevel' and (owner_id = auth.uid()::text or public.is_amanah_admin()))
with check (bucket_id = 'amanah-unilevel' and (owner_id = auth.uid()::text or public.is_amanah_admin()));

drop policy if exists "unilevel_storage_delete_own_folder" on storage.objects;
create policy "unilevel_storage_delete_own_folder" on storage.objects
for delete to authenticated
using (bucket_id = 'amanah-unilevel' and (owner_id = auth.uid()::text or public.is_amanah_admin()));

-- IMPORTANT:
-- 1) Commission percentages and JMO/SMO qualification rules are intentionally not seeded.
-- 2) Promote the first administrator manually after creating its Auth account:
-- update public.profiles set role = 'administrator' where id = '<AUTH_USER_UUID>';
-- 3) Business-critical commission posting and wallet updates must be implemented with
--    trusted database functions/transactions before production use.

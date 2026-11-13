-- Add distributor order destinations and secure Mobile Stockist selection.
-- Apply ONLY to Supabase project bqgxvnrgjmngezknqhsl.
alter table public.orders
  add column if not exists destination_category text,
  add column if not exists destination_name text,
  add column if not exists destination_contact_person text,
  add column if not exists destination_contact_number text,
  add column if not exists destination_address text,
  add column if not exists destination_member_id uuid references public.profiles(id);

alter table public.orders
  add constraint orders_destination_category_check
  check (destination_category is null or destination_category in ('main_branch','branch_operator','mobile_stockist'));

create or replace function public.list_active_mobile_stockists()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in.';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', id, 'full_name', full_name, 'member_code', member_code
  ) order by full_name), '[]'::jsonb)
  into v_result
  from public.profiles
  where role = 'mobile_stockist'::public.amanah_role
    and is_active = true;
  return v_result;
end;
$$;

drop function if exists public.submit_member_order(jsonb);

create function public.submit_member_order(
  p_items jsonb,
  p_destination_category text,
  p_destination_member_id uuid default null,
  p_contact_person text default null,
  p_contact_number text default null,
  p_address text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_member_id uuid := auth.uid();
  v_role public.amanah_role;
  v_order_id uuid;
  v_order_number text;
  v_total numeric(12,2);
  v_item_count integer;
  v_destination_name text;
begin
  if v_member_id is null then
    raise exception 'You must be signed in to submit an order.';
  end if;
  select role into v_role from public.profiles
  where id = v_member_id and is_active = true;
  if v_role is null then
    raise exception 'Your AMANAH profile is missing or inactive.';
  end if;
  if v_role <> 'distributor'::public.amanah_role then
    raise exception 'Only Distributor accounts can use this order form.';
  end if;
  if p_destination_category not in ('main_branch','branch_operator','mobile_stockist') then
    raise exception 'Please select a valid order destination.';
  end if;

  if p_destination_category = 'mobile_stockist' then
    if p_destination_member_id is null then
      raise exception 'Please select a Mobile Stockist by name.';
    end if;
    select full_name into v_destination_name
    from public.profiles
    where id = p_destination_member_id
      and role = 'mobile_stockist'::public.amanah_role
      and is_active = true;
    if v_destination_name is null then
      raise exception 'The selected Mobile Stockist is unavailable. Refresh the list.';
    end if;
  else
    if nullif(trim(p_contact_person), '') is null
       or nullif(trim(p_contact_number), '') is null
       or nullif(trim(p_address), '') is null then
      raise exception 'Enter the contact person, contact number, and complete address.';
    end if;
    v_destination_name := case p_destination_category
      when 'main_branch' then 'Main Branch'
      else 'Branch Operator'
    end;
    if length(trim(p_contact_person)) > 120 or length(trim(p_contact_number)) > 40
       or length(trim(p_address)) > 500 then
      raise exception 'Destination details are too long.';
    end if;
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Your cart is empty.';
  end if;
  if exists (
    select 1 from jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer)
    where x.product_id is null or x.quantity is null or x.quantity < 1 or x.quantity > 1000
  ) then
    raise exception 'Cart contains an invalid product or quantity.';
  end if;

  with requested as (
    select product_id, sum(quantity)::integer as quantity
    from jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer)
    group by product_id
  ), priced as (
    select r.product_id, r.quantity,
      case v_role
        when 'distributor' then p.distributor_price
        when 'mobile_stockist' then p.mobile_stockist_price
        when 'branch_operator' then p.branch_operator_price
        when 'marketing_officer' then p.marketing_officer_price
        else p.srp
      end::numeric(12,2) as unit_price
    from requested r
    join public.products p on p.id = r.product_id and p.is_active = true
  )
  select count(*), coalesce(sum(quantity * unit_price), 0)
  into v_item_count, v_total from priced;

  if v_item_count = 0 then
    raise exception 'No valid active products were found in your cart.';
  end if;
  if v_item_count <> (
    select count(*) from (
      select product_id from jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer)
      group by product_id
    ) q
  ) then
    raise exception 'One or more cart products are unavailable. Refresh the catalog and try again.';
  end if;

  insert into public.orders (
    buyer_id, status, subtotal, total, payment_method, notes,
    destination_category, destination_name, destination_contact_person,
    destination_contact_number, destination_address, destination_member_id
  ) values (
    v_member_id, 'submitted', v_total, v_total,
    'Pending - no payment collected',
    'Submitted through AMANAH member portal. Awaiting admin confirmation.',
    p_destination_category, v_destination_name,
    case when p_destination_category = 'mobile_stockist' then null else trim(p_contact_person) end,
    case when p_destination_category = 'mobile_stockist' then null else trim(p_contact_number) end,
    case when p_destination_category = 'mobile_stockist' then null else trim(p_address) end,
    case when p_destination_category = 'mobile_stockist' then p_destination_member_id else null end
  ) returning id, order_number into v_order_id, v_order_number;

  insert into public.order_items (order_id, product_id, quantity, unit_price)
  select v_order_id, priced.product_id, priced.quantity, priced.unit_price
  from (
    select r.product_id, r.quantity,
      case v_role
        when 'distributor' then p.distributor_price
        when 'mobile_stockist' then p.mobile_stockist_price
        when 'branch_operator' then p.branch_operator_price
        when 'marketing_officer' then p.marketing_officer_price
        else p.srp
      end::numeric(12,2) as unit_price
    from (
      select product_id, sum(quantity)::integer as quantity
      from jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer)
      group by product_id
    ) r
    join public.products p on p.id = r.product_id and p.is_active = true
  ) priced;

  return jsonb_build_object(
    'order_id', v_order_id, 'order_number', v_order_number,
    'total', v_total, 'product_count', v_item_count, 'status', 'submitted',
    'destination_name', v_destination_name
  );
end;
$$;

revoke all on function public.list_active_mobile_stockists() from public;
revoke all on function public.list_active_mobile_stockists() from anon;
grant execute on function public.list_active_mobile_stockists() to authenticated;

revoke all on function public.submit_member_order(jsonb,text,uuid,text,text,text) from public;
revoke all on function public.submit_member_order(jsonb,text,uuid,text,text,text) from anon;
grant execute on function public.submit_member_order(jsonb,text,uuid,text,text,text) to authenticated;

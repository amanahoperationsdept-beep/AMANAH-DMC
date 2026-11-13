-- Secure AMANAH member order submission.
-- Apply ONLY to Supabase project bqgxvnrgjmngezknqhsl.
-- Prices are recalculated from the signed-in member role in the database.
create or replace function public.submit_member_order(p_items jsonb)
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
begin
  if v_member_id is null then
    raise exception 'You must be signed in to submit an order.';
  end if;

  select role into v_role
  from public.profiles
  where id = v_member_id and is_active = true;

  if v_role is null then
    raise exception 'Your AMANAH profile is missing or inactive.';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Your cart is empty.';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer)
    where x.product_id is null or x.quantity is null or x.quantity < 1 or x.quantity > 1000
  ) then
    raise exception 'Cart contains an invalid product or quantity.';
  end if;

  with requested as (
    select product_id, sum(quantity)::integer as quantity
    from jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer)
    group by product_id
  ),
  priced as (
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
  into v_item_count, v_total
  from priced;

  if v_item_count = 0 then
    raise exception 'No valid active products were found in your cart.';
  end if;

  if v_item_count <> (
    select count(*) from (
      select product_id
      from jsonb_to_recordset(p_items) as x(product_id uuid, quantity integer)
      group by product_id
    ) q
  ) then
    raise exception 'One or more cart products are unavailable. Refresh the catalog and try again.';
  end if;

  insert into public.orders (
    buyer_id, status, subtotal, total, payment_method, notes
  )
  values (
    v_member_id, 'submitted', v_total, v_total,
    'Pending - no payment collected',
    'Submitted through AMANAH member portal. Awaiting admin confirmation.'
  )
  returning id, order_number into v_order_id, v_order_number;

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
    'order_id', v_order_id,
    'order_number', v_order_number,
    'total', v_total,
    'product_count', v_item_count,
    'status', 'submitted'
  );
end;
$$;

revoke all on function public.submit_member_order(jsonb) from public;
revoke all on function public.submit_member_order(jsonb) from anon;
grant execute on function public.submit_member_order(jsonb) to authenticated;

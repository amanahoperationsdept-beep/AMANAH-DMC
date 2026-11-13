-- Include selected delivery destination in the read-only Admin Orders feed.
-- Apply ONLY to Supabase project bqgxvnrgjmngezknqhsl.
create or replace function public.admin_list_orders(p_limit integer default 50)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role public.amanah_role;
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'You must be signed in.'; end if;
  select role into v_role from public.profiles
  where id = auth.uid() and is_active = true;
  if v_role is distinct from 'administrator'::public.amanah_role then
    raise exception 'Administrator access required.';
  end if;

  select coalesce(jsonb_agg(order_row order by created_at desc), '[]'::jsonb)
  into v_result
  from (
    select o.created_at,
      jsonb_build_object(
        'id', o.id,
        'order_number', o.order_number,
        'status', o.status,
        'subtotal', o.subtotal,
        'total', o.total,
        'payment_method', o.payment_method,
        'notes', o.notes,
        'created_at', o.created_at,
        'member_name', coalesce(p.full_name, 'Unknown member'),
        'member_code', p.member_code,
        'destination_category', o.destination_category,
        'destination_name', o.destination_name,
        'destination_contact_person', o.destination_contact_person,
        'destination_contact_number', o.destination_contact_number,
        'destination_address', o.destination_address,
        'items', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'product_name', pr.name,
            'quantity', oi.quantity,
            'unit_price', oi.unit_price,
            'line_total', oi.quantity * oi.unit_price
          )), '[]'::jsonb)
          from public.order_items oi
          left join public.products pr on pr.id = oi.product_id
          where oi.order_id = o.id
        )
      ) as order_row
    from public.orders o
    left join public.profiles p on p.id = o.buyer_id
    order by o.created_at desc
    limit greatest(1, least(coalesce(p_limit, 50), 100))
  ) recent_orders;
  return v_result;
end;
$$;
revoke all on function public.admin_list_orders(integer) from public;
revoke all on function public.admin_list_orders(integer) from anon;
grant execute on function public.admin_list_orders(integer) to authenticated;

-- Harden financial processing RPCs for server-side use only.
-- Apply after 0001_initial_schema.sql.
--
-- The application server must authenticate the administrator separately,
-- then invoke these RPCs with the Supabase service-role client. Never ship
-- the service-role key to a browser or mobile client.

create or replace function public.calculate_monthly_volumes(p_month date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month date;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Server-side service role required';
  end if;
  if p_month is null then
    raise exception 'A month is required';
  end if;

  v_month := date_trunc('month', p_month)::date;

  -- Once a period is approved or posted, its qualification snapshot is frozen.
  if exists (
    select 1 from public.commission_runs
    where period_month = v_month and status in ('approved', 'posted')
  ) then
    raise exception 'Cannot recalculate a period that is approved or posted';
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
        select r.id
        from public.rank_settings r
        where r.is_active
          and t.personal_pv >= r.required_personal_pv
          and t.group_pv >= r.required_group_pv
        order by r.sort_order desc
        limit 1
      ), 0)::smallint as rank_id
    from totals t
  )
  insert into public.monthly_volumes(
    period_month, member_id, personal_pv, group_pv,
    qualified_rank_id, qualified_rate
  )
  select v_month, x.member_id, x.personal_pv, x.group_pv, r.id, r.commission_rate
  from ranked x
  join public.rank_settings r on r.id = x.rank_id;
end;
$$;

create or replace function public.build_monthly_commissions(p_month date)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month date;
  v_run uuid;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Server-side service role required';
  end if;
  if p_month is null then
    raise exception 'A month is required';
  end if;

  v_month := date_trunc('month', p_month)::date;

  if exists (
    select 1 from public.commission_runs
    where period_month = v_month and status in ('approved', 'posted')
  ) then
    raise exception 'This commission period is already approved or posted';
  end if;

  -- Always refresh the draft qualification snapshot from verified paid orders.
  perform public.calculate_monthly_volumes(v_month);

  insert into public.commission_runs(period_month, status, created_by)
  values (v_month, 'draft', null)
  on conflict (period_month) do update
    set status = 'draft',
        created_by = null,
        approved_by = null,
        approved_at = null,
        posted_at = null
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
    join public.profiles p
      on p.id = g.ancestor_id and p.status = 'active'
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

-- Remove the default PUBLIC execute grant and prevent direct client RPC calls.
revoke all on function public.calculate_monthly_volumes(date) from public, anon, authenticated;
revoke all on function public.build_monthly_commissions(date) from public, anon, authenticated;
grant execute on function public.calculate_monthly_volumes(date) to service_role;
grant execute on function public.build_monthly_commissions(date) to service_role;

comment on function public.calculate_monthly_volumes(date) is
  'Server-only monthly PV/rank snapshot. Approved and posted periods are immutable.';
comment on function public.build_monthly_commissions(date) is
  'Server-only idempotent draft builder. Rebuilds only unapproved/unposted periods.';

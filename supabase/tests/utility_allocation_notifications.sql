-- Run against a migrated test database with an owner and active room occupants.
-- No pushes are sent: notifications and queue rows roll back with the charges.
begin;
do $$
declare
  v_owner uuid;
  v_result jsonb;
  v_expected_tenant integer;
  v_expected_all integer;
  v_actual_tenant integer;
  v_actual_all integer;
begin
  select id into v_owner
  from public.profiles
  where role::text = 'owner'
  limit 1;
  if v_owner is null then raise exception 'Owner fixture required'; end if;

  perform set_config('request.jwt.claim.sub', v_owner::text, true);
  set local role authenticated;
  v_result := public.create_utility_charge_cart(jsonb_build_array(jsonb_build_object(
    'scope', 'all_rooms',
    'category', 'electricity',
    'allocation_method', 'equal_per_tenant',
    'title', 'Notification regression',
    'total_amount', 9999,
    'due_date', current_date + 7,
    'period_start', current_date,
    'period_end', current_date + 6
  )));
  reset role;

  v_expected_tenant := (v_result->>'charge_count')::integer;

  select count(*) into v_actual_tenant
  from public.utility_charge_allocations allocation
  join public.utility_charge_batch_items item
    on item.id = allocation.batch_item_id
  join public.app_notifications notification
    on notification.route_id = allocation.charge_id
   and notification.recipient_id = allocation.tenant_id
   and notification.route_type = 'payment'
   and (notification.data->>'amount')::numeric = allocation.allocated_amount
  join public.notification_push_jobs job
    on job.notification_id = notification.id
  where item.batch_id = (v_result->>'batch_id')::uuid;

  select coalesce(sum(
    1 + (
      select count(*)
      from public.guardian_tenant_links link
      where link.tenant_id = allocation.tenant_id
    )
  ), 0)::integer
  into v_expected_all
  from public.utility_charge_allocations allocation
  join public.utility_charge_batch_items item
    on item.id = allocation.batch_item_id
  where item.batch_id = (v_result->>'batch_id')::uuid;

  select count(*) into v_actual_all
  from public.utility_charge_allocations allocation
  join public.utility_charge_batch_items item
    on item.id = allocation.batch_item_id
  join public.app_notifications notification
    on notification.route_id = allocation.charge_id
   and notification.route_type = 'payment'
   and (notification.data->>'amount')::numeric = allocation.allocated_amount
   and (
     notification.recipient_id = allocation.tenant_id
     or exists (
       select 1
       from public.guardian_tenant_links link
       where link.tenant_id = allocation.tenant_id
         and link.guardian_id = notification.recipient_id
     )
   )
  join public.notification_push_jobs job
    on job.notification_id = notification.id
  where item.batch_id = (v_result->>'batch_id')::uuid;

  if v_expected_tenant < 1 or v_actual_tenant <> v_expected_tenant then
    raise exception 'Expected % tenant allocation notifications with push jobs, found %',
      v_expected_tenant, v_actual_tenant;
  end if;

  if v_actual_all <> v_expected_all then
    raise exception 'Expected % tenant + guardian allocation notifications with push jobs, found %',
      v_expected_all, v_actual_all;
  end if;
end;
$$;
rollback;

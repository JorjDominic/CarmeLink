-- Cleaning-duty notification regression checks. All writes roll back.
begin;

do $$
declare
  v_tenant uuid;
  v_bed uuid;
  v_report uuid;
  v_staff_count integer;
  v_count integer;
begin
  select id into v_tenant
  from public.profiles
  where role::text = 'tenant'
  limit 1;

  select id into v_bed
  from public.bed_spaces
  limit 1;

  select count(*) into v_staff_count
  from public.profiles
  where role::text in ('owner', 'caretaker');

  if v_tenant is null or v_bed is null or v_staff_count = 0 then
    raise exception 'Test requires a tenant, a bed, and at least one staff profile';
  end if;

  insert into public.cleaning_noncompliance_reports (
    reporter_id,
    reported_bed_space_id,
    reported_bed_label,
    description
  ) values (
    v_tenant,
    v_bed,
    'Regression test bed',
    'Cleaning notification regression test'
  )
  returning id into v_report;

  select count(*) into v_count
  from public.app_notifications
  where route_type = 'cleaning_report'
    and route_id = v_report;

  if v_count <> v_staff_count then
    raise exception 'Expected % staff notifications, found %',
      v_staff_count, v_count;
  end if;

  if exists (
    select 1
    from public.app_notifications notification
    join public.profiles profile on profile.id = notification.recipient_id
    where notification.route_id = v_report
      and profile.role::text not in ('owner', 'caretaker')
  ) then
    raise exception 'New cleaning report notified an unauthorized role';
  end if;

  update public.cleaning_noncompliance_reports
  set status = 'reviewing',
      staff_notes = 'Review started'
  where id = v_report;

  select count(*) into v_count
  from public.app_notifications
  where route_type = 'cleaning_report'
    and route_id = v_report
    and recipient_id = v_tenant
    and data ->> 'status' = 'reviewing';

  if v_count <> 1 then
    raise exception 'Tenant status notification missing or duplicated';
  end if;

  update public.cleaning_noncompliance_reports
  set updated_at = now()
  where id = v_report;

  select count(*) into v_count
  from public.app_notifications
  where route_type = 'cleaning_report'
    and route_id = v_report
    and recipient_id = v_tenant;

  if v_count <> 1 then
    raise exception 'Unrelated update created a duplicate tenant notification';
  end if;
end;
$$;

rollback;

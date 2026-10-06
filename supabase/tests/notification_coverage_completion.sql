-- Structural smoke test for the notification coverage migration.
-- Run after migration 202610070012. No application records are changed.
begin;
do $$
declare
  v_missing text[] := array[]::text[];
  v_name text;
begin
  foreach v_name in array array[
    'emit_app_notification',
    'emit_staff_notification',
    'emit_tenant_circle_notification',
    'notify_contract_requirement_event',
    'notify_contract_signer_event',
    'notify_contract_status_event',
    'notify_move_out_case_event',
    'notify_move_out_settlement_event',
    'notify_room_assignment_event',
    'notify_cleaning_schedule_event',
    'notify_employee_curfew_event',
    'notify_guardian_link_event',
    'notify_room_inspection_schedule_event',
    'process_contract_expiry_notifications'
  ] loop
    if not exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public' and p.proname = v_name
    ) then
      v_missing := array_append(v_missing, v_name);
    end if;
  end loop;

  if cardinality(v_missing) > 0 then
    raise exception 'Missing notification functions: %', array_to_string(v_missing, ', ');
  end if;

  foreach v_name in array array[
    'contract_requirement_notification',
    'contract_signer_notification',
    'tenant_contract_status_notification',
    'move_out_case_notification',
    'move_out_settlement_notification',
    'tenant_assignment_notification',
    'cleaning_schedule_notification',
    'employee_curfew_notification',
    'guardian_link_notification',
    'room_inspection_schedule_notification'
  ] loop
    if not exists (
      select 1 from pg_trigger
      where tgname = v_name and not tgisinternal
    ) then
      raise exception 'Missing notification trigger: %', v_name;
    end if;
  end loop;

  if not exists (
    select 1 from cron.job
    where jobname = 'contract-expiry-notifications'
  ) then
    raise exception 'Contract-expiry notification cron job is missing';
  end if;
end;
$$;
rollback;

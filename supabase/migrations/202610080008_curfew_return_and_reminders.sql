-- Phase 1: verified return records and reliable pre-return / overdue reminders.
-- Never infer physical arrival from a clock, geofence, or notification.
-- Apply after 202610070012_notification_coverage_completion.sql.
begin;

alter table public.curfew_requests
  add column if not exists actual_return_time timestamptz,
  add column if not exists return_recorded_by uuid references public.profiles(id) on delete set null,
  add column if not exists return_recorded_at timestamptz;

create index if not exists curfew_approved_outstanding_return_idx
  on public.curfew_requests(expected_return_time)
  where status = 'approved' and actual_return_time is null;

-- Keep the established curfew approval trigger. Enforce new fields in a
-- second BEFORE UPDATE trigger; no changes to existing decision logic.
create or replace function public.zz_validate_curfew_return_update()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.actual_return_time is distinct from old.actual_return_time then
    if not public.is_staff() then
      raise exception 'Only staff can record or correct a return';
    end if;
    if old.status <> 'approved' then
      raise exception 'Only approved requests can have a return recorded';
    end if;
    if new.actual_return_time is null then
      raise exception 'A recorded return cannot be cleared';
    end if;
    if new.actual_return_time < old.departure_time or
       new.actual_return_time > now() then
      raise exception 'Return time must be after departure and cannot be in the future';
    end if;
    new.return_recorded_by := auth.uid();
    new.return_recorded_at := now();
  elsif new.return_recorded_by is distinct from old.return_recorded_by or
        new.return_recorded_at is distinct from old.return_recorded_at then
    raise exception 'Return audit fields can only change when recording a return';
  end if;

  -- An approved overnight leave belongs to the guardian's decision, so staff
  -- must not silently extend it. Approved late-return schedules are editable.
  if new.expected_return_time is distinct from old.expected_return_time
     and old.status = 'approved' then
    if not public.is_staff() or old.request_type <> 'late_return' or
       old.actual_return_time is not null then
      raise exception 'Only staff can reschedule approved late returns before arrival';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists zz_validate_curfew_return_update on public.curfew_requests;
create trigger zz_validate_curfew_return_update
before update on public.curfew_requests
for each row execute function public.zz_validate_curfew_return_update();

-- Existing server-side notification queue handles FCM delivery/retry.
create or replace function public.notify_curfew_return_record_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_event text;
begin
  if new.actual_return_time is distinct from old.actual_return_time
     and new.actual_return_time is not null then
    v_event := 'curfew_return:' || new.id::text || ':' ||
      extract(epoch from new.actual_return_time)::bigint::text;
    perform public.emit_tenant_circle_notification(
      new.tenant_id, true, true, 'curfew', 'Return recorded',
      'Dormitory staff recorded a return at ' ||
        to_char(new.actual_return_time at time zone 'Asia/Manila', 'Mon DD, YYYY HH12:MI AM') ||
        '. Open the request to review.',
      'curfew', new.id, jsonb_build_object('request_id', new.id,
        'actual_return_time', new.actual_return_time), v_event, 0
    );
  elsif new.expected_return_time is distinct from old.expected_return_time
        and new.status = 'approved' then
    v_event := 'curfew_rescheduled:' || new.id::text || ':' ||
      extract(epoch from new.expected_return_time)::bigint::text;
    perform public.emit_tenant_circle_notification(
      new.tenant_id, true, true, 'curfew', 'Late-return schedule updated',
      'Staff updated the expected return to ' ||
        to_char(new.expected_return_time at time zone 'Asia/Manila', 'Mon DD, YYYY HH12:MI AM') || '.',
      'curfew', new.id, jsonb_build_object('request_id', new.id,
        'expected_return_time', new.expected_return_time), v_event, 0
    );
  end if;
  return new;
end $$;

drop trigger if exists notify_curfew_return_record_change on public.curfew_requests;
create trigger notify_curfew_return_record_change
after update of actual_return_time, expected_return_time on public.curfew_requests
for each row execute function public.notify_curfew_return_record_change();

-- The unique log is independent of notification retention, so pg_cron retries
-- and simultaneous runs cannot duplicate reminders.
create table if not exists public.curfew_return_reminder_log (
  request_id uuid not null references public.curfew_requests(id) on delete cascade,
  expected_return_time timestamptz not null,
  reminder_kind text not null check (reminder_kind in ('approaching', 'overdue')),
  created_at timestamptz not null default now(),
  primary key (request_id, expected_return_time, reminder_kind)
);

alter table public.curfew_return_reminder_log enable row level security;
revoke all on public.curfew_return_reminder_log from public, anon, authenticated;

create or replace function public.process_curfew_return_reminders()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_row record;
  v_kind text;
  v_inserted uuid;
  v_count integer := 0;
  v_local text;
begin
  for v_row in
    select r.id, r.tenant_id, r.expected_return_time
      from public.curfew_requests r
     where r.status = 'approved'
       and r.actual_return_time is null
       and r.expected_return_time <= now() + interval '30 minutes'
       and r.expected_return_time >= now() - interval '2 hours'
  loop
    if v_row.expected_return_time > now() then
      v_kind := 'approaching';
    else
      v_kind := 'overdue';
    end if;

    v_inserted := null;
    insert into public.curfew_return_reminder_log (
      request_id, expected_return_time, reminder_kind
    ) values (v_row.id, v_row.expected_return_time, v_kind)
    on conflict do nothing returning request_id into v_inserted;
    if v_inserted is null then continue; end if;

    v_local := to_char(v_row.expected_return_time at time zone 'Asia/Manila',
      'Mon DD, YYYY HH12:MI AM');
    perform public.emit_tenant_circle_notification(
      v_row.tenant_id, true, true, 'curfew',
      case when v_kind = 'approaching'
        then 'Expected return approaching' else 'Expected return time passed' end,
      case when v_kind = 'approaching'
        then 'Expected return is ' || v_local || '. Plan your return and coordinate with dormitory staff.'
        else 'Expected return was ' || v_local || '. If already back, ask staff to record your actual return.' end,
      'curfew', v_row.id,
      jsonb_build_object('request_id', v_row.id, 'reminder_kind', v_kind,
        'expected_return_time', v_row.expected_return_time),
      'curfew_reminder:' || v_row.id::text || ':' || v_kind || ':' ||
        extract(epoch from v_row.expected_return_time)::bigint::text, 0
    );
    v_count := v_count + 1;
  end loop;
  return v_count;
end $$;

-- PRODUCTION SAFE ROLLOUT: reminder scheduler intentionally NOT enabled here.
-- This migration only installs schema, guard triggers, and the reminder function.
-- Notifications from explicit staff return/reschedule updates remain active.
-- Review ops_manual_sql/03_enable_reminders_after_approval.sql separately
-- after controlled staff/tenant/guardian tests and notification-volume review.

revoke all on function public.zz_validate_curfew_return_update() from public, anon, authenticated;
revoke all on function public.notify_curfew_return_record_change() from public, anon, authenticated;
revoke all on function public.process_curfew_return_reminders() from public, anon, authenticated;

commit;

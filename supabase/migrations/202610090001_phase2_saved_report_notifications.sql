-- REVIEW ONLY: do not run against production without leader approval.
-- Requires 202610070012_notification_coverage_completion.sql.
-- Keep existing client status/completion notifications; fill only uncovered
-- saves. Trigger writes roll back with the report when persistence fails.
begin;

create or replace function public.notify_confidential_report_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_key text;
begin
  v_key := 'confidential:' || new.id::text || ':' || txid_current()::text;
  if tg_op = 'INSERT' then
    perform public.emit_staff_notification('safety', 'New confidential report',
      'A confidential report was submitted. Open the protected report to review it.',
      'confidential_report', new.id, jsonb_build_object('report_id', new.id), v_key, 0);
  elsif new.status is distinct from old.status
     or new.response_notes is distinct from old.response_notes then
    perform public.emit_app_notification(new.tenant_id, 'safety', 'Confidential report updated',
      'Your confidential report was updated. Open the protected report for details.',
      'confidential_report', new.id, jsonb_build_object('report_id', new.id), v_key, 0);
  end if;
  return new;
end;
$$;

-- The existing trigger may listen only to status. Recreate it to include notes.
drop trigger if exists confidential_report_notifications on public.confidential_reports;
create trigger confidential_report_notifications
after insert or update of status, response_notes on public.confidential_reports
for each row execute function public.notify_confidential_report_change();

create or replace function public.notify_confidential_report_addendum_saved()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_tenant uuid; v_key text;
begin
  select tenant_id into v_tenant from public.confidential_reports where id = new.report_id;
  v_key := 'confidential_addendum:' || new.id::text;
  -- No private report text in notification bodies and no guardian recipients.
  perform public.emit_staff_notification('safety', 'Confidential report updated',
    'Additional details were saved to a confidential report.', 'confidential_report',
    new.report_id, jsonb_build_object('report_id', new.report_id), v_key, 0);
  perform public.emit_app_notification(v_tenant, 'safety', 'Confidential report updated',
    'Additional details were saved to your confidential report.', 'confidential_report',
    new.report_id, jsonb_build_object('report_id', new.report_id), v_key, 0);
  return new;
end;
$$;
create trigger confidential_addendum_saved_notification
after insert on public.confidential_report_addenda
for each row execute function public.notify_confidential_report_addendum_saved();

create or replace function public.notify_maintenance_report_saved_changes()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_data jsonb; v_key text;
begin
  v_data := jsonb_build_object('report_id', new.id);
  v_key := 'maintenance_saved:' || new.id::text || ':' || txid_current()::text;
  if (to_jsonb(new) - array['updated_at', 'status', 'staff_notes', 'resolved_at'])
      is distinct from
     (to_jsonb(old) - array['updated_at', 'status', 'staff_notes', 'resolved_at']) then
    perform public.emit_staff_notification('maintenance', 'Maintenance report updated',
      'Saved details changed on a maintenance report.', 'maintenance', new.id, v_data, v_key, 0);
  end if;
  if new.status is distinct from old.status and auth.uid() = new.tenant_id then
    -- Tenant cancellation has no client notification producer.
    perform public.emit_staff_notification('maintenance', 'Maintenance report updated',
      'A tenant changed the status of a maintenance report.', 'maintenance', new.id, v_data, v_key, 0);
  end if;
  -- Status changes already use AppNotificationService after the staff RPC.
  if new.status is not distinct from old.status
     and new.staff_notes is distinct from old.staff_notes then
    perform public.emit_app_notification(new.tenant_id, 'maintenance', 'Maintenance report updated',
      'Staff saved new notes on your maintenance report.', 'maintenance', new.id, v_data, v_key, 0);
  end if;
  return new;
end;
$$;
create trigger maintenance_saved_changes_notification
after update on public.maintenance_reports
for each row execute function public.notify_maintenance_report_saved_changes();

create or replace function public.notify_conduct_report_saved_event()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_case public.conduct_cases; v_key text;
begin
  -- Publish and warning notifications are already sent by AppNotificationService.
  if new.event_type in ('tenant_notified', 'warning_issued') then return new; end if;
  select * into v_case from public.conduct_cases where id = new.case_id;
  v_key := 'conduct_saved:' || new.id::text;
  perform public.emit_staff_notification('safety', 'Conduct report updated',
    'A change was saved to a conduct report.', 'conduct_case', new.case_id,
    jsonb_build_object('case_id', new.case_id), v_key, 0);
  -- Drafts and staff-only evidence must never be disclosed to residents.
  if v_case.tenant_notified_at is not null
     and new.event_type not in ('case_created', 'evidence_added', 'tenant_response_submitted') then
    perform public.emit_app_notification(v_case.tenant_id, 'safety', 'Conduct report updated',
      'Your conduct report was updated. Open the report for details.', 'conduct_case',
      new.case_id, jsonb_build_object('case_id', new.case_id), v_key, 0);
  end if;
  return new;
end;
$$;
create trigger conduct_saved_event_notification after insert on public.conduct_case_events
for each row execute function public.notify_conduct_report_saved_event();

create or replace function public.notify_conduct_appeal_saved_changes()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_key text;
begin
  -- Submission and final decisions already notify through AppNotificationService.
  if new.status not in ('under_review', 'withdrawn')
     or (new.status is not distinct from old.status and new.decision_notes is not distinct from old.decision_notes) then
    return new;
  end if;
  v_key := 'appeal_saved:' || new.id::text || ':' || txid_current()::text;
  perform public.emit_staff_notification('safety', 'Conduct appeal updated',
    'A change was saved to a conduct appeal.', 'conduct_case', new.case_id,
    jsonb_build_object('case_id', new.case_id), v_key, 0);
  perform public.emit_app_notification(new.tenant_id, 'safety', 'Conduct appeal updated',
    'Your conduct appeal was updated.', 'conduct_case', new.case_id,
    jsonb_build_object('case_id', new.case_id), v_key, 0);
  return new;
end;
$$;
create trigger conduct_appeal_saved_notification after update on public.conduct_case_appeals
for each row execute function public.notify_conduct_appeal_saved_changes();

create or replace function public.notify_inspection_saved_changes()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_inspection public.room_inspections; v_tenant uuid; v_key text;
begin
  if tg_op = 'UPDATE' then
    if (to_jsonb(new) - array['updated_at', 'corrected_at']) is not distinct from
       (to_jsonb(old) - array['updated_at', 'corrected_at']) then return new; end if;
  end if;
  if tg_table_name = 'room_inspections' then
    -- Creation/scheduling and completion already have notification producers.
    if tg_op = 'INSERT' or new.status in ('scheduled', 'completed') then return new; end if;
    v_id := new.id;
  else
    v_id := new.inspection_id;
  end if;
  select * into v_inspection from public.room_inspections where id = v_id;
  v_key := 'inspection_saved:' || v_id::text || ':' || tg_table_name || ':' || new.id::text || ':' || txid_current()::text;
  perform public.emit_staff_notification('maintenance', 'Inspection report updated',
    'A change was saved to an inspection report.', 'inspection', v_id,
    jsonb_build_object('inspection_id', v_id), v_key, 0);
  -- Evidence is staff-only. Other updates are visible only after publication.
  if tg_table_name <> 'room_inspection_evidence' and v_inspection.notice_published_at is not null then
    for v_tenant in
      select distinct a.tenant_id from public.tenant_assignments a
      join public.bed_spaces b on b.id = a.bed_space_id
      where a.status::text = 'active' and b.room_id = v_inspection.room_id
    loop
      perform public.emit_app_notification(v_tenant, 'maintenance', 'Inspection report updated',
        'An inspection report for your room was updated.', 'inspection', v_id,
        jsonb_build_object('inspection_id', v_id), v_key, 0);
    end loop;
  end if;
  return new;
end;
$$;
create trigger inspection_saved_changes_notification after update on public.room_inspections
for each row execute function public.notify_inspection_saved_changes();
create trigger inspection_finding_saved_notification after insert or update on public.room_inspection_findings
for each row execute function public.notify_inspection_saved_changes();
create trigger inspection_evidence_saved_notification after insert on public.room_inspection_evidence
for each row execute function public.notify_inspection_saved_changes();

-- Cleaning status AND staff-notes saves already use the existing transactional
-- cleaning_report_notifications trigger; do not add a second producer.
revoke all on function public.notify_confidential_report_change(),
  public.notify_confidential_report_addendum_saved(),
  public.notify_maintenance_report_saved_changes(),
  public.notify_conduct_report_saved_event(),
  public.notify_conduct_appeal_saved_changes(),
  public.notify_inspection_saved_changes() from public, anon, authenticated;
commit;

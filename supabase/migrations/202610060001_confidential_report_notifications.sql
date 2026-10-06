begin;

-- Persist the inbox entry in the report transaction. Submission previously
-- saved the report without creating any app_notifications row.
create or replace function public.notify_confidential_report_change()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.app_notifications (
      recipient_id, notification_type, title, body, route_type, route_id, data
    )
    select p.id, 'safety', 'New confidential report',
      'A tenant submitted a confidential report. Open the report register to review it.',
      'confidential_report', new.id,
      jsonb_build_object('report_id', new.id, 'status', new.status)
    from public.profiles p
    where p.role::text = 'owner';
  elsif new.status is distinct from old.status then
    insert into public.app_notifications (
      recipient_id, notification_type, title, body, route_type, route_id, data
    ) values (
      new.tenant_id, 'safety', 'Confidential report update',
      'Your confidential report is now ' || replace(new.status, '_', ' ') || '.',
      'confidential_report', new.id,
      jsonb_build_object('report_id', new.id, 'status', new.status)
    );
  end if;
  return new;
end;
$$;

revoke all on function public.notify_confidential_report_change()
  from public, anon, authenticated;

create trigger confidential_report_notifications
  after insert or update of status on public.confidential_reports
  for each row execute function public.notify_confidential_report_change();

commit;

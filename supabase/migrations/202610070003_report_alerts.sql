begin;

-- Cleaning-duty reports are created by an RPC and previously had no durable
-- notification entry. Keep the notification content intentionally generic;
-- recipients open the protected report to read the private details.
create or replace function public.notify_cleaning_report_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.app_notifications (
      recipient_id,
      notification_type,
      title,
      body,
      route_type,
      route_id,
      data
    )
    select
      profile.id,
      'maintenance',
      'New cleaning-duty report',
      'A tenant submitted a cleaning-duty report. Open the report to review it.',
      'cleaning_report',
      new.id,
      jsonb_build_object(
        'report_id', new.id,
        'status', new.status,
        'server_push', true
      )
    from public.profiles profile
    where profile.role::text in ('owner', 'caretaker');
  elsif new.status is distinct from old.status
     or new.staff_notes is distinct from old.staff_notes then
    insert into public.app_notifications (
      recipient_id,
      notification_type,
      title,
      body,
      route_type,
      route_id,
      data
    ) values (
      new.reporter_id,
      'maintenance',
      'Cleaning report updated',
      'Your cleaning-duty report is now ' || replace(new.status, '_', ' ') || '.',
      'cleaning_report',
      new.id,
      jsonb_build_object(
        'report_id', new.id,
        'status', new.status,
        'server_push', true
      )
    );
  end if;

  return new;
end;
$$;

revoke all on function public.notify_cleaning_report_change()
  from public, anon, authenticated;

drop trigger if exists cleaning_report_notifications
  on public.cleaning_noncompliance_reports;

create trigger cleaning_report_notifications
after insert or update of status, staff_notes
on public.cleaning_noncompliance_reports
for each row
execute function public.notify_cleaning_report_change();

commit;

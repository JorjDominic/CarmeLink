begin;

-- Backend-authoritative notification read state for every authenticated role.
create or replace function public.mark_all_notifications_read()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  update public.app_notifications
  set read_at = coalesce(read_at, now())
  where recipient_id = auth.uid()
    and read_at is null;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.mark_all_notifications_read() from public, anon;
grant execute on function public.mark_all_notifications_read() to authenticated;

create or replace function public.my_unread_notification_count()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.app_notifications
  where recipient_id = auth.uid()
    and read_at is null;
$$;

revoke all on function public.my_unread_notification_count() from public, anon;
grant execute on function public.my_unread_notification_count() to authenticated;

-- Session-driven retention. The app calls this automatically when the
-- notification stream starts. It deletes only notification inbox rows; source
-- payment, maintenance, curfew, gate, visitor and conduct records are untouched.
create or replace function public.cleanup_my_expired_notifications()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  delete from public.app_notifications n
  where n.recipient_id = auth.uid()
    and n.created_at < now() - case
      when n.notification_type in ('curfew', 'safety', 'gate')
        then interval '90 days'
      when n.notification_type in ('payment', 'maintenance', 'visitor', 'onboarding')
        then interval '60 days'
      when n.read_at is null
        then interval '60 days'
      else interval '30 days'
    end;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.cleanup_my_expired_notifications() from public, anon;
grant execute on function public.cleanup_my_expired_notifications() to authenticated;

-- Tenant cancellation keeps an auditable maintenance row instead of deleting it.
create or replace function public.cancel_my_maintenance_report(p_report_id uuid)
returns public.maintenance_reports
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.maintenance_reports;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  update public.maintenance_reports
  set status = 'cancelled',
      updated_at = now()
  where id = p_report_id
    and tenant_id = auth.uid()
    and status = 'pending'
  returning * into v_row;

  if v_row.id is null then
    raise exception 'Only a pending maintenance request can be cancelled';
  end if;

  return v_row;
end;
$$;

revoke all on function public.cancel_my_maintenance_report(uuid) from public, anon;
grant execute on function public.cancel_my_maintenance_report(uuid) to authenticated;

commit;

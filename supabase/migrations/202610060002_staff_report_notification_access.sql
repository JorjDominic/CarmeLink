begin;

-- Owners and caretakers share report review; retain RPC names for existing apps.
create or replace function public.owner_list_confidential_reports()
returns table (
  id uuid, tenant_id uuid, tenant_name text, category text, summary text,
  status text, response_notes text, reviewed_at timestamptz,
  created_at timestamptz, updated_at timestamptz
)
language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(public.current_user_role()::text, '') not in ('owner', 'caretaker') then
    raise exception 'Only owners and caretakers may access confidential reports';
  end if;
  insert into public.confidential_report_audit(actor_id, action, notes)
  values (auth.uid(), 'list_access', 'Opened confidential report register');
  return query
  select r.id, r.tenant_id, p.full_name, r.category, r.summary, r.status,
         coalesce(r.response_notes, ''), r.reviewed_at, r.created_at, r.updated_at
  from public.confidential_reports r
  join public.profiles p on p.id = r.tenant_id
  order by case r.status when 'submitted' then 0 when 'under_review' then 1 else 2 end,
           r.created_at desc;
end;
$$;

create or replace function public.owner_review_confidential_report(
  p_report_id uuid, p_status text, p_notes text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_old_status text; v_row jsonb;
begin
  if coalesce(public.current_user_role()::text, '') not in ('owner', 'caretaker') then
    raise exception 'Only owners and caretakers may review confidential reports';
  end if;
  if p_status not in ('under_review', 'resolved', 'dismissed') then
    raise exception 'Invalid confidential report status';
  end if;
  if char_length(btrim(coalesce(p_notes, ''))) < 5 then
    raise exception 'Review notes must contain at least 5 characters';
  end if;
  select status into v_old_status from public.confidential_reports
  where id = p_report_id for update;
  if not found then raise exception 'Confidential report not found'; end if;
  update public.confidential_reports
  set status = p_status, response_notes = btrim(p_notes),
      reviewed_by = auth.uid(), reviewed_at = now()
  where id = p_report_id;
  insert into public.confidential_report_audit(
    report_id, actor_id, action, previous_status, new_status, notes
  ) values (p_report_id, auth.uid(), 'status_change', v_old_status, p_status, btrim(p_notes));
  select to_jsonb(result_row) into v_row from (
    select r.id, r.tenant_id, p.full_name as tenant_name, r.category,
           r.summary, r.status, coalesce(r.response_notes, '') as response_notes,
           r.reviewed_at, r.created_at, r.updated_at
    from public.confidential_reports r join public.profiles p on p.id = r.tenant_id
    where r.id = p_report_id
  ) result_row;
  return v_row;
end;
$$;

revoke all on function public.owner_list_confidential_reports() from public, anon;
revoke all on function public.owner_review_confidential_report(uuid, text, text) from public, anon;
grant execute on function public.owner_list_confidential_reports() to authenticated;
grant execute on function public.owner_review_confidential_report(uuid, text, text) to authenticated;
comment on table public.confidential_report_audit is
  'Append-only audit trail for staff access and decisions on confidential reports.';

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
    where p.role::text in ('owner', 'caretaker');
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


commit;

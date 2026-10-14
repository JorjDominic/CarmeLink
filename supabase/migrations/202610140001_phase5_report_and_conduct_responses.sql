-- Phase 5. Review locally; deployment requires separate authorization.
-- Reuse existing append-only history. Existing entries stay staff-only.
begin;

alter table public.conduct_case_events
  add column visibility text not null default 'internal'
    check (visibility in ('internal','tenant')),
  add column actor_role text,
  add column client_request_id uuid;
alter table public.conduct_case_events drop constraint conduct_case_events_event_type_check;
alter table public.conduct_case_events add constraint conduct_case_events_event_type_check
  check (event_type in ('case_created','tenant_notified','tenant_response_submitted',
    'review_started','warning_issued','resolved','dismissed',
    'termination_review_recommended','evidence_added','official_response'));
create unique index conduct_event_request on public.conduct_case_events(actor_id,client_request_id)
  where client_request_id is not null;

create function public.add_conduct_official_response(
  p_case_id uuid, p_expected_updated_at timestamptz, p_body text,
  p_visibility text, p_request_id uuid
) returns uuid language plpgsql security definer set search_path='' as $$
declare c public.conduct_cases; e public.conduct_case_events;
  v_role text := public.current_user_role()::text; v_body text := btrim(coalesce(p_body,''));
begin
  if auth.uid() is null or coalesce(v_role,'') not in ('owner','caretaker') then
    raise exception 'Only owners and caretakers may respond' using errcode='42501'; end if;
  if p_request_id is null or p_visibility is null or p_visibility not in ('internal','tenant')
    or char_length(v_body) not between 5 and 4000 then raise exception 'Invalid official response'; end if;
  select * into c from public.conduct_cases where id=p_case_id for update;
  if not found then raise exception 'Case not found'; end if;
  -- A retry after an interrupted successful save returns the original entry.
  select * into e from public.conduct_case_events where actor_id=auth.uid() and client_request_id=p_request_id;
  if found then
    if e.case_id is distinct from p_case_id or e.notes is distinct from v_body
      or e.visibility is distinct from p_visibility then raise exception 'Response request conflict'; end if;
    return e.id;
  end if;
  if c.status in ('draft','resolved','dismissed') or c.tenant_notified_at is null then
    raise exception 'Responses are closed for this conduct case'; end if;
  if p_expected_updated_at is null or c.updated_at is distinct from p_expected_updated_at then
    raise exception 'This case changed. Refresh before continuing.' using errcode='40001'; end if;
  insert into public.conduct_case_events(case_id,event_type,actor_id,actor_name,actor_role,notes,visibility,client_request_id)
    values(c.id,'official_response',auth.uid(),public.conduct_actor_name(),v_role,v_body,p_visibility,p_request_id)
    returning * into e;
  -- Serialize responses with the existing versioned warning/decision RPCs.
  -- Never change status, warnings, appeals, contracts or financial records.
  update public.conduct_cases set updated_at=clock_timestamp() where id=c.id;
  return e.id;
end $$;
revoke all on function public.add_conduct_official_response(uuid,timestamptz,text,text,uuid) from public,anon;
grant execute on function public.add_conduct_official_response(uuid,timestamptz,text,text,uuid) to authenticated;

-- No tenant SELECT policy is added to the staff event/audit table.
create function public.get_my_conduct_official_responses(p_case_id uuid)
returns table(id uuid,body text,actor_name text,actor_role text,created_at timestamptz)
language sql stable security definer set search_path='' as $$
  select e.id,e.notes,e.actor_name,e.actor_role,e.created_at
  from public.conduct_case_events e join public.conduct_cases c on c.id=e.case_id
  where e.case_id=p_case_id and c.tenant_id=auth.uid()
    and public.current_user_role()::text='tenant' and c.tenant_notified_at is not null
    and e.event_type='official_response' and e.visibility='tenant'
  order by e.created_at,e.id;
$$;
revoke all on function public.get_my_conduct_official_responses(uuid) from public,anon;
grant execute on function public.get_my_conduct_official_responses(uuid) to authenticated;

-- Keep the established event notification producer and destinations.
create or replace function public.notify_conduct_report_saved_event()
returns trigger language plpgsql security definer set search_path='' as $$
declare c public.conduct_cases; v_key text;
begin
  if new.event_type in ('tenant_notified','warning_issued') then return new; end if;
  select * into c from public.conduct_cases where id=new.case_id;
  v_key:='conduct_saved:'||new.id::text;
  perform public.emit_staff_notification('safety','Conduct report updated',
    'A change was saved to a conduct report.','conduct_case',new.case_id,
    jsonb_build_object('case_id',new.case_id),v_key,0);
  if c.tenant_notified_at is not null
    and new.event_type not in ('case_created','evidence_added','tenant_response_submitted')
    and (new.event_type<>'official_response' or new.visibility='tenant') then
    perform public.emit_app_notification(c.tenant_id,'safety',
      case when new.event_type='official_response' then 'Official conduct response available' else 'Conduct report updated' end,
      'Open your conduct case to review the update.','conduct_case',new.case_id,
      jsonb_build_object('case_id',new.case_id),v_key,0);
  end if;
  return new;
end $$;
revoke all on function public.notify_conduct_report_saved_event() from public,anon,authenticated;

-- Internal report notes belong to staff-only history, never response_notes or
-- staff_notes, both of which the reporting tenant can already read.
alter table public.maintenance_staff_history add column client_request_id uuid;
create unique index maintenance_note_request on public.maintenance_staff_history(actor_id,client_request_id)
  where client_request_id is not null;
alter table public.confidential_report_audit add column client_request_id uuid;
alter table public.confidential_report_audit drop constraint confidential_report_audit_action_check;
alter table public.confidential_report_audit add constraint confidential_report_audit_action_check
  check(action in ('list_access','status_change','internal_note'));
create unique index confidential_note_request on public.confidential_report_audit(actor_id,client_request_id)
  where client_request_id is not null;

create function public.append_report_internal_note(
  p_report_type text,p_report_id uuid,p_body text,p_request_id uuid
) returns void language plpgsql security definer set search_path='' as $$
declare v_status text; v_body text:=btrim(coalesce(p_body,'')); v_existing record;
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then
    raise exception 'Staff access required' using errcode='42501'; end if;
  if p_request_id is null or char_length(v_body) not between 5 and 2000 then raise exception 'Invalid internal note'; end if;
  if p_report_type='maintenance' then
    select status into v_status from public.maintenance_reports where id=p_report_id for update;
    if not found then raise exception 'Report not found'; end if;
    select report_id,notes into v_existing from public.maintenance_staff_history
      where actor_id=auth.uid() and client_request_id=p_request_id;
    if found then
      if v_existing.report_id is distinct from p_report_id or v_existing.notes is distinct from '[Internal note] '||v_body then raise exception 'Note request conflict'; end if;
      return;
    end if;
    if v_status in ('resolved','cancelled') then raise exception 'Report is finalized'; end if;
    insert into public.maintenance_staff_history(report_id,actor_id,actor_name,previous_status,next_status,notes,client_request_id)
      values(p_report_id,auth.uid(),public.conduct_actor_name(),v_status,v_status,'[Internal note] '||v_body,p_request_id);
  elsif p_report_type='confidential' then
    select status into v_status from public.confidential_reports where id=p_report_id for update;
    if not found then raise exception 'Report not found'; end if;
    select report_id,notes into v_existing from public.confidential_report_audit
      where actor_id=auth.uid() and client_request_id=p_request_id;
    if found then
      if v_existing.report_id is distinct from p_report_id or v_existing.notes is distinct from v_body then raise exception 'Note request conflict'; end if;
      return;
    end if;
    if v_status in ('resolved','dismissed') then raise exception 'Report is finalized'; end if;
    insert into public.confidential_report_audit(report_id,actor_id,action,previous_status,new_status,notes,client_request_id)
      values(p_report_id,auth.uid(),'internal_note',v_status,v_status,v_body,p_request_id);
  else raise exception 'Invalid report type'; end if;
  -- History-only insert: no tenant notification or report content mutation.
end $$;
revoke all on function public.append_report_internal_note(text,uuid,text,uuid) from public,anon;
grant execute on function public.append_report_internal_note(text,uuid,text,uuid) to authenticated;

create function public.get_confidential_report_history(p_report_id uuid)
returns table(id bigint,actor_name text,action text,previous_status text,new_status text,notes text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then
    raise exception 'Staff access required' using errcode='42501'; end if;
  return query select a.id,coalesce(p.full_name,'Staff'),a.action,a.previous_status,a.new_status,a.notes,a.created_at
    from public.confidential_report_audit a left join public.profiles p on p.id=a.actor_id
    where a.report_id=p_report_id order by a.created_at,a.id;
end $$;
revoke all on function public.get_confidential_report_history(uuid) from public,anon;
grant execute on function public.get_confidential_report_history(uuid) to authenticated;

-- Harden the legacy entry point as well, so older clients cannot reopen a
-- finalized confidential report or repeat a decision through the direct API.
create or replace function public.owner_review_confidential_report(p_report_id uuid,p_status text,p_notes text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.confidential_reports; v_row jsonb;
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then raise exception 'Staff access required' using errcode='42501'; end if;
  if p_status is null or p_status not in ('under_review','resolved','dismissed') then raise exception 'Invalid confidential report status'; end if;
  if char_length(btrim(coalesce(p_notes,''))) not between 5 and 1000 then raise exception 'Use 5 to 1000 characters of review notes'; end if;
  select * into r from public.confidential_reports where id=p_report_id for update;
  if not found then raise exception 'Confidential report not found'; end if;
  if r.status in ('resolved','dismissed') or r.status=p_status then raise exception 'That status transition is not allowed'; end if;
  update public.confidential_reports set status=p_status,response_notes=btrim(p_notes),reviewed_by=auth.uid(),reviewed_at=now() where id=r.id;
  insert into public.confidential_report_audit(report_id,actor_id,action,previous_status,new_status,notes)
    values(r.id,auth.uid(),'status_change',r.status,p_status,btrim(p_notes));
  select to_jsonb(x) into v_row from (
    select c.*,p.full_name as tenant_name from public.confidential_reports c join public.profiles p on p.id=c.tenant_id where c.id=r.id
  ) x;
  return v_row;
end $$;

create function public.review_confidential_report_guarded(
  p_report_id uuid,p_expected_updated_at timestamptz,p_status text,p_notes text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.confidential_reports;
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then raise exception 'Staff access required' using errcode='42501'; end if;
  select * into r from public.confidential_reports where id=p_report_id for update;
  if not found then raise exception 'Confidential report not found'; end if;
  if p_expected_updated_at is null or r.updated_at is distinct from p_expected_updated_at then
    raise exception 'This report changed. Refresh before continuing.' using errcode='40001'; end if;
  return public.owner_review_confidential_report(p_report_id,p_status,p_notes);
end $$;
revoke all on function public.owner_review_confidential_report(uuid,text,text),
  public.review_confidential_report_guarded(uuid,timestamptz,text,text) from public,anon;
grant execute on function public.owner_review_confidential_report(uuid,text,text),
  public.review_confidential_report_guarded(uuid,timestamptz,text,text) to authenticated;

-- Preserve tenant explanations and their existing status rule, but invalidate
-- stale staff actions even when an additional explanation leaves status alone.
create or replace function public.submit_conduct_case_response(p_case_id uuid,p_body text)
returns uuid language plpgsql security definer set search_path='' as $$
declare c public.conduct_cases; v_id uuid; v_body text:=btrim(coalesce(p_body,''));
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select * into c from public.conduct_cases where id=p_case_id for update;
  if not found or c.tenant_id<>auth.uid() or c.tenant_notified_at is null then
    raise exception 'This conduct case is not available to your account' using errcode='42501'; end if;
  if c.status in ('draft','resolved','dismissed') then raise exception 'Responses are closed for this conduct case'; end if;
  if char_length(v_body) not between 5 and 4000 then raise exception 'Response must be between 5 and 4000 characters'; end if;
  insert into public.conduct_case_responses(case_id,tenant_id,body) values(c.id,auth.uid(),v_body) returning id into v_id;
  update public.conduct_cases set status=case when status='awaiting_response' then 'under_review' else status end,
    updated_at=clock_timestamp() where id=c.id;
  insert into public.conduct_case_events(case_id,event_type,actor_id,actor_name,notes)
    values(c.id,'tenant_response_submitted',auth.uid(),public.conduct_actor_name(),'Affected tenant submitted a response.');
  return v_id;
end $$;
revoke all on function public.submit_conduct_case_response(uuid,text) from public,anon;
grant execute on function public.submit_conduct_case_response(uuid,text) to authenticated;

notify pgrst,'reload schema';
commit;

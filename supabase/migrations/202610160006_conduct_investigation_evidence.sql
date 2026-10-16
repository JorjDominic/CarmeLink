-- Local validation only. No historical case is inferred to be confirmed.
begin;
alter table public.conduct_case_events add column decision_appeal_id uuid
  references public.conduct_case_appeals(id) on delete restrict;
alter table public.conduct_case_events drop constraint conduct_case_events_event_type_check;
alter table public.conduct_case_events add constraint conduct_case_events_event_type_check
  check(event_type in ('case_created','tenant_notified','tenant_response_submitted',
    'review_started','warning_issued','resolved','dismissed','termination_review_recommended',
    'evidence_added','official_response','investigation_confirmed','investigation_not_confirmed',
    'investigation_overturned'));

-- New explicit outcomes are Owner decisions. Existing Caretaker RPCs are unchanged.
create function public.record_conduct_investigation_decision(
  p_case_id uuid,p_expected_updated_at timestamptz,p_outcome text,p_reason text,
  p_request_id uuid,p_appeal_id uuid default null
) returns uuid language plpgsql security definer set search_path='' as $$
declare c public.conduct_cases; e public.conduct_case_events;
  reason text:=btrim(coalesce(p_reason,'')); kind text;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then
    raise exception 'Only owners may record investigation outcomes' using errcode='42501'; end if;
  if p_outcome is null or p_outcome not in ('confirmed','not_confirmed','overturned')
    or p_request_id is null or char_length(reason) not between 5 and 4000 then
    raise exception 'A valid outcome, request identifier and documented reason are required'; end if;
  kind:='investigation_'||p_outcome;
  select * into c from public.conduct_cases where id=p_case_id for update;
  if not found then raise exception 'Case not found'; end if;
  select * into e from public.conduct_case_events
    where actor_id=auth.uid() and client_request_id=p_request_id;
  if found then
    if e.case_id is distinct from p_case_id or e.event_type is distinct from kind
      or e.notes is distinct from reason or e.decision_appeal_id is distinct from p_appeal_id then
      raise exception 'Decision request conflict'; end if;
    return e.id;
  end if;
  if p_expected_updated_at is null or c.updated_at is distinct from p_expected_updated_at then
    raise exception 'This case changed. Refresh before continuing.' using errcode='40001'; end if;
  if c.tenant_notified_at is null or c.status='draft' then raise exception 'Publish the case first'; end if;
  if p_outcome='overturned' then
    if not exists(select 1 from public.conduct_case_appeals
      where id=p_appeal_id and case_id=c.id and status='accepted') then
      raise exception 'An accepted appeal for this case is required'; end if;
    if (select event_type from public.conduct_case_events where case_id=c.id
      and event_type like 'investigation_%' order by created_at desc,id desc limit 1)
      is distinct from 'investigation_confirmed' then
      raise exception 'Only a confirmed outcome may be overturned'; end if;
  elsif c.status in ('resolved','dismissed') or p_appeal_id is not null then
    raise exception 'Investigation decisions are closed for this case';
  end if;
  insert into public.conduct_case_events(case_id,event_type,actor_id,actor_name,actor_role,
    notes,visibility,client_request_id,decision_appeal_id,created_at)
    values(c.id,kind,auth.uid(),public.conduct_actor_name(),'owner',reason,'tenant',
      p_request_id,p_appeal_id,clock_timestamp()) returning * into e;
  update public.conduct_cases set updated_at=clock_timestamp() where id=c.id;
  return e.id;
end $$;
revoke all on function public.record_conduct_investigation_decision(uuid,timestamptz,text,text,uuid,uuid) from public,anon;
grant execute on function public.record_conduct_investigation_decision(uuid,timestamptz,text,text,uuid,uuid) to authenticated;

-- One guarded projection gives staff and the affected tenant identical published-case counts.
-- Drafts remain staff-only and are not counted in tenant-visible statistics.
create function public.get_conduct_investigation(p_case_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare c public.conduct_cases; result jsonb; counts jsonb; history jsonb;
begin
  select * into c from public.conduct_cases where id=p_case_id;
  if not found or auth.uid() is null or not (
    coalesce(public.is_staff(),false) or (coalesce(public.current_user_role()::text,'')='tenant'
      and c.tenant_id=auth.uid() and c.tenant_notified_at is not null)) then
    raise exception 'This conduct case is not available to your account' using errcode='42501'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'outcome',substr(e.event_type,15),
    'reason',e.notes,'actor_name',e.actor_name,'created_at',e.created_at,
    'appeal_id',e.decision_appeal_id) order by e.created_at desc,e.id desc),'[]'::jsonb)
    into history from public.conduct_case_events e
    where e.case_id=c.id and e.event_type in
      ('investigation_confirmed','investigation_not_confirmed','investigation_overturned');
  with cases as (
    select x.*, d.event_type,
      case when x.source_record_id is not null and x.source_module not in ('manual','other')
        then x.source_module||':'||x.source_record_id else x.id::text end incident_key,
      exists(select 1 from public.conduct_case_appeals a where a.case_id=x.id
        and a.status<>'withdrawn') appealed
    from public.conduct_cases x left join lateral (
      select event_type from public.conduct_case_events where case_id=x.id
        and event_type in ('investigation_confirmed','investigation_not_confirmed','investigation_overturned')
      order by created_at desc,id desc limit 1
    ) d on true where x.tenant_id=c.tenant_id and x.tenant_notified_at is not null
  ) select jsonb_build_object('total',count(*),
    'confirmed',count(distinct incident_key) filter(where event_type='investigation_confirmed' and status<>'dismissed'),
    'pending',count(*) filter(where status not in ('resolved','dismissed') and event_type is null),
    'unconfirmed',count(*) filter(where status='dismissed' or event_type in ('investigation_not_confirmed','investigation_overturned')),
    'closed_without_outcome',count(*) filter(where status='resolved' and event_type is null),
    'appealed',count(*) filter(where appealed)) into counts from cases;
  result:=jsonb_build_object('decisions',history,'counts',counts,'accepted_appeals',(
    select coalesce(jsonb_agg(jsonb_build_object('id',a.id,'submitted_at',a.submitted_at)
      order by a.submitted_at desc,a.id),'[]'::jsonb) from public.conduct_case_appeals a
    where a.case_id=c.id and a.status='accepted'));
  return result;
end $$;
revoke all on function public.get_conduct_investigation(uuid) from public,anon;
grant execute on function public.get_conduct_investigation(uuid) to authenticated;

-- Registered evidence is permanent. Unregistered failed uploads can still be cleaned up.
-- Storage API permission checks must reject replacement/deletion before blob writes.
-- Keep the existing staff scope for unregistered upload cleanup.
alter policy "staff update conduct evidence files" on storage.objects
  using (bucket_id='conduct_case_evidence' and (select public.is_staff())
    and not exists(select 1 from public.conduct_case_evidence e where e.storage_path=storage.objects.name))
  with check (bucket_id='conduct_case_evidence' and (select public.is_staff())
    and not exists(select 1 from public.conduct_case_evidence e where e.storage_path=storage.objects.name));
alter policy "staff delete conduct evidence files" on storage.objects
  using (bucket_id='conduct_case_evidence' and (select public.is_staff())
    and not exists(select 1 from public.conduct_case_evidence e where e.storage_path=storage.objects.name));

create function public.protect_registered_conduct_object() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if old.bucket_id='conduct_case_evidence' and exists(
    select 1 from public.conduct_case_evidence where storage_path=old.name) then
    raise exception 'Registered conduct evidence cannot be replaced or deleted' using errcode='42501';
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end $$;
revoke all on function public.protect_registered_conduct_object() from public,anon,authenticated;
create trigger protect_registered_conduct_object before update or delete on storage.objects
  for each row execute function public.protect_registered_conduct_object();

create or replace function public.register_conduct_case_evidence(
  p_case_id uuid,p_storage_path text,p_original_name text,p_content_type text,
  p_size_bytes bigint,p_caption text default ''
) returns uuid language plpgsql security definer set search_path='' as $$
declare e public.conduct_case_evidence; caption text:=btrim(coalesce(p_caption,'')); obj storage.objects;
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then
    raise exception 'Only owners and caretakers may attach conduct evidence' using errcode='42501'; end if;
  perform 1 from public.conduct_cases where id=p_case_id for update;
  if not found then raise exception 'Conduct case not found'; end if;
  if p_storage_path is null or split_part(p_storage_path,'/',1)<>p_case_id::text
    or p_storage_path !~ '^[0-9a-f-]+/[A-Za-z0-9_.-]+$'
    or btrim(coalesce(p_original_name,''))='' or char_length(p_original_name)>255
    or p_content_type is null or p_content_type not in ('image/jpeg','image/png','image/webp')
    or p_size_bytes is null or p_size_bytes not between 1 and 10485760
    or char_length(caption)>1000 then raise exception 'Invalid evidence metadata or case path'; end if;
  -- Lock serializes registration with storage deletion/replacement.
  select * into obj from storage.objects where bucket_id='conduct_case_evidence'
    and name=p_storage_path for update;
  if not found then raise exception 'Upload the evidence image before registering it'; end if;
  -- Storage metadata is generated by the storage service, not the registering client.
  if obj.metadata->>'mimetype' is distinct from p_content_type
    or (obj.metadata->>'size')::bigint is distinct from p_size_bytes then
    raise exception 'Evidence metadata does not match the uploaded image'; end if;
  select * into e from public.conduct_case_evidence where storage_path=p_storage_path;
  if found then
    if e.case_id is distinct from p_case_id or e.uploaded_by is distinct from auth.uid()
      or e.original_name is distinct from p_original_name or e.caption is distinct from caption
      or e.content_type is distinct from p_content_type or e.size_bytes is distinct from p_size_bytes then
      raise exception 'Evidence request conflict'; end if;
    return e.id;
  end if;
  if obj.owner_id is distinct from auth.uid()::text then
    raise exception 'Evidence must be uploaded by the registering staff member' using errcode='42501'; end if;
  insert into public.conduct_case_evidence(case_id,storage_path,original_name,content_type,size_bytes,caption,uploaded_by)
    values(p_case_id,p_storage_path,p_original_name,p_content_type,p_size_bytes,caption,auth.uid()) returning * into e;
  insert into public.conduct_case_events(case_id,event_type,actor_id,actor_name,actor_role,notes)
    values(p_case_id,'evidence_added',auth.uid(),public.conduct_actor_name(),public.current_user_role()::text,
      case when caption='' then 'Evidence image attached.' else caption end);
  return e.id;
end $$;
-- Keep response retries separate from decision request identifiers.
create or replace function public.add_conduct_official_response(
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
    if e.event_type is distinct from 'official_response' or e.case_id is distinct from p_case_id or e.notes is distinct from v_body
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


commit;

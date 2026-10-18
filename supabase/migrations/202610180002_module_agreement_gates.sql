begin;

-- Preserve existing confidentiality versions and acceptance history.
alter table public.confidentiality_agreement_versions
  add column module text not null default 'confidentiality'
    check (module in ('confidentiality','geofencing'));
alter table public.confidentiality_agreement_versions
  drop constraint confidentiality_agreement_versions_audience_version_key,
  add unique(module,audience,version);
create index module_agreement_latest on public.confidentiality_agreement_versions
  (module,audience,published_at desc,id desc);

create function public.publish_module_agreement(
  p_module text,p_audience text,p_version text,p_content text,p_approved boolean
) returns uuid language plpgsql security definer set search_path='' as $$
declare v public.confidentiality_agreement_versions;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then
    raise exception 'Only owners may publish approved agreements' using errcode='42501'; end if;
  if p_approved is distinct from true then raise exception 'Confirm that this is approved agreement wording'; end if;
  if p_module is null or p_module not in ('confidentiality','geofencing')
    or p_audience is null or p_audience not in ('tenant','guardian')
    or char_length(btrim(coalesce(p_version,''))) not between 1 and 80
    or char_length(btrim(coalesce(p_content,''))) not between 20 and 100000 then
    raise exception 'Valid module, audience, version and approved content are required'; end if;
  perform pg_advisory_xact_lock(hashtextextended('agreement:'||p_module||':'||p_audience,0));
  select * into v from public.confidentiality_agreement_versions
    where module=p_module and audience=p_audience and version=btrim(p_version);
  if found then
    if v.content is distinct from p_content or v.published_by is distinct from auth.uid() then
      raise exception 'This agreement version already exists with different content or publisher'; end if;
    return v.id;
  end if;
  insert into public.confidentiality_agreement_versions(module,audience,version,content,published_by)
    values(p_module,p_audience,btrim(p_version),p_content,auth.uid()) returning id into v.id;
  return v.id;
end $$;

-- Older clients can still publish confidentiality versions, never geofencing.
create or replace function public.publish_confidentiality_agreement(
  p_audience text,p_version text,p_content text,p_approved boolean
) returns uuid language sql security definer set search_path='' as $$
  select public.publish_module_agreement('confidentiality',p_audience,p_version,p_content,p_approved);
$$;

create or replace function public.accept_confidentiality_agreement(
  p_agreement_id uuid,p_reviewed boolean,p_accepted boolean
) returns uuid language plpgsql security definer set search_path='' as $$
declare v public.confidentiality_agreement_versions; a uuid; latest uuid;
  role_name text:=public.current_user_role()::text;
begin
  if auth.uid() is null or coalesce(role_name,'') not in ('tenant','guardian') then
    raise exception 'Only tenants and guardians may accept their own agreements' using errcode='42501'; end if;
  if p_reviewed is distinct from true or p_accepted is distinct from true then
    raise exception 'Review the complete agreement and explicitly accept it'; end if;
  select * into v from public.confidentiality_agreement_versions where id=p_agreement_id and audience=role_name;
  if not found then raise exception 'Agreement is not available to your account' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('agreement:'||v.module||':'||role_name,0));
  select id into latest from public.confidentiality_agreement_versions
    where module=v.module and audience=role_name order by published_at desc,id desc limit 1;
  if latest is distinct from v.id then raise exception 'A newer agreement is available. Refresh and review it first'; end if;
  insert into public.confidentiality_agreement_acceptances(agreement_id,user_id)
    values(v.id,auth.uid()) on conflict(user_id,agreement_id) do nothing;
  select id into a from public.confidentiality_agreement_acceptances where agreement_id=v.id and user_id=auth.uid();
  return a;
end $$;

create function public.module_agreement_status(p_module text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v public.confidentiality_agreement_versions; accepted timestamptz;
begin
  if auth.uid() is null or coalesce(public.current_user_role()::text,'') not in ('tenant','guardian') then
    raise exception 'Participant access required' using errcode='42501'; end if;
  if p_module is null or p_module not in ('confidentiality','geofencing') then raise exception 'Invalid agreement module'; end if;
  select * into v from public.confidentiality_agreement_versions
    where module=p_module and audience=public.current_user_role()::text order by published_at desc,id desc limit 1;
  if not found then return jsonb_build_object('allowed',false,'agreement',null,'accepted_at',null); end if;
  select accepted_at into accepted from public.confidentiality_agreement_acceptances
    where user_id=auth.uid() and agreement_id=v.id;
  return jsonb_build_object('allowed',accepted is not null,'agreement',to_jsonb(v),'accepted_at',accepted);
end $$;

create function public.has_module_agreement(p_module text) returns boolean
language sql stable security definer set search_path='' as $$
  select coalesce((public.module_agreement_status(p_module)->>'allowed')::boolean,false);
$$;
create function public.require_module_agreement(p_module text) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform pg_advisory_xact_lock_shared(hashtextextended('agreement:'||p_module||':'||public.current_user_role()::text,0));
  if not public.has_module_agreement(p_module) then
    raise exception 'MODULE_AGREEMENT_REQUIRED: Review and accept the current % agreement',p_module using errcode='42501';
  end if;
end $$;

-- Staff workflows stay available; participants cannot bypass a gate via REST/RPC.
create function public.guard_module_agreement_write() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if public.current_user_role()::text in ('tenant','guardian') then
    perform public.require_module_agreement(tg_argv[0]);
  end if;
  return new;
end $$;
create trigger aa_confidential_agreement before insert or update on public.confidential_reports
  for each row execute function public.guard_module_agreement_write('confidentiality');
create trigger aa_confidential_addendum_agreement before insert or update on public.confidential_report_addenda
  for each row execute function public.guard_module_agreement_write('confidentiality');
create trigger aa_geofencing_agreement before insert on public.gate_events
  for each row execute function public.guard_module_agreement_write('geofencing');

create policy confidential_agreement_read on public.confidential_reports as restrictive
  for select to authenticated using (public.current_user_role()::text not in ('tenant','guardian')
    or public.has_module_agreement('confidentiality'));
create policy confidential_addendum_agreement_read on public.confidential_report_addenda as restrictive
  for select to authenticated using (public.current_user_role()::text not in ('tenant','guardian')
    or public.has_module_agreement('confidentiality'));
create policy geofencing_agreement_read on public.gate_events as restrictive
  for select to authenticated using (public.current_user_role()::text not in ('tenant','guardian')
    or public.has_module_agreement('geofencing'));

-- The definer addendum reader must also enforce the participant gate.
alter function public.list_confidential_report_addenda(uuid) rename to list_confidential_report_addenda_core;
revoke all on function public.list_confidential_report_addenda_core(uuid) from public,anon,authenticated;
create function public.list_confidential_report_addenda(p_report_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  if public.current_user_role()::text in ('tenant','guardian') then
    perform public.require_module_agreement('confidentiality');
  end if;
  return public.list_confidential_report_addenda_core(p_report_id);
end $$;

revoke all on function public.publish_module_agreement(text,text,text,text,boolean),
  public.module_agreement_status(text),public.has_module_agreement(text),public.require_module_agreement(text),
  public.guard_module_agreement_write(),public.list_confidential_report_addenda(uuid) from public,anon,authenticated;
grant execute on function public.publish_module_agreement(text,text,text,text,boolean),
  public.module_agreement_status(text),public.has_module_agreement(text),public.list_confidential_report_addenda(uuid) to authenticated;

-- Agreement-paused tracking must not be treated as a location-off violation.
create or replace function public.claim_location_monitoring_alerts(p_incident_id uuid default null)
returns setof public.location_monitoring_incidents
language sql security definer set search_path='' as $$
  with pending as (
    select i.id from public.location_monitoring_incidents i
    where i.recovered_at is null
      and (p_incident_id is null or i.id=p_incident_id)
      and (i.dispatch_claimed_until is null or i.dispatch_claimed_until<=now())
      and (i.guardian_notified_at is null or (i.escalated_at is null and i.started_at<=now()-interval '30 minutes'))
      and exists (
        select 1 from public.confidentiality_agreement_acceptances a
        where a.user_id=i.tenant_id and a.agreement_id=(
          select v.id from public.confidentiality_agreement_versions v
          where v.module='geofencing' and v.audience='tenant'
          order by v.published_at desc,v.id desc limit 1
        )
      )
    order by i.started_at limit 50 for update skip locked
  )
  update public.location_monitoring_incidents i set dispatch_claimed_until=now()+interval '5 minutes'
    from pending where i.id=pending.id returning i.*;
$$;
revoke all on function public.claim_location_monitoring_alerts(uuid) from public,anon,authenticated;
grant execute on function public.claim_location_monitoring_alerts(uuid) to service_role;

-- Realtime plus polling/resume checks invalidate open gates and running monitors.
do $$ begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime'
      and schemaname='public' and tablename='confidentiality_agreement_versions') then
      alter publication supabase_realtime add table public.confidentiality_agreement_versions;
    end if;
  end if;
end $$;
notify pgrst,'reload schema';
commit;

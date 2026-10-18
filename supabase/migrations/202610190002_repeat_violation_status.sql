begin;

-- Derived from explicit current outcomes; no account or contract is changed.
create function public.get_tenant_conduct_status(p_tenant_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare total integer; recent integer; last_incident timestamptz;
begin
  if p_tenant_id is null or auth.uid() is null or not coalesce((public.is_staff() or
    (public.current_user_role()::text='tenant' and auth.uid()=p_tenant_id)),false) then
    raise exception 'Conduct status is not available to your account' using errcode='42501';
  end if;
  with confirmed as (
    select case when c.source_record_id is not null and c.source_module not in ('manual','other')
        then c.source_module||':'||c.source_record_id else c.id::text end incident_key,
      c.incident_at
    from public.conduct_cases c
    join lateral (
      select e.event_type from public.conduct_case_events e where e.case_id=c.id
        and e.event_type in ('investigation_confirmed','investigation_not_confirmed','investigation_overturned')
      order by e.created_at desc,e.id desc limit 1
    ) d on d.event_type='investigation_confirmed'
    where c.tenant_id=p_tenant_id and c.tenant_notified_at is not null
      and c.status not in ('draft','dismissed') and c.incident_at<=now()
  ), incidents as (
    -- The earliest incident date prevents duplicate records extending the window.
    select incident_key,min(incident_at) incident_at from confirmed group by incident_key
  ) select count(*),count(*) filter(where incident_at>=now()-interval '90 days'),max(incident_at)
    into total,recent,last_incident from incidents;
  return jsonb_build_object('tenant_id',p_tenant_id,'confirmed',total,'recent_confirmed',recent,
    'window_days',90,'repeat_threshold',2,'continuous_threshold',3,
    'status',case when recent>=3 then 'continuous_violations' when total>=2 then 'repeated_violations'
      when total=1 then 'single_confirmed' else 'no_confirmed' end,
    'last_incident_at',last_incident);
end $$;
revoke all on function public.get_tenant_conduct_status(uuid) from public,anon;
grant execute on function public.get_tenant_conduct_status(uuid) to authenticated;

create function public.list_conduct_tenant_statuses(p_offset integer default 0,p_limit integer default 200)
returns setof jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then
    raise exception 'Staff access required' using errcode='42501'; end if;
  if p_offset is null or p_offset<0 or p_limit is null or p_limit not between 1 and 200 then
    raise exception 'Invalid page'; end if;
  return query select public.get_tenant_conduct_status(t.tenant_id) from (
    select distinct tenant_id from public.conduct_cases order by tenant_id offset p_offset limit p_limit
  ) t;
end $$;
revoke all on function public.list_conduct_tenant_statuses(integer,integer) from public,anon;
grant execute on function public.list_conduct_tenant_statuses(integer,integer) to authenticated;
create or replace function public.get_conduct_investigation(p_case_id uuid) returns jsonb
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
  return result || jsonb_build_object('tenant_status',public.get_tenant_conduct_status(c.tenant_id));
end $$;
commit;

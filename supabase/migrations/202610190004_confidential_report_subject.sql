begin;
-- tenant_id remains the reporter. Never infer a subject for historical reports.
alter table public.confidential_reports
  add column reported_tenant_id uuid references public.profiles(id) on delete restrict,
  add column reported_tenant_name text;
create index confidential_reports_subject_idx on public.confidential_reports(reported_tenant_id,created_at desc);

create function public.guard_confidential_report_subject() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_op='UPDATE' then
    if new.reported_tenant_id is distinct from old.reported_tenant_id
      or new.reported_tenant_name is distinct from old.reported_tenant_name then
      raise exception 'Submitted tenant links cannot be changed. Add a correction instead.';
    end if;
    return new;
  end if;
  if new.reported_tenant_id is null then new.reported_tenant_name:=null; return new; end if;
  if new.reported_tenant_id=new.tenant_id then raise exception 'Select another tenant or leave the tenant unspecified'; end if;
  select p.full_name into new.reported_tenant_name from public.profiles p
    left join public.tenant_details d on d.profile_id=p.id
    where p.id=new.reported_tenant_id and p.role::text='tenant'
      and coalesce(d.residency_status,'active')<>'inactive';
  if not found then raise exception 'Selected tenant is unavailable'; end if;
  return new;
end $$;
revoke all on function public.guard_confidential_report_subject() from public,anon,authenticated;
create trigger confidential_report_subject before insert or update on public.confidential_reports
  for each row execute function public.guard_confidential_report_subject();

-- A narrow, authenticated directory search. Do not widen profile RLS.
create function public.search_reportable_tenants(p_query text,p_offset integer default 0)
returns table(id uuid,display_name text) language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or coalesce(public.current_user_role()::text,'') not in ('tenant','owner','caretaker') then
    raise exception 'Resident or staff access required' using errcode='42501'; end if;
  if public.current_user_role()::text='tenant' then perform public.require_module_agreement('confidentiality'); end if;
  if p_query is null or char_length(btrim(p_query)) not between 2 and 80
    or p_offset is null or p_offset<0 then raise exception 'Enter 2 to 80 characters to search'; end if;
  return query select p.id,p.full_name from public.profiles p
    left join public.tenant_details d on d.profile_id=p.id
    where p.role::text='tenant' and p.id<>auth.uid()
      and coalesce(d.residency_status,'active')<>'inactive'
      and strpos(lower(p.full_name),lower(btrim(p_query)))>0
    order by p.full_name,p.id offset p_offset limit 20;
end $$;
revoke all on function public.search_reportable_tenants(text,integer) from public,anon;
grant execute on function public.search_reportable_tenants(text,integer) to authenticated;

-- Audited staff access to reports about the CASE tenant, not their reporter.
create function public.list_conduct_confidential_sources(p_tenant_id uuid)
returns table(id uuid,category text,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then
    raise exception 'Staff access required' using errcode='42501'; end if;
  insert into public.confidential_report_audit(actor_id,action,notes)
    values(auth.uid(),'list_access','Opened confidential sources for a conduct case');
  return query select r.id,coalesce(r.report_type_label,r.category),r.created_at
    from public.confidential_reports r where r.reported_tenant_id=p_tenant_id
    order by r.created_at desc,r.id limit 30;
end $$;
revoke all on function public.list_conduct_confidential_sources(uuid) from public,anon;
grant execute on function public.list_conduct_confidential_sources(uuid) to authenticated;
-- Preserve the latest configured-category checks and other source validation.
create or replace function public.create_conduct_case(
  p_tenant_id uuid,
  p_category text,
  p_title text,
  p_description text,
  p_incident_at timestamptz,
  p_source_module text default 'manual',
  p_source_record_id text default null,
  p_category_detail text default null,
  p_source_detail text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_case_id uuid;
  v_title text := btrim(coalesce(p_title, ''));
  v_description text := btrim(coalesce(p_description, ''));
  v_category_detail text := nullif(btrim(coalesce(p_category_detail, '')), '');
  v_source_detail text := nullif(btrim(coalesce(p_source_detail, '')), '');
  v_source_record_id text := nullif(btrim(coalesce(p_source_record_id, '')), '');
  v_source_valid boolean := false;
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may create conduct cases'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.profiles
    where id = p_tenant_id
      and role = 'tenant'
  ) then
    raise exception 'Selected tenant was not found';
  end if;

  if not public.is_active_business_category('conduct_category', p_category) then
    raise exception 'Invalid conduct case category';
  end if;

  if exists (select 1 from public.dormitory_options o
    where o.group_key = 'conduct_category' and o.is_active
      and (o.code = p_category or o.label = p_category)
      and public.is_catch_all_dormitory_option(o.id)) then
    if v_category_detail is null
       or char_length(v_category_detail) < 2
       or char_length(v_category_detail) > 120 then
      raise exception 'Please specify the conduct case category';
    end if;
  else
    v_category_detail := null;
  end if;

  if p_source_module not in (
    'manual',
    'confidential_report',
    'room_inspection',
    'cleaning_report',
    'curfew',
    'visitor',
    'maintenance',
    'other'
  ) then
    raise exception 'Invalid conduct case source';
  end if;

  if p_source_module = 'other' then
    if v_source_detail is null
       or char_length(v_source_detail) < 2
       or char_length(v_source_detail) > 120 then
      raise exception 'Please specify the conduct case source';
    end if;
    v_source_record_id := null;
  else
    v_source_detail := null;
  end if;

  if p_source_module = 'manual' then
    v_source_record_id := null;
  end if;

  -- A linked source is optional, but when supplied it must belong to the
  -- selected tenant (or to the tenant's current room/bed for shared records).
  if v_source_record_id is not null then
    case p_source_module
      when 'confidential_report' then
        select exists (
          select 1
          from public.confidential_reports r
          where r.id::text = v_source_record_id
            and r.reported_tenant_id = p_tenant_id
        ) into v_source_valid;
      when 'maintenance' then
        select exists (
          select 1
          from public.maintenance_reports r
          where r.id::text = v_source_record_id
            and r.tenant_id = p_tenant_id
        ) into v_source_valid;
      when 'visitor' then
        select exists (
          select 1
          from public.visitor_requests r
          where r.id::text = v_source_record_id
            and r.tenant_id = p_tenant_id
        ) into v_source_valid;
      when 'curfew' then
        select exists (
          select 1
          from public.curfew_requests r
          where r.id::text = v_source_record_id
            and r.tenant_id = p_tenant_id
        ) into v_source_valid;
      when 'cleaning_report' then
        select exists (
          select 1
          from public.cleaning_noncompliance_reports r
          join public.tenant_assignments a
            on a.bed_space_id = r.reported_bed_space_id
           and a.status = 'active'
          where r.id::text = v_source_record_id
            and a.tenant_id = p_tenant_id
        ) into v_source_valid;
      when 'room_inspection' then
        select exists (
          select 1
          from public.room_inspections i
          join public.bed_spaces b on b.room_id = i.room_id
          join public.tenant_assignments a
            on a.bed_space_id = b.id
           and a.status = 'active'
          where i.id::text = v_source_record_id
            and a.tenant_id = p_tenant_id
        ) into v_source_valid;
      else
        v_source_valid := false;
    end case;

    if not v_source_valid then
      raise exception 'Selected source record does not belong to the selected tenant';
    end if;
  end if;

  if char_length(v_title) < 3 or char_length(v_title) > 160 then
    raise exception 'Case title must be between 3 and 160 characters';
  end if;

  if char_length(v_description) < 10
     or char_length(v_description) > 4000 then
    raise exception 'Case description must be between 10 and 4000 characters';
  end if;

  if p_incident_at > now() + interval '5 minutes' then
    raise exception 'Incident time cannot be in the future';
  end if;

  insert into public.conduct_cases (
    tenant_id,
    category,
    category_detail,
    title,
    description,
    incident_at,
    source_module,
    source_record_id,
    source_detail,
    opened_by
  )
  values (
    p_tenant_id,
    p_category,
    v_category_detail,
    v_title,
    v_description,
    p_incident_at,
    p_source_module,
    v_source_record_id,
    v_source_detail,
    v_actor
  )
  returning id into v_case_id;

  insert into public.conduct_case_events (
    case_id,
    event_type,
    actor_id,
    actor_name,
    notes
  )
  values (
    v_case_id,
    'case_created',
    v_actor,
    public.conduct_actor_name(),
    'Restricted conduct case created as draft.'
  );

  return v_case_id;
end;
$$;
commit;

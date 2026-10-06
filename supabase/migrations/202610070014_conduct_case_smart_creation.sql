begin;

-- Final conduct-case creation cleanup:
-- * preserve a meaningful value when the literal Other choice is used
-- * replace manual source UUID entry with validated linked records
-- * prevent cross-tenant source links
-- * keep historical rows compatible (new detail columns are nullable)

alter table public.conduct_cases
  add column if not exists category_detail text,
  add column if not exists source_detail text;

alter table public.conduct_cases
  drop constraint if exists conduct_cases_category_detail_length_check,
  add constraint conduct_cases_category_detail_length_check
    check (
      category_detail is null
      or char_length(btrim(category_detail)) between 2 and 120
    ),
  drop constraint if exists conduct_cases_source_detail_length_check,
  add constraint conduct_cases_source_detail_length_check
    check (
      source_detail is null
      or char_length(btrim(source_detail)) between 2 and 120
    );

-- Replace the previous RPC with a backward-compatible signature. Existing
-- callers can still omit the new trailing parameters because they have
-- defaults; the new client supplies them when Other is selected.
drop function if exists public.create_conduct_case(
  uuid, text, text, text, timestamptz, text, text
);

create function public.create_conduct_case(
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

  if p_category not in (
    'rule_violation',
    'misconduct',
    'unauthorized_visitor',
    'roommate_conflict',
    'safety',
    'property_damage',
    'curfew',
    'other'
  ) then
    raise exception 'Invalid conduct case category';
  end if;

  if p_category = 'other' then
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
            and r.tenant_id = p_tenant_id
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

revoke all on function public.create_conduct_case(
  uuid, text, text, text, timestamptz, text, text, text, text
) from public, anon;
grant execute on function public.create_conduct_case(
  uuid, text, text, text, timestamptz, text, text, text, text
) to authenticated;

-- Tenant-safe reads may show the specific category because it is part of the
-- conduct allegation itself. Source module, source record, and source detail
-- remain staff-only.
drop function if exists public.get_my_conduct_cases();
create function public.get_my_conduct_cases()
returns table (
  id uuid,
  category text,
  category_detail text,
  title text,
  description text,
  incident_at timestamptz,
  status text,
  tenant_notified_at timestamptz,
  resolution_notes text,
  termination_review_reason text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    c.id,
    c.category,
    c.category_detail,
    c.title,
    c.description,
    c.incident_at,
    c.status,
    c.tenant_notified_at,
    c.resolution_notes,
    c.termination_review_reason,
    c.created_at,
    c.updated_at
  from public.conduct_cases c
  where c.tenant_id = (select auth.uid())
    and c.tenant_notified_at is not null
  order by c.created_at desc;
$$;

revoke all on function public.get_my_conduct_cases()
  from public, anon;
grant execute on function public.get_my_conduct_cases()
  to authenticated;

comment on column public.conduct_cases.category_detail is
  'Specific user-entered value when the canonical conduct category is Other.';
comment on column public.conduct_cases.source_detail is
  'Specific staff-entered source description when the canonical source is Other.';

commit;

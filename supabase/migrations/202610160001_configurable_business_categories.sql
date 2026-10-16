begin;

-- Extend owner-managed business choices. Financial options map to existing
-- accounting categories; source modules, roles, priorities and statuses remain
-- workflow values rather than user-created options.
alter table public.dormitory_options
  drop constraint dormitory_options_group_key_check,
  drop constraint dormitory_options_category_code_check,
  drop constraint dormitory_options_check;
alter table public.dormitory_options
  add constraint dormitory_options_group_key_check check (group_key in (
    'maintenance_category', 'common_area', 'report_type',
    'announcement_category', 'payment_method', 'conduct_category',
    'inspection_category', 'additional_charge_category', 'utility_category',
    'deduction_category', 'feedback_type'
  )),
  add constraint dormitory_options_workflow_mapping_check check (
    case group_key
      when 'report_type' then category_code is not null and category_code in
        ('safety_concern', 'rule_violation', 'roommate_concern', 'other')
      when 'additional_charge_category' then category_code is not null and category_code in
        ('damage', 'fine', 'late_fee', 'cleaning', 'replacement', 'other')
      when 'utility_category' then category_code is not null and category_code in
        ('electricity', 'water', 'internet', 'utility')
      when 'deduction_category' then category_code is not null and category_code in
        ('damage', 'cleaning', 'replacement', 'utility', 'other')
      else category_code is null
    end
  );

insert into public.dormitory_options(group_key, code, label, category_code)
values
  ('conduct_category', 'curfew', 'Curfew', null),
  ('conduct_category', 'misconduct', 'Misconduct', null),
  ('conduct_category', 'property_damage', 'Property damage', null),
  ('conduct_category', 'roommate_conflict', 'Roommate conflict', null),
  ('conduct_category', 'rule_violation', 'Rule violation', null),
  ('conduct_category', 'safety', 'Safety', null),
  ('conduct_category', 'unauthorized_visitor', 'Unauthorized visitor', null),
  ('conduct_category', 'other', 'Other', null),
  ('inspection_category', 'condition', 'Condition', null),
  ('inspection_category', 'cleanliness', 'Cleanliness', null),
  ('inspection_category', 'maintenance', 'Maintenance', null),
  ('inspection_category', 'safety', 'Safety', null),
  ('inspection_category', 'furniture', 'Furniture', null),
  ('inspection_category', 'utilities', 'Utilities', null),
  ('inspection_category', 'other', 'Other', null),
  ('additional_charge_category', 'damage', 'Damage', 'damage'),
  ('additional_charge_category', 'fine', 'Fine', 'fine'),
  ('additional_charge_category', 'late_fee', 'Late fee', 'late_fee'),
  ('additional_charge_category', 'cleaning', 'Cleaning', 'cleaning'),
  ('additional_charge_category', 'replacement', 'Replacement', 'replacement'),
  ('additional_charge_category', 'other', 'Other', 'other'),
  ('utility_category', 'electricity', 'Electricity', 'electricity'),
  ('utility_category', 'water', 'Water', 'water'),
  ('utility_category', 'internet', 'Internet', 'internet'),
  ('utility_category', 'utility', 'Other utility', 'utility'),
  ('deduction_category', 'damage', 'Damage', 'damage'),
  ('deduction_category', 'cleaning', 'Cleaning', 'cleaning'),
  ('deduction_category', 'replacement', 'Replacement', 'replacement'),
  ('deduction_category', 'utility', 'Utility', 'utility'),
  ('deduction_category', 'other', 'Other', 'other'),
  ('feedback_type', 'accessibility', 'Accessibility', null),
  ('feedback_type', 'app_issue', 'App issue', null),
  ('feedback_type', 'compliment', 'Compliment', null),
  ('feedback_type', 'suggestion', 'Suggestion', null),
  ('feedback_type', 'other', 'Other', null)
on conflict (group_key, code) do nothing;

-- Store readable labels on conduct and inspection records as a snapshot.
-- Existing records retain their original codes and remain readable. Archived
-- choices are valid history, but cannot be used for a new record/category.
create or replace function public.is_active_business_category(p_group text, p_value text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.dormitory_options
    where group_key = p_group and is_active
      and (code = p_value or label = p_value)
  );
$$;
revoke all on function public.is_active_business_category(text,text) from public, anon;
grant execute on function public.is_active_business_category(text,text) to authenticated;

create or replace function public.validate_business_category()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and new.category is not distinct from old.category then
    return new;
  end if;
  if not public.is_active_business_category(tg_argv[0], new.category) then
    raise exception 'Choose an active business category';
  end if;
  return new;
end;
$$;

alter table public.conduct_cases drop constraint conduct_cases_category_check;
alter table public.room_inspection_findings drop constraint room_inspection_findings_category_check;
create trigger validate_conduct_category before insert or update of category
on public.conduct_cases for each row execute function public.validate_business_category('conduct_category');
create trigger validate_inspection_category before insert or update of category
on public.room_inspection_findings for each row execute function public.validate_business_category('inspection_category');

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

create or replace function public.add_room_inspection_finding(
  p_inspection_id uuid,
  p_category text,
  p_location_label text,
  p_severity text,
  p_description text,
  p_corrective_action text default '',
  p_action_due_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_inspection public.room_inspections%rowtype;
  v_location text := trim(coalesce(p_location_label, ''));
  v_description text := trim(coalesce(p_description, ''));
  v_action text := trim(coalesce(p_corrective_action, ''));
  v_finding_id uuid;
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may record inspection findings'
      using errcode = '42501';
  end if;

  select *
    into v_inspection
  from public.room_inspections
  where id = p_inspection_id;

  if not found then
    raise exception 'Inspection not found';
  end if;

  if v_inspection.status <> 'in_progress' then
    raise exception 'Findings can be added only while an inspection is in progress';
  end if;

  if not public.is_active_business_category('inspection_category', p_category) then
    raise exception 'Invalid finding category';
  end if;

  if p_severity not in ('note', 'minor', 'moderate', 'major') then
    raise exception 'Invalid finding severity';
  end if;

  if char_length(v_location) < 2 or char_length(v_location) > 120 then
    raise exception 'Finding location must be between 2 and 120 characters';
  end if;

  if char_length(v_description) < 5
     or char_length(v_description) > 2000 then
    raise exception 'Finding description must be between 5 and 2000 characters';
  end if;

  if char_length(v_action) > 2000 then
    raise exception 'Corrective action must be 2000 characters or fewer';
  end if;

  if p_action_due_at is not null and p_action_due_at <= now() then
    raise exception 'Corrective-action due date must be in the future';
  end if;

  insert into public.room_inspection_findings (
    inspection_id,
    category,
    location_label,
    severity,
    description,
    corrective_action,
    action_due_at,
    status,
    created_by
  )
  values (
    p_inspection_id,
    p_category,
    v_location,
    p_severity,
    v_description,
    v_action,
    p_action_due_at,
    'open',
    v_actor
  )
  returning id into v_finding_id;

  return v_finding_id;
end;
$$;

notify pgrst, 'reload schema';
commit;

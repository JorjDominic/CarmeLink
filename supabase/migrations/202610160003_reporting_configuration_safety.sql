-- Local review and validation only. Requires configuration 006, room identity 011,
-- choice standardization 013, concern snapshot 090003 and business categories 160001.
begin;
create or replace function public.snapshot_report_options()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_option public.dormitory_options;
  v_category_is_other boolean;
  v_location_is_other boolean;
begin
  if tg_table_name = 'maintenance_reports' then
    -- Pre-configuration rows may have no matching option. An unchanged legacy
    -- category is history, not a new selection that must still be active.
    if tg_op = 'UPDATE' and new.category_option_id is not distinct from old.category_option_id
       and new.category is not distinct from old.category then
      new.category := old.category;
    elsif new.category_option_id is null then
      select * into v_option
      from public.dormitory_options
      where group_key = 'maintenance_category'
        and is_active
        and lower(btrim(label)) = lower(btrim(new.category))
      limit 1;
      if not found then
        raise exception 'Choose an active maintenance category';
      end if;
      new.category_option_id := v_option.id;
      new.category := v_option.label;
    elsif tg_op = 'INSERT' or new.category_option_id is distinct from old.category_option_id then
      select * into v_option
      from public.dormitory_options
      where id = new.category_option_id
        and group_key = 'maintenance_category'
        and is_active;
      if not found then raise exception 'Choose an active maintenance category'; end if;
      new.category := v_option.label;
    elsif tg_op = 'UPDATE' then
      new.category := old.category;
    end if;

    if new.location_option_id is not null
       and (tg_op = 'INSERT' or new.location_option_id is distinct from old.location_option_id) then
      select * into v_option
      from public.dormitory_options
      where id = new.location_option_id
        and group_key = 'common_area'
        and is_active;
      if not found then raise exception 'Choose an active common area'; end if;
      new.location := v_option.label;
    elsif tg_op = 'UPDATE' and new.location_option_id is not null then
      new.location := old.location;
    end if;
    v_category_is_other := public.is_catch_all_dormitory_option(new.category_option_id)
      or (tg_op = 'UPDATE'
          and new.category_option_id is not distinct from old.category_option_id
          and new.category is not distinct from old.category
          and old.specific_category is not null);
    v_location_is_other := (new.location_option_id is not null
      and public.is_catch_all_dormitory_option(new.location_option_id))
      or (tg_op = 'UPDATE'
          and new.location_option_id is not distinct from old.location_option_id
          and new.location is not distinct from old.location
          and old.specific_location is not null);

    if v_category_is_other then
      if tg_op = 'INSERT'
         or new.category_option_id is distinct from old.category_option_id
         or new.category is distinct from old.category
         or new.specific_category is distinct from old.specific_category then
        if char_length(btrim(coalesce(new.specific_category, ''))) < 2 then
          raise exception 'Please specify the maintenance category';
        end if;
      end if;
      new.specific_category := nullif(btrim(new.specific_category), '');
    else
      new.specific_category := null;
    end if;

    if v_location_is_other then
      if tg_op = 'INSERT'
         or new.location_option_id is distinct from old.location_option_id
         or new.location is distinct from old.location
         or new.specific_location is distinct from old.specific_location then
        if char_length(btrim(coalesce(new.specific_location, ''))) < 2 then
          raise exception 'Please specify the maintenance location';
        end if;
      end if;
      new.specific_location := nullif(btrim(new.specific_location), '');
    else
      new.specific_location := null;
    end if;
  else
    -- Reviews of an unchanged report retain the original snapshot, even after
    -- its option is renamed or archived. New/changed selections remain active-only.
    if tg_op = 'UPDATE' and new.report_type_id is not distinct from old.report_type_id
       and new.category is not distinct from old.category then
      new.report_type_label := old.report_type_label;
      return new;
    end if;
    if new.report_type_id is null then
      select * into v_option
      from public.dormitory_options
      where group_key = 'report_type'
        and is_active
        and category_code = new.category
      order by is_system desc, sort_order, label
      limit 1;
      if not found then raise exception 'Choose an active report type'; end if;
      new.report_type_id := v_option.id;
    else
      select * into v_option
      from public.dormitory_options
      where id = new.report_type_id
        and group_key = 'report_type'
        and is_active;
      if not found then raise exception 'Choose an active report type'; end if;
    end if;

    new.category := v_option.category_code;
    new.report_type_label := v_option.label;
    -- Match the shared application's catch-all detection, not workflow mapping.
    if replace(replace(lower(btrim(v_option.code)), '-', '_'), ' ', '_') ~ '^others?($|_)'
       or lower(btrim(v_option.label)) ~ '^others?($| )' then
      if char_length(btrim(coalesce(new.specific_concern, ''))) < 2 then
        raise exception 'Please specify the concern';
      end if;
    else
      new.specific_concern := null;
    end if;
  end if;

  return new;
end;
$$;

-- Submission time is a server fact, separate from editable incident_at.
-- Existing rows are never backfilled or rewritten by this migration.
create or replace function public.enforce_report_submission_time()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := statement_timestamp();
  elsif new.created_at is distinct from old.created_at then
    raise exception 'Original report submission time cannot be changed';
  end if;
  return new;
end;
$$;
create trigger aa_maintenance_submission_time before insert or update on public.maintenance_reports
for each row execute function public.enforce_report_submission_time();
create trigger aa_concern_submission_time before insert or update on public.confidential_reports
for each row execute function public.enforce_report_submission_time();
create trigger aa_conduct_submission_time before insert or update on public.conduct_cases
for each row execute function public.enforce_report_submission_time();

-- The existing linker records room identity, but previously accepted arbitrary
-- strings (including archived rooms). Validate new selections after snapshots
-- and before zz_link_maintenance_room; unchanged historical locations are valid.
create or replace function public.validate_maintenance_location()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and new.location is not distinct from old.location
     and new.location_option_id is not distinct from old.location_option_id then
    return new;
  end if;
  if new.location_option_id is not null then
    return new; -- snapshot_report_options already validates group and activity.
  end if;
  if not exists (
    select 1 from public.rooms r where r.is_active
      and lower(btrim(new.location)) in
        (lower('Room ' || r.room_number), lower('Room ' || r.room_number || ' • Bathroom'))
  ) then
    raise exception 'Choose an active room or common area';
  end if;
  return new;
end;
$$;
create trigger zy_validate_maintenance_location before insert or update on public.maintenance_reports
for each row execute function public.validate_maintenance_location();
revoke all on function public.enforce_report_submission_time(), public.validate_maintenance_location()
from public, anon, authenticated;

-- Retain the existing assigned-room scope; archived rooms are history only.
create or replace function public.list_maintenance_room_locations()
returns table(location_label text)
language sql security definer set search_path = '' as $$
  select distinct 'Room ' || r.room_number || suffix.value
  from public.tenant_assignments a
  join public.bed_spaces b on b.id = a.bed_space_id
  join public.rooms r on r.id = b.room_id
  cross join (values (''), (' • Bathroom')) suffix(value)
  where a.tenant_id = auth.uid() and a.status = 'active' and r.is_active
  order by 1;
$$;
revoke all on function public.list_maintenance_room_locations() from public, anon;
grant execute on function public.list_maintenance_room_locations() to authenticated;
commit;

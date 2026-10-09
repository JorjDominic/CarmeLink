-- REVIEW ONLY: apply after configuration 006 and Phase 2/3 migrations.
-- Preserves existing RLS, IDs, maintenance rules and historical report labels.
begin;
create or replace function public.snapshot_report_options()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_option public.dormitory_options;
begin
  if tg_table_name = 'maintenance_reports' then
    if new.category_option_id is null then
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
commit;

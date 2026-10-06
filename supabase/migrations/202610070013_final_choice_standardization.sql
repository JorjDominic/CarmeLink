begin;

-- Final configuration standardization:
-- * choices are alphabetized automatically
-- * catch-all Other choices remain last
-- * maintenance Other values retain a stable option plus specific user text
-- * custom descriptive concern types mapped to the generic workflow no longer
--   behave like the literal catch-all Other choice

alter table public.maintenance_reports
  add column if not exists specific_category text
    check (
      specific_category is null
      or char_length(btrim(specific_category)) between 2 and 120
    ),
  add column if not exists specific_location text
    check (
      specific_location is null
      or char_length(btrim(specific_location)) between 2 and 120
    );

create or replace function public.is_catch_all_dormitory_option(
  p_option_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select
      lower(
        replace(replace(btrim(option_row.code), '-', '_'), ' ', '_')
      ) in ('other', 'others')
      or left(
        lower(replace(replace(btrim(option_row.code), '-', '_'), ' ', '_')),
        6
      ) = 'other_'
      or left(
        lower(replace(replace(btrim(option_row.code), '-', '_'), ' ', '_')),
        7
      ) = 'others_'
      or lower(btrim(option_row.label)) in ('other', 'others')
      or lower(btrim(option_row.label)) like 'other %'
      or lower(btrim(option_row.label)) like 'others %'
    from public.dormitory_options option_row
    where option_row.id = p_option_id
  ), false);
$$;

create or replace function public.normalize_dormitory_option_order(
  p_group_key text
)
returns void
language sql
security definer
set search_path = ''
as $$
  with ranked as (
    select
      option_row.id,
      row_number() over (
        order by
          public.is_catch_all_dormitory_option(option_row.id),
          lower(btrim(option_row.label)),
          option_row.created_at,
          option_row.id
      )::integer as next_order
    from public.dormitory_options option_row
    where option_row.group_key = p_group_key
  )
  update public.dormitory_options option_row
  set sort_order = ranked.next_order
  from ranked
  where option_row.id = ranked.id
    and option_row.sort_order is distinct from ranked.next_order;
$$;

create or replace function public.normalize_dormitory_option_order_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.normalize_dormitory_option_order(new.group_key);
  return new;
end;
$$;

drop trigger if exists normalize_dormitory_option_order
  on public.dormitory_options;
create trigger normalize_dormitory_option_order
after insert or update of label, is_active
on public.dormitory_options
for each row execute function public.normalize_dormitory_option_order_trigger();

do $$
declare
  v_group text;
begin
  for v_group in
    select distinct group_key from public.dormitory_options
  loop
    perform public.normalize_dormitory_option_order(v_group);
  end loop;
end;
$$;

create or replace function public.snapshot_report_options()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_option public.dormitory_options;
  v_category_is_other boolean := false;
  v_location_is_other boolean := false;
  v_report_type_is_other boolean := false;
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
    elsif tg_op = 'INSERT'
       or new.category_option_id is distinct from old.category_option_id then
      select * into v_option
      from public.dormitory_options
      where id = new.category_option_id
        and group_key = 'maintenance_category'
        and is_active;
      if not found then
        raise exception 'Choose an active maintenance category';
      end if;
      new.category := v_option.label;
    elsif tg_op = 'UPDATE' then
      new.category := old.category;
    end if;

    v_category_is_other :=
      public.is_catch_all_dormitory_option(new.category_option_id);

    if new.location_option_id is not null
       and (
         tg_op = 'INSERT'
         or new.location_option_id is distinct from old.location_option_id
       ) then
      select * into v_option
      from public.dormitory_options
      where id = new.location_option_id
        and group_key = 'common_area'
        and is_active;
      if not found then
        raise exception 'Choose an active common area';
      end if;
      new.location := v_option.label;
    elsif tg_op = 'UPDATE' and new.location_option_id is not null then
      new.location := old.location;
    end if;

    v_location_is_other := new.location_option_id is not null
      and public.is_catch_all_dormitory_option(new.location_option_id);

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
    if new.report_type_id is null then
      select * into v_option
      from public.dormitory_options
      where group_key = 'report_type'
        and is_active
        and category_code = new.category
      order by
        public.is_catch_all_dormitory_option(id) desc,
        sort_order,
        label
      limit 1;
      if not found then
        raise exception 'Choose an active report type';
      end if;
      new.report_type_id := v_option.id;
    else
      select * into v_option
      from public.dormitory_options
      where id = new.report_type_id
        and group_key = 'report_type'
        and is_active;
      if not found then
        raise exception 'Choose an active report type';
      end if;
    end if;

    new.category := v_option.category_code;
    new.report_type_label := v_option.label;
    v_report_type_is_other :=
      public.is_catch_all_dormitory_option(v_option.id);

    if v_report_type_is_other then
      if char_length(btrim(coalesce(new.specific_concern, ''))) < 2 then
        raise exception 'Please specify the concern';
      end if;
      new.specific_concern := nullif(btrim(new.specific_concern), '');
    else
      new.specific_concern := null;
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.is_catch_all_dormitory_option(uuid)
  from public, anon, authenticated;
revoke all on function public.normalize_dormitory_option_order(text)
  from public, anon, authenticated;
revoke all on function public.normalize_dormitory_option_order_trigger()
  from public, anon, authenticated;
revoke all on function public.snapshot_report_options()
  from public, anon, authenticated;

comment on column public.maintenance_reports.specific_category is
  'Specific text required when a catch-all maintenance category is selected.';
comment on column public.maintenance_reports.specific_location is
  'Specific text required when a catch-all common-area option is selected.';

commit;

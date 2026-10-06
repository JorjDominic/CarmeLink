begin;

create table if not exists public.dormitory_options (
  id uuid primary key default gen_random_uuid(),
  group_key text not null check (
    group_key in ('maintenance_category', 'common_area', 'report_type')
  ),
  code text not null default gen_random_uuid()::text,
  label text not null check (char_length(btrim(label)) between 2 and 80),
  category_code text check (
    category_code in ('safety_concern', 'rule_violation', 'roommate_concern', 'other')
  ),
  sort_order integer not null default 0 check (sort_order between 0 and 9999),
  is_active boolean not null default true,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (group_key, code),
  check ((group_key = 'report_type') = (category_code is not null))
);

create unique index if not exists dormitory_options_label_key
  on public.dormitory_options(group_key, lower(btrim(label)));

alter table public.dormitory_options enable row level security;
revoke all on public.dormitory_options from public, anon, authenticated;
grant select, insert, update on public.dormitory_options to authenticated;

create policy "read active dormitory options"
  on public.dormitory_options for select to authenticated
  using (is_active or (select public.is_owner()));

create policy "owner adds dormitory options"
  on public.dormitory_options for insert to authenticated
  with check ((select public.is_owner()) and not is_system);

create policy "owner edits dormitory options"
  on public.dormitory_options for update to authenticated
  using ((select public.is_owner()) and not is_system)
  with check ((select public.is_owner()) and not is_system);

create or replace function public.protect_dormitory_option()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.code <> old.code
     or new.group_key <> old.group_key
     or new.is_system <> old.is_system
     or new.category_code is distinct from old.category_code then
    raise exception 'Option identity and workflow mapping cannot be changed';
  end if;
  new.label := btrim(new.label);
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists protect_dormitory_option on public.dormitory_options;
create trigger protect_dormitory_option
  before update on public.dormitory_options
  for each row execute function public.protect_dormitory_option();

insert into public.dormitory_options(group_key, code, label, sort_order)
select 'maintenance_category', code, label, ordinality::integer
from unnest(array[
  'plumbing|Plumbing',
  'electrical|Electrical',
  'furniture|Furniture',
  'air_conditioning|Air conditioning',
  'locks_keys|Locks & Keys',
  'structural|Structural',
  'other|Other'
]) with ordinality raw(item, ordinality)
cross join lateral (
  select split_part(item, '|', 1) as code,
         split_part(item, '|', 2) as label
) parsed
on conflict do nothing;

insert into public.dormitory_options(group_key, code, label, sort_order)
select 'common_area', code, label, ordinality::integer
from unnest(array[
  'second_floor_corridor|Second-floor corridor',
  'first_floor_hallway|First-floor hallway',
  'kitchen_dining|Kitchen / Dining area',
  'laundry_area|Laundry area',
  'study_lounge|Study lounge',
  'ground_floor_lobby|Ground floor lobby',
  'other_common_area|Other common area'
]) with ordinality raw(item, ordinality)
cross join lateral (
  select split_part(item, '|', 1) as code,
         split_part(item, '|', 2) as label
) parsed
on conflict do nothing;

insert into public.dormitory_options(
  group_key, code, label, category_code, sort_order, is_system
) values
  ('report_type', 'safety_concern', 'Safety concern', 'safety_concern', 1, false),
  ('report_type', 'rule_violation', 'Rule violation', 'rule_violation', 2, false),
  ('report_type', 'roommate_concern', 'Roommate concern', 'roommate_concern', 3, false),
  ('report_type', 'other', 'Other', 'other', 99, true)
on conflict do nothing;

alter table public.maintenance_reports
  add column if not exists category_option_id uuid references public.dormitory_options(id),
  add column if not exists location_option_id uuid references public.dormitory_options(id);

alter table public.confidential_reports
  add column if not exists report_type_id uuid references public.dormitory_options(id),
  add column if not exists report_type_label text,
  add column if not exists specific_concern text
    check (specific_concern is null or char_length(btrim(specific_concern)) between 2 and 120);

update public.maintenance_reports m
set category_option_id = o.id
from public.dormitory_options o
where m.category_option_id is null
  and o.group_key = 'maintenance_category'
  and lower(btrim(o.label)) = lower(btrim(m.category));

update public.maintenance_reports m
set location_option_id = o.id
from public.dormitory_options o
where m.location_option_id is null
  and o.group_key = 'common_area'
  and lower(btrim(o.label)) = lower(btrim(m.location));

update public.confidential_reports r
set report_type_id = o.id,
    report_type_label = o.label
from public.dormitory_options o
where r.report_type_id is null
  and o.group_key = 'report_type'
  and o.code = r.category;

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
    if v_option.category_code = 'other'
       and char_length(btrim(coalesce(new.specific_concern, ''))) < 2 then
      raise exception 'Please specify the concern';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists snapshot_maintenance_options on public.maintenance_reports;
create trigger snapshot_maintenance_options
  before insert or update on public.maintenance_reports
  for each row execute function public.snapshot_report_options();

drop trigger if exists snapshot_concern_options on public.confidential_reports;
create trigger snapshot_concern_options
  before insert on public.confidential_reports
  for each row execute function public.snapshot_report_options();

create table if not exists public.confidential_report_addenda (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.confidential_reports(id) on delete restrict,
  author_id uuid not null default auth.uid() references public.profiles(id) on delete restrict,
  body text not null check (char_length(btrim(body)) between 5 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists confidential_report_addenda_report_idx
  on public.confidential_report_addenda(report_id, created_at);

alter table public.confidential_report_addenda enable row level security;
revoke all on public.confidential_report_addenda from public, anon, authenticated;
grant select, insert on public.confidential_report_addenda to authenticated;

create policy "report participants read addenda"
  on public.confidential_report_addenda for select to authenticated
  using (
    (select public.is_staff())
    or exists (
      select 1 from public.confidential_reports r
      where r.id = report_id and r.tenant_id = (select auth.uid())
    )
  );

create policy "report participants append addenda"
  on public.confidential_report_addenda for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and (
      (select public.is_staff())
      or exists (
        select 1 from public.confidential_reports r
        where r.id = report_id and r.tenant_id = (select auth.uid())
      )
    )
  );

create or replace function public.list_confidential_reports_v2()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not coalesce(public.is_staff(), false) then
    raise exception 'Staff access required';
  end if;
  insert into public.confidential_report_audit(actor_id, action, notes)
  values (auth.uid(), 'list_access', 'Opened confidential report register');
  return coalesce((
    select jsonb_agg(
      to_jsonb(r) || jsonb_build_object('tenant_name', p.full_name)
      order by case r.status when 'submitted' then 0 when 'under_review' then 1 else 2 end,
               r.created_at desc
    )
    from public.confidential_reports r
    join public.profiles p on p.id = r.tenant_id
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.list_confidential_reports_v2() from public, anon;
grant execute on function public.list_confidential_reports_v2() to authenticated;

create or replace function public.list_confidential_report_addenda(p_report_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_allowed boolean;
begin
  select (
    coalesce(public.is_staff(), false)
    or exists (
      select 1 from public.confidential_reports r
      where r.id = p_report_id and r.tenant_id = auth.uid()
    )
  ) into v_allowed;
  if not coalesce(v_allowed, false) then
    raise exception 'Report access denied';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', a.id,
        'report_id', a.report_id,
        'author_id', a.author_id,
        'author_name', p.full_name,
        'author_role', p.role::text,
        'body', a.body,
        'created_at', a.created_at
      ) order by a.created_at
    )
    from public.confidential_report_addenda a
    join public.profiles p on p.id = a.author_id
    where a.report_id = p_report_id
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.list_confidential_report_addenda(uuid) from public, anon;
grant execute on function public.list_confidential_report_addenda(uuid) to authenticated;

create or replace function public.list_maintenance_room_locations()
returns table(location_label text)
language sql
security definer
set search_path = ''
as $$
  select label
  from (
    select 1 as position, 'Room ' || r.room_number as label
    from public.tenant_assignments a
    join public.bed_spaces b on b.id = a.bed_space_id
    join public.rooms r on r.id = b.room_id
    where a.tenant_id = auth.uid() and a.status = 'active'
    union all
    select 2, 'Room ' || r.room_number || ' • Bathroom'
    from public.tenant_assignments a
    join public.bed_spaces b on b.id = a.bed_space_id
    join public.rooms r on r.id = b.room_id
    where a.tenant_id = auth.uid() and a.status = 'active'
  ) locations
  order by position;
$$;

revoke all on function public.list_maintenance_room_locations() from public, anon;
grant execute on function public.list_maintenance_room_locations() to authenticated;

commit;

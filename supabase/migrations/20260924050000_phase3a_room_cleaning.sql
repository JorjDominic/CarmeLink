begin;

-- Phase 3A: Room Operations / Cleaning Schedule
--
-- Scope:
--   * staff-managed cleaning rota by bed identifier
--   * tenant view restricted to the rota for the tenant's own room
--   * private tenant non-compliance reports
--   * staff-only report review history
--
-- Deliberately excluded:
--   * penalties / damage charges
--   * disciplinary-case creation
--   * assignment, contract, activation, or move-out transitions
--   * Room Inspections (Phase 3B)

create table public.cleaning_schedules (
  id uuid primary key default gen_random_uuid(),
  bed_space_id uuid not null
    references public.bed_spaces(id) on delete cascade,
  weekday smallint not null
    check (weekday between 1 and 7),
  task_notes text not null default ''
    check (char_length(task_notes) <= 500),
  is_active boolean not null default true,
  created_by uuid not null
    references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (bed_space_id, weekday)
);

create index cleaning_schedules_bed_weekday_idx
  on public.cleaning_schedules(bed_space_id, weekday);

create trigger cleaning_schedules_set_updated_at
before update on public.cleaning_schedules
for each row
execute function public.set_updated_at();

alter table public.cleaning_schedules enable row level security;

revoke all on public.cleaning_schedules from anon, authenticated;
grant select on public.cleaning_schedules to authenticated;

create or replace function public.current_tenant_room_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select b.room_id
  from public.tenant_assignments a
  join public.bed_spaces b on b.id = a.bed_space_id
  where a.tenant_id = (select auth.uid())
    and a.status = 'active'
  limit 1;
$$;

create or replace function public.current_tenant_bed_space_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select a.bed_space_id
  from public.tenant_assignments a
  where a.tenant_id = (select auth.uid())
    and a.status = 'active'
  limit 1;
$$;

create or replace function public.cleaning_schedule_visible_to_current_tenant(
  p_bed_space_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    exists (
      select 1
      from public.bed_spaces b
      where b.id = p_bed_space_id
        and b.room_id = public.current_tenant_room_id()
    ),
    false
  );
$$;

revoke all on function public.current_tenant_room_id()
  from public, anon, authenticated;
revoke all on function public.current_tenant_bed_space_id()
  from public, anon, authenticated;
revoke all on function public.cleaning_schedule_visible_to_current_tenant(uuid)
  from public, anon, authenticated;

grant execute on function public.current_tenant_room_id()
  to authenticated;
grant execute on function public.current_tenant_bed_space_id()
  to authenticated;
grant execute on function public.cleaning_schedule_visible_to_current_tenant(uuid)
  to authenticated;

create policy "staff read cleaning schedules"
on public.cleaning_schedules
for select
to authenticated
using ((select public.is_staff()));

create policy "tenant read own room cleaning schedules"
on public.cleaning_schedules
for select
to authenticated
using (
  public.cleaning_schedule_visible_to_current_tenant(bed_space_id)
);

create or replace function public.set_cleaning_schedule(
  p_bed_space_id uuid,
  p_weekdays integer[],
  p_task_notes text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_notes text := trim(coalesce(p_task_notes, ''));
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may manage cleaning schedules'
      using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.bed_spaces
    where id = p_bed_space_id
  ) then
    raise exception 'Bed space not found';
  end if;

  if p_weekdays is null then
    raise exception 'Weekday selection is required';
  end if;

  if exists (
    select 1
    from unnest(p_weekdays) as selected_day
    where selected_day < 1 or selected_day > 7
  ) then
    raise exception 'Weekdays must be between Monday and Sunday';
  end if;

  if char_length(v_notes) > 500 then
    raise exception 'Cleaning instructions must be 500 characters or fewer';
  end if;

  delete from public.cleaning_schedules
  where bed_space_id = p_bed_space_id;

  insert into public.cleaning_schedules (
    bed_space_id,
    weekday,
    task_notes,
    is_active,
    created_by
  )
  select
    p_bed_space_id,
    days.selected_day,
    v_notes,
    true,
    v_actor
  from (
    select distinct unnest(p_weekdays) as selected_day
  ) days
  order by days.selected_day;
end;
$$;

revoke all on function public.set_cleaning_schedule(uuid, integer[], text)
  from public, anon;
grant execute on function public.set_cleaning_schedule(uuid, integer[], text)
  to authenticated;

create or replace function public.get_my_room_cleaning_schedule()
returns table (
  bed_space_id uuid,
  bed_label text,
  weekday smallint,
  task_notes text,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_room_id uuid;
begin
  if auth.uid() is null
     or not exists (
       select 1
       from public.profiles
       where id = (select auth.uid())
         and role = 'tenant'
     ) then
    raise exception 'Only tenants may view their room cleaning schedule'
      using errcode = '42501';
  end if;

  v_room_id := public.current_tenant_room_id();

  if v_room_id is null then
    return;
  end if;

  return query
  select
    s.bed_space_id,
    b.label,
    s.weekday,
    s.task_notes,
    s.updated_at
  from public.cleaning_schedules s
  join public.bed_spaces b on b.id = s.bed_space_id
  where b.room_id = v_room_id
    and s.is_active
  order by s.weekday, b.label;
end;
$$;

revoke all on function public.get_my_room_cleaning_schedule()
  from public, anon;
grant execute on function public.get_my_room_cleaning_schedule()
  to authenticated;

create table public.cleaning_noncompliance_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null
    references public.profiles(id) on delete restrict,
  reported_bed_space_id uuid not null
    references public.bed_spaces(id) on delete restrict,
  reported_bed_label text not null,
  description text not null
    check (char_length(description) between 5 and 1500),
  status text not null default 'open'
    check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  staff_notes text not null default ''
    check (char_length(staff_notes) <= 2000),
  handled_by uuid
    references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index cleaning_reports_reporter_idx
  on public.cleaning_noncompliance_reports(reporter_id, created_at desc);
create index cleaning_reports_bed_idx
  on public.cleaning_noncompliance_reports(reported_bed_space_id, created_at desc);
create index cleaning_reports_status_idx
  on public.cleaning_noncompliance_reports(status, created_at desc);

create trigger cleaning_reports_set_updated_at
before update on public.cleaning_noncompliance_reports
for each row
execute function public.set_updated_at();

alter table public.cleaning_noncompliance_reports enable row level security;

revoke all on public.cleaning_noncompliance_reports from anon, authenticated;
grant select on public.cleaning_noncompliance_reports to authenticated;

create policy "tenant read own cleaning reports"
on public.cleaning_noncompliance_reports
for select
to authenticated
using (reporter_id = (select auth.uid()));

create policy "staff read cleaning reports"
on public.cleaning_noncompliance_reports
for select
to authenticated
using ((select public.is_staff()));

create table public.cleaning_report_history (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null
    references public.cleaning_noncompliance_reports(id) on delete cascade,
  actor_id uuid
    references public.profiles(id) on delete set null,
  actor_name text not null,
  previous_status text not null,
  next_status text not null,
  notes text not null default '',
  created_at timestamptz not null default now()
);

create index cleaning_report_history_report_idx
  on public.cleaning_report_history(report_id, created_at desc);

alter table public.cleaning_report_history enable row level security;

revoke all on public.cleaning_report_history from anon, authenticated;
grant select on public.cleaning_report_history to authenticated;

create policy "staff read cleaning report history"
on public.cleaning_report_history
for select
to authenticated
using ((select public.is_staff()));

create or replace function public.submit_cleaning_noncompliance_report(
  p_reported_bed_space_id uuid,
  p_description text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_own_bed uuid;
  v_own_room uuid;
  v_reported_room uuid;
  v_bed_label text;
  v_description text := trim(coalesce(p_description, ''));
  v_report_id uuid;
begin
  if v_actor is null
     or not exists (
       select 1
       from public.profiles
       where id = v_actor
         and role = 'tenant'
     ) then
    raise exception 'Only tenants may submit cleaning reports'
      using errcode = '42501';
  end if;

  v_own_bed := public.current_tenant_bed_space_id();
  v_own_room := public.current_tenant_room_id();

  if v_own_bed is null or v_own_room is null then
    raise exception 'An active room assignment is required';
  end if;

  select b.room_id, b.label
    into v_reported_room, v_bed_label
  from public.bed_spaces b
  where b.id = p_reported_bed_space_id;

  if not found then
    raise exception 'Reported bed space not found';
  end if;

  if v_reported_room <> v_own_room then
    raise exception 'You may report cleaning issues only within your assigned room'
      using errcode = '42501';
  end if;

  if p_reported_bed_space_id = v_own_bed then
    raise exception 'Choose another assigned bed for this report';
  end if;

  if not exists (
    select 1
    from public.cleaning_schedules s
    where s.bed_space_id = p_reported_bed_space_id
      and s.is_active
  ) then
    raise exception 'That bed has no active cleaning duty to report';
  end if;

  if char_length(v_description) < 5
     or char_length(v_description) > 1500 then
    raise exception 'Report details must be between 5 and 1500 characters';
  end if;

  insert into public.cleaning_noncompliance_reports (
    reporter_id,
    reported_bed_space_id,
    reported_bed_label,
    description
  )
  values (
    v_actor,
    p_reported_bed_space_id,
    v_bed_label,
    v_description
  )
  returning id into v_report_id;

  return v_report_id;
end;
$$;

revoke all on function public.submit_cleaning_noncompliance_report(uuid, text)
  from public, anon;
grant execute on function public.submit_cleaning_noncompliance_report(uuid, text)
  to authenticated;

create or replace function public.update_cleaning_noncompliance_report(
  p_report_id uuid,
  p_expected_updated_at timestamptz,
  p_status text,
  p_staff_notes text default ''
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_actor_name text;
  v_report public.cleaning_noncompliance_reports%rowtype;
  v_notes text := trim(coalesce(p_staff_notes, ''));
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may review cleaning reports'
      using errcode = '42501';
  end if;

  if p_status not in ('open', 'reviewing', 'resolved', 'dismissed') then
    raise exception 'Invalid cleaning report status';
  end if;

  if char_length(v_notes) > 2000 then
    raise exception 'Staff notes must be 2000 characters or fewer';
  end if;

  if p_status in ('resolved', 'dismissed') and v_notes = '' then
    raise exception 'Add resolution notes or a dismissal reason';
  end if;

  select *
    into v_report
  from public.cleaning_noncompliance_reports
  where id = p_report_id
  for update;

  if not found then
    raise exception 'This cleaning report no longer exists. Refresh the page.';
  end if;

  if p_expected_updated_at is null
     or v_report.updated_at is distinct from p_expected_updated_at then
    raise exception 'This cleaning report changed. Reload it before saving.'
      using errcode = '40001';
  end if;

  if p_status = v_report.status
     and v_notes = v_report.staff_notes then
    return;
  end if;

  select full_name
    into v_actor_name
  from public.profiles
  where id = v_actor;

  update public.cleaning_noncompliance_reports
  set
    status = p_status,
    staff_notes = v_notes,
    handled_by = v_actor,
    resolved_at = case
      when p_status in ('resolved', 'dismissed') then now()
      else null
    end
  where id = p_report_id;

  insert into public.cleaning_report_history (
    report_id,
    actor_id,
    actor_name,
    previous_status,
    next_status,
    notes
  )
  values (
    p_report_id,
    v_actor,
    coalesce(v_actor_name, 'Staff'),
    v_report.status,
    p_status,
    v_notes
  );
end;
$$;

revoke all on function public.update_cleaning_noncompliance_report(
  uuid, timestamptz, text, text
) from public, anon;
grant execute on function public.update_cleaning_noncompliance_report(
  uuid, timestamptz, text, text
) to authenticated;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'cleaning_schedules',
    'cleaning_noncompliance_reports',
    'cleaning_report_history'
  ] loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = v_table
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        v_table
      );
    end if;
  end loop;
end $$;

commit;

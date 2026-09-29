begin;

-- Phase 5: automatic but editable cleaning rotation.
--
-- Documented rule:
--   * only occupied beds are eligible
--   * occupied beds are ordered by bed label
--   * each eligible bed receives one weekly duty day in Monday-Sunday
--     round-robin order
--   * a staff-edited bed is a manual override and is never overwritten by
--     automatic regeneration while that bed remains occupied
--   * vacancy removes the bed's active cleaning schedule
--   * assignment changes regenerate the affected room(s) automatically

alter table public.cleaning_schedules
  add column if not exists generation_source text not null default 'manual';

alter table public.cleaning_schedules
  drop constraint if exists cleaning_schedules_generation_source_check;

alter table public.cleaning_schedules
  add constraint cleaning_schedules_generation_source_check
  check (generation_source in ('manual', 'automatic'));

-- System-triggered regeneration can run without an authenticated staff actor.
-- Manual edits still require an authenticated owner/caretaker in the RPC.
alter table public.cleaning_schedules
  alter column created_by drop not null;

create index if not exists cleaning_schedules_generation_source_idx
  on public.cleaning_schedules(generation_source, bed_space_id, weekday);

create or replace function public.refresh_room_cleaning_rotation(
  p_room_id uuid,
  p_actor uuid default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_occupied_count integer := 0;
begin
  if not exists (
    select 1
    from public.rooms
    where id = p_room_id
  ) then
    raise exception 'Room not found';
  end if;

  select case
    when p_actor is not null
      and exists (select 1 from public.profiles where id = p_actor)
      then p_actor
    else null
  end
  into v_actor;

  -- A vacant bed must not keep either an automatic or a manual active duty.
  delete from public.cleaning_schedules s
  using public.bed_spaces b
  where s.bed_space_id = b.id
    and b.room_id = p_room_id
    and not exists (
      select 1
      from public.tenant_assignments a
      where a.bed_space_id = b.id
        and a.status = 'active'
    );

  -- Remove stale automatic rows. Manual rows are intentional overrides and
  -- therefore reserve that bed from automatic regeneration.
  with occupied as (
    select
      b.id as bed_space_id,
      row_number() over (order by b.label, b.id) as bed_position
    from public.bed_spaces b
    where b.room_id = p_room_id
      and exists (
        select 1
        from public.tenant_assignments a
        where a.bed_space_id = b.id
          and a.status = 'active'
      )
  ),
  targets as (
    select
      o.bed_space_id,
      (((o.bed_position - 1) % 7) + 1)::smallint as weekday
    from occupied o
    where not exists (
      select 1
      from public.cleaning_schedules manual_schedule
      where manual_schedule.bed_space_id = o.bed_space_id
        and manual_schedule.is_active
        and manual_schedule.generation_source = 'manual'
    )
  )
  delete from public.cleaning_schedules current_schedule
  using public.bed_spaces room_bed
  where current_schedule.bed_space_id = room_bed.id
    and room_bed.room_id = p_room_id
    and current_schedule.generation_source = 'automatic'
    and not exists (
      select 1
      from targets target
      where target.bed_space_id = current_schedule.bed_space_id
        and target.weekday = current_schedule.weekday
    );

  -- Insert only missing automatic targets. Re-running this function with the
  -- same occupancy therefore does not create duplicates or churn row ids.
  with occupied as (
    select
      b.id as bed_space_id,
      row_number() over (order by b.label, b.id) as bed_position
    from public.bed_spaces b
    where b.room_id = p_room_id
      and exists (
        select 1
        from public.tenant_assignments a
        where a.bed_space_id = b.id
          and a.status = 'active'
      )
  ),
  targets as (
    select
      o.bed_space_id,
      (((o.bed_position - 1) % 7) + 1)::smallint as weekday
    from occupied o
    where not exists (
      select 1
      from public.cleaning_schedules manual_schedule
      where manual_schedule.bed_space_id = o.bed_space_id
        and manual_schedule.is_active
        and manual_schedule.generation_source = 'manual'
    )
  )
  insert into public.cleaning_schedules (
    bed_space_id,
    weekday,
    task_notes,
    is_active,
    created_by,
    generation_source
  )
  select
    target.bed_space_id,
    target.weekday,
    'Automatic weekly cleaning rotation',
    true,
    v_actor,
    'automatic'
  from targets target
  where not exists (
    select 1
    from public.cleaning_schedules existing
    where existing.bed_space_id = target.bed_space_id
      and existing.weekday = target.weekday
      and existing.is_active
  );

  select count(*)::integer
  into v_occupied_count
  from public.bed_spaces b
  where b.room_id = p_room_id
    and exists (
      select 1
      from public.tenant_assignments a
      where a.bed_space_id = b.id
        and a.status = 'active'
    );

  return v_occupied_count;
end;
$$;

revoke all on function public.refresh_room_cleaning_rotation(uuid, uuid)
  from public, anon, authenticated;

create or replace function public.regenerate_cleaning_schedule(
  p_room_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may manage cleaning schedules'
      using errcode = '42501';
  end if;

  return public.refresh_room_cleaning_rotation(p_room_id, auth.uid());
end;
$$;

revoke all on function public.regenerate_cleaning_schedule(uuid)
  from public, anon;
grant execute on function public.regenerate_cleaning_schedule(uuid)
  to authenticated;

-- Preserve the existing API used by the app, but mark staff edits as manual
-- overrides. Clearing all selected days removes the override and immediately
-- restores the automatic duty for an occupied bed.
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
  v_room_id uuid;
begin
  if v_actor is null
     or not coalesce(public.is_staff(), false) then
    raise exception 'Only owners and caretakers may manage cleaning schedules'
      using errcode = '42501';
  end if;

  select room_id
  into v_room_id
  from public.bed_spaces
  where id = p_bed_space_id;

  if v_room_id is null then
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

  if cardinality(p_weekdays) > 0
     and not exists (
       select 1
       from public.tenant_assignments assignment
       where assignment.bed_space_id = p_bed_space_id
         and assignment.status = 'active'
     ) then
    raise exception 'An active room assignment is required to set a cleaning schedule';
  end if;

  delete from public.cleaning_schedules
  where bed_space_id = p_bed_space_id;

  if cardinality(p_weekdays) > 0 then
    insert into public.cleaning_schedules (
      bed_space_id,
      weekday,
      task_notes,
      is_active,
      created_by,
      generation_source
    )
    select
      p_bed_space_id,
      days.selected_day,
      v_notes,
      true,
      v_actor,
      'manual'
    from (
      select distinct unnest(p_weekdays) as selected_day
    ) days
    order by days.selected_day;
  end if;

  perform public.refresh_room_cleaning_rotation(v_room_id, v_actor);
end;
$$;

revoke all on function public.set_cleaning_schedule(uuid, integer[], text)
  from public, anon;
grant execute on function public.set_cleaning_schedule(uuid, integer[], text)
  to authenticated;

create or replace function public.sync_cleaning_rotation_after_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_room uuid;
  v_new_room uuid;
begin
  if tg_op <> 'INSERT' then
    select room_id
    into v_old_room
    from public.bed_spaces
    where id = old.bed_space_id;
  end if;

  if tg_op <> 'DELETE' then
    select room_id
    into v_new_room
    from public.bed_spaces
    where id = new.bed_space_id;
  end if;

  if v_old_room is not null then
    perform public.refresh_room_cleaning_rotation(v_old_room, auth.uid());
  end if;

  if v_new_room is not null
     and v_new_room is distinct from v_old_room then
    perform public.refresh_room_cleaning_rotation(v_new_room, auth.uid());
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function public.sync_cleaning_rotation_after_assignment()
  from public, anon, authenticated;

drop trigger if exists cleaning_rotation_sync_assignments
  on public.tenant_assignments;

create trigger cleaning_rotation_sync_assignments
after insert or delete or update of bed_space_id, status
on public.tenant_assignments
for each row
execute function public.sync_cleaning_rotation_after_assignment();

-- Backfill current occupancy once so Phase 5 becomes useful immediately.
do $$
declare
  room_row record;
begin
  for room_row in
    select distinct b.room_id
    from public.tenant_assignments a
    join public.bed_spaces b on b.id = a.bed_space_id
    where a.status = 'active'
  loop
    perform public.refresh_room_cleaning_rotation(room_row.room_id, null);
  end loop;
end;
$$;

commit;

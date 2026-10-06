begin;

-- Phase 4: owner-controlled room expansion while keeping the established
-- four-bed room model and historical assignment records intact.
alter table public.rooms
  add column if not exists is_active boolean not null default true;

-- Normalize pre-existing room records before enforcing lifecycle rules.
do $$
declare
  room_row record;
  bed_number integer;
begin
  if exists (
    select 1
    from public.rooms r
    where (select count(*) from public.bed_spaces b where b.room_id = r.id) > 4
  ) then
    raise exception 'Cannot enforce four beds: an existing room has more than four bed spaces';
  end if;

  update public.rooms set capacity = 4 where capacity <> 4;

  for room_row in select id from public.rooms loop
    for bed_number in 1..4 loop
      exit when (
        select count(*) from public.bed_spaces where room_id = room_row.id
      ) >= 4;
      insert into public.bed_spaces (room_id, label, status)
      values (room_row.id, 'Bed ' || bed_number, 'available')
      on conflict (room_id, label) do nothing;
    end loop;
  end loop;
end
$$;

-- Room numbers are unique regardless of case or surrounding whitespace.
create unique index if not exists rooms_number_normalized_idx
  on public.rooms (lower(btrim(room_number)));

create or replace function public.protect_room_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Archive rooms instead of deleting history';
  end if;

  if coalesce(public.current_user_role()::text, '') <> 'owner' then
    raise exception 'Only the owner can change dormitory room structure';
  end if;

  new.room_number := btrim(new.room_number);
  new.floor := btrim(new.floor);
  new.description := btrim(coalesce(new.description, ''));
  new.capacity := 4;

  if char_length(new.room_number) not between 1 and 40 then
    raise exception 'Enter a valid room number';
  end if;
  if char_length(new.floor) not between 1 and 60 then
    raise exception 'Enter a valid floor';
  end if;

  if exists (
    select 1
    from public.rooms r
    where lower(btrim(r.room_number)) = lower(new.room_number)
      and r.id <> new.id
  ) then
    raise exception 'Room number already exists';
  end if;

  if tg_op = 'UPDATE' then
    if new.room_number is distinct from old.room_number then
      raise exception 'Room numbers cannot be renamed after creation';
    end if;

    if new.is_active is distinct from old.is_active
       and new.is_active is false
       and exists (
         select 1
         from public.tenant_assignments a
         join public.bed_spaces b on b.id = a.bed_space_id
         where b.room_id = new.id
           and a.status = 'active'
       ) then
      raise exception 'Move all residents before archiving this room';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists protect_room_lifecycle on public.rooms;
create trigger protect_room_lifecycle
before insert or update or delete on public.rooms
for each row execute function public.protect_room_lifecycle();

-- Structural room writes are owner-only. Caretakers retain read access and
-- their existing operational access to bed status/tenant assignments.
drop policy if exists "staff manage rooms" on public.rooms;
drop policy if exists "staff read rooms" on public.rooms;
drop policy if exists "owner create rooms" on public.rooms;
drop policy if exists "owner update rooms" on public.rooms;
drop policy if exists "owner delete rooms" on public.rooms;

create policy "staff read rooms"
on public.rooms for select to authenticated
using ((select public.is_staff()));

create policy "owner create rooms"
on public.rooms for insert to authenticated
with check ((select public.is_owner()));

create policy "owner update rooms"
on public.rooms for update to authenticated
using ((select public.is_owner()))
with check ((select public.is_owner()));

create policy "owner delete rooms"
on public.rooms for delete to authenticated
using ((select public.is_owner()));

-- Keep the four-bed model intact even if a caller bypasses the UI.
create or replace function public.protect_fixed_room_beds()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_count integer;
begin
  if tg_op = 'DELETE' then
    raise exception 'Room bed spaces are fixed at four; do not delete bed spaces';
  end if;

  if tg_op = 'UPDATE' and new.room_id is distinct from old.room_id then
    raise exception 'Bed spaces cannot be moved between rooms';
  end if;

  if tg_op = 'INSERT' then
    select count(*) into existing_count
    from public.bed_spaces
    where room_id = new.room_id;

    if existing_count >= 4 then
      raise exception 'Each dormitory room is limited to four bed spaces';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists protect_fixed_room_beds on public.bed_spaces;
create trigger protect_fixed_room_beds
before insert or update or delete on public.bed_spaces
for each row execute function public.protect_fixed_room_beds();

-- Any owner-created room receives four bed spaces even if the room row is
-- inserted through a future admin surface instead of the RPC below.
create or replace function public.ensure_four_beds_after_room_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.bed_spaces (room_id, label, status)
  select new.id, 'Bed ' || n, 'available'
  from generate_series(1, 4) n
  on conflict (room_id, label) do nothing;
  return new;
end;
$$;

drop trigger if exists ensure_four_beds_after_room_insert on public.rooms;
create trigger ensure_four_beds_after_room_insert
after insert on public.rooms
for each row execute function public.ensure_four_beds_after_room_insert();

-- Archived rooms can never receive a new active assignment.
create or replace function public.reject_archived_room_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_room boolean;
begin
  if new.status = 'active' then
    select r.is_active
      into active_room
    from public.rooms r
    join public.bed_spaces b on b.room_id = r.id
    where b.id = new.bed_space_id
    for update of r;

    if active_room is not true then
      raise exception 'Archived rooms cannot receive assignments';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists reject_archived_room_assignment
  on public.tenant_assignments;
create trigger reject_archived_room_assignment
before insert or update of bed_space_id, status on public.tenant_assignments
for each row execute function public.reject_archived_room_assignment();

-- Replace the older staff-level room creation RPC with an owner-only version.
create or replace function public.create_room_with_four_beds(
  p_room_number text,
  p_floor text,
  p_description text default ''
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_room_id uuid;
  normalized_number text := btrim(coalesce(p_room_number, ''));
  normalized_floor text := btrim(coalesce(p_floor, ''));
begin
  if not public.is_owner() then
    raise exception 'Only the owner can create rooms';
  end if;

  if char_length(normalized_number) not between 1 and 40 then
    raise exception 'Enter a valid room number';
  end if;
  if char_length(normalized_floor) not between 1 and 60 then
    raise exception 'Enter a valid floor';
  end if;

  insert into public.rooms (
    room_number,
    floor,
    capacity,
    description,
    is_active
  ) values (
    normalized_number,
    normalized_floor,
    4,
    btrim(coalesce(p_description, '')),
    true
  )
  returning id into new_room_id;

  -- The AFTER INSERT room trigger creates the fixed four bed spaces.
  return new_room_id;
end;
$$;

revoke all on function public.create_room_with_four_beds(text, text, text)
  from public, anon;
grant execute on function public.create_room_with_four_beds(text, text, text)
  to authenticated;

-- Useful for owner/staff forms and future room-aware configuration without
-- exposing archived rooms as assignment targets.
create or replace function public.list_active_room_locations()
returns table(id uuid, room_number text, floor text)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.room_number, r.floor
  from public.rooms r
  where r.is_active
    and auth.uid() is not null
    and public.is_staff()
  order by lower(r.floor), lower(r.room_number);
$$;

revoke all on function public.list_active_room_locations() from public, anon;
grant execute on function public.list_active_room_locations() to authenticated;

commit;

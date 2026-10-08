-- REVIEW ONLY. Validate against the deployed/full schema before approval.
-- Requires the existing room identity and confidential addenda migrations.
-- No notification producers or curfew/payment/visitor rules are changed.
begin;

create or replace function public.guard_confidential_addendum_open_report()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_report public.confidential_reports;
begin
  select * into v_report from public.confidential_reports
    where id = new.report_id for update;
  if not found or auth.uid() is null or new.author_id is distinct from auth.uid()
    or not (coalesce(public.is_staff(), false) or v_report.tenant_id = auth.uid()) then
    raise exception 'Report access denied';
  end if;
  if v_report.status = 'resolved' then
    raise exception 'Resolved reports cannot receive additions';
  end if;
  return new;
end;
$$;
create trigger guard_confidential_addendum_open_report
before insert on public.confidential_report_addenda
for each row execute function public.guard_confidential_addendum_open_report();

-- Existing schema stores floors as room labels, not a floors table. This small
-- registry permits empty floors while retaining those labels and all room IDs.
create table public.room_floors (
  name text primary key check (char_length(name) between 1 and 60 and name = btrim(name))
);
create unique index room_floors_normalized_name on public.room_floors(lower(name));
-- Fail safely on ambiguous pre-existing labels; do not silently merge them.
insert into public.room_floors(name) select distinct floor from public.rooms;
alter table public.rooms add constraint rooms_floor_registry_fkey
foreign key (floor) references public.room_floors(name)
on delete restrict deferrable initially deferred;
alter table public.room_floors enable row level security;
revoke all on public.room_floors from public, anon, authenticated;
grant select on public.room_floors to authenticated;
create policy "staff read floor registry" on public.room_floors
for select to authenticated using ((select public.is_staff()));

create or replace function public.create_room_floor(p_name text)
returns text language plpgsql security definer set search_path = '' as $$
declare v_name text := btrim(coalesce(p_name, ''));
begin
  if not coalesce(public.is_owner(), false) then raise exception 'Only the owner can create floors'; end if;
  if char_length(v_name) not between 1 and 60 then raise exception 'Enter a valid floor'; end if;
  insert into public.room_floors values (v_name);
  return v_name;
end;
$$;

create or replace function public.manage_room_floor(
  p_from text, p_to text, p_expected_count integer, p_merge boolean default false
) returns integer language plpgsql security definer set search_path = '' as $$
declare v_from text; v_to text; v_count integer;
begin
  if not coalesce(public.is_owner(), false) then raise exception 'Only the owner can rename floors'; end if;
  if char_length(btrim(coalesce(p_to, ''))) not between 1 and 60 then raise exception 'Enter a valid floor'; end if;
  lock table public.room_floors in share row exclusive mode;
  lock table public.rooms in share row exclusive mode;
  select name into v_from from public.room_floors where name = p_from;
  if not found then raise exception 'Floor unavailable. Refresh and review again'; end if;
  select count(*) into v_count from public.rooms where floor = v_from;
  if v_count <> p_expected_count then raise exception 'Floor rooms changed. Refresh and review again'; end if;
  select name into v_to from public.room_floors where lower(name) = lower(btrim(p_to));
  if v_to is not null and v_to <> v_from then
    if not p_merge then raise exception 'Floor name already exists. Use explicit merge'; end if;
    update public.rooms set floor = v_to where floor = v_from;
    delete from public.room_floors where name = v_from;
  else
    if p_merge then raise exception 'Choose an existing different floor to merge into'; end if;
    update public.room_floors set name = btrim(p_to) where name = v_from;
    update public.rooms set floor = btrim(p_to) where floor = v_from;
  end if;
  return v_count;
end;
$$;

-- Preserve compatibility for existing callers of the original atomic merge.
create or replace function public.rename_room_floor(p_from text, p_to text, p_expected_count integer)
returns integer language plpgsql security definer set search_path = '' as $$
begin
  return public.manage_room_floor(p_from, p_to, p_expected_count,
    exists(select 1 from public.room_floors where lower(name) = lower(btrim(p_to)) and name <> p_from));
end;
$$;

create or replace function public.safe_delete_room_floor(p_name text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not coalesce(public.is_owner(), false) then raise exception 'Only the owner can delete floors'; end if;
  perform 1 from public.room_floors where name = p_name for update;
  if not found then raise exception 'Floor unavailable. Refresh and review again'; end if;
  if exists(select 1 from public.rooms where floor = p_name) then
    raise exception 'Move or delete all rooms before deleting this floor, including archived rooms';
  end if;
  delete from public.room_floors where name = p_name;
end;
$$;

-- Inspect every FK to room/bed IDs, including CASCADE and SET NULL historical
-- dependencies. Never remove a dependent record merely because its FK allows it.
create or replace function public.assert_room_has_no_dependencies(p_room_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_fk record; v_join text; v_exists boolean;
begin
  for v_fk in
    select c.conrelid, c.confrelid, c.conkey, c.confkey,
      ns.nspname as schema_name, t.relname as table_name
    from pg_catalog.pg_constraint c
    join pg_catalog.pg_class t on t.oid = c.conrelid
    join pg_catalog.pg_namespace ns on ns.oid = t.relnamespace
    where c.contype = 'f' and c.confrelid in ('public.rooms'::regclass, 'public.bed_spaces'::regclass)
      and not (c.confrelid = 'public.rooms'::regclass and c.conrelid = 'public.bed_spaces'::regclass)
  loop
    select string_agg(format('s.%I = t.%I', a.attname, b.attname), ' and ')
    into v_join from unnest(v_fk.conkey, v_fk.confkey) as keys(src, dst)
    join pg_catalog.pg_attribute a on a.attrelid = v_fk.conrelid and a.attnum = keys.src
    join pg_catalog.pg_attribute b on b.attrelid = v_fk.confrelid and b.attnum = keys.dst;
    execute format('select exists(select 1 from %I.%I s join %s t on %s where t.%I = $1)',
      v_fk.schema_name, v_fk.table_name, v_fk.confrelid::regclass, v_join,
      case when v_fk.confrelid = 'public.rooms'::regclass then 'id' else 'room_id' end)
    into v_exists using p_room_id;
    if v_exists then raise exception 'Room has dependent records (%). Archive it instead', v_fk.table_name; end if;
  end loop;
  -- Also protect legacy maintenance records that predate the stable room FK.
  if exists(select 1 from public.maintenance_reports m join public.rooms r on r.id = p_room_id
    where lower(btrim(m.location)) in (lower('Room ' || r.room_number), lower('Room ' || r.room_number || ' • Bathroom'))) then
    raise exception 'Room has dependent records (maintenance_reports). Archive it instead';
  end if;
end;
$$;

-- Eliminate the existing room-to-bed cascade. The guarded room trigger below
-- deletes only its four structural beds, after proving no history references them.
alter table public.bed_spaces drop constraint bed_spaces_room_id_fkey;
alter table public.bed_spaces add constraint bed_spaces_room_id_fkey
foreign key (room_id) references public.rooms(id) on delete restrict;

create or replace function public.protect_room_lifecycle()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if coalesce(public.current_user_role()::text, '') <> 'owner' then
    raise exception 'Only the owner can change dormitory room structure';
  end if;
  if tg_op = 'DELETE' then
    perform 1 from public.bed_spaces where room_id = old.id for update;
    perform public.assert_room_has_no_dependencies(old.id);
    delete from public.bed_spaces where room_id = old.id;
    return old;
  end if;
  new.room_number := btrim(new.room_number);
  new.floor := btrim(new.floor);
  new.description := btrim(coalesce(new.description, ''));
  new.capacity := 4;
  if char_length(new.room_number) not between 1 and 40 then raise exception 'Enter a valid room number'; end if;
  if char_length(new.floor) not between 1 and 60 then raise exception 'Enter a valid floor'; end if;
  if exists(select 1 from public.rooms r where lower(btrim(r.room_number)) = lower(new.room_number) and r.id <> new.id) then
    raise exception 'Room number already exists';
  end if;
  if tg_op = 'INSERT' then
    new.layout_number := new.room_number;
    new.layout_floor := new.floor;
  else
    new.layout_number := old.layout_number;
    new.layout_floor := old.layout_floor;
    if new.is_active is distinct from old.is_active and not new.is_active
      and exists(select 1 from public.tenant_assignments a join public.bed_spaces b on b.id = a.bed_space_id
        where b.room_id = new.id and a.status = 'active') then
      raise exception 'Move all residents before archiving this room';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.protect_fixed_room_beds()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_count integer;
begin
  if tg_op = 'DELETE' then
    -- Direct bed deletes stay forbidden. Only the nested room-delete trigger
    -- may remove structure, and even that path rechecks all dependencies.
    if pg_trigger_depth() <= 1 or not coalesce(public.is_owner(), false) then
      raise exception 'Room bed spaces are fixed at four; do not delete bed spaces';
    end if;
    perform public.assert_room_has_no_dependencies(old.room_id);
    return old;
  end if;
  if tg_op = 'UPDATE' and new.room_id is distinct from old.room_id then
    raise exception 'Bed spaces cannot be moved between rooms';
  end if;
  if tg_op = 'INSERT' then
    select count(*) into v_count from public.bed_spaces where room_id = new.room_id;
    if v_count >= 4 then raise exception 'Each dormitory room is limited to four bed spaces'; end if;
  end if;
  return new;
end;
$$;

create or replace function public.safe_delete_room(p_room_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not coalesce(public.is_owner(), false) then raise exception 'Only the owner can delete rooms'; end if;
  delete from public.rooms where id = p_room_id;
  if not found then raise exception 'Room unavailable. Refresh and review again'; end if;
end;
$$;

revoke all on function public.create_room_floor(text), public.manage_room_floor(text,text,integer,boolean),
  public.safe_delete_room_floor(text), public.safe_delete_room(uuid) from public, anon;
grant execute on function public.create_room_floor(text), public.manage_room_floor(text,text,integer,boolean),
  public.safe_delete_room_floor(text), public.safe_delete_room(uuid) to authenticated;
revoke all on function public.guard_confidential_addendum_open_report(),
  public.assert_room_has_no_dependencies(uuid), public.protect_room_lifecycle(), public.protect_fixed_room_beds()
  from public, anon, authenticated;
commit;

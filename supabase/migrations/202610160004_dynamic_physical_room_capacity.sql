-- Owner-controlled physical capacity; retain every bed identity and historical reference.
-- Requires room lifecycle 090002 and contract occupancy stabilization/display 130002/130003.
begin;
alter table public.rooms drop constraint if exists rooms_capacity_is_four;
alter table public.rooms alter column capacity set default 4;
alter table public.bed_spaces add column retired_at timestamptz;
create or replace function public.protect_room_lifecycle()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  -- Existing staff assignment RPCs may release a legally ended arrangement.
  -- Its private display trigger only touches updated_at, not room structure.
  if tg_op = 'UPDATE' and pg_trigger_depth() > 1 and coalesce(public.is_staff(),false)
     and (to_jsonb(new)-'updated_at') is not distinct from (to_jsonb(old)-'updated_at') then
    return new;
  end if;
  if coalesce(public.current_user_role()::text, '') <> 'owner' then
    raise exception 'Only the owner can change dormitory room structure';
  end if;
  if tg_op = 'DELETE' then
    if exists(select 1 from public.bed_spaces where room_id=old.id and retired_at is not null) then
      raise exception 'Room has retired bed history. Archive it instead';
    end if;
    perform 1 from public.bed_spaces where room_id = old.id for update;
    perform public.assert_room_has_no_dependencies(old.id);
    delete from public.bed_spaces where room_id = old.id;
    return old;
  end if;
  new.room_number := btrim(new.room_number);
  new.floor := btrim(new.floor);
  new.description := btrim(coalesce(new.description, ''));
  if new.capacity is null or new.capacity < 1 then raise exception 'Enter a positive physical bed capacity'; end if;
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


-- Any FK reference (even historical) prevents retirement. JSON contract bed
-- snapshots are checked as well; no referenced bed is deleted or reused.
create function public.bed_has_history(p_bed uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare f record; used boolean;
begin
  for f in select c.conrelid::regclass tbl,a.attname col
    from pg_catalog.pg_constraint c join pg_catalog.pg_attribute a
      on a.attrelid=c.conrelid and a.attnum=c.conkey[1]
    where c.contype='f' and c.confrelid='public.bed_spaces'::regclass
  loop
    execute format('select exists(select 1 from %s where %I=$1)',f.tbl,f.col) into used using p_bed;
    if used then return true; end if;
  end loop;
  return exists(select 1 from public.contract_occupancy_arrangements g,
    lateral jsonb_array_elements(g.snapshot->'members') m where m->>'bed_id'=p_bed::text);
end $$;

create or replace function public.protect_fixed_room_beds() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_op='DELETE' then
    if pg_trigger_depth()<=1 or not coalesce(public.is_owner(),false) then
      raise exception 'Retire unused beds through room capacity configuration; preserve bed history'; end if;
    perform public.assert_room_has_no_dependencies(old.room_id);
    return old;
  end if;
  if tg_op='INSERT' or new.room_id is distinct from old.room_id
     or new.retired_at is distinct from old.retired_at then
    if not coalesce(public.is_owner(),false) then raise exception 'Only the owner can change physical bed capacity'; end if;
  end if;
  if tg_op='UPDATE' and new.room_id is distinct from old.room_id then raise exception 'Bed spaces cannot be moved between rooms'; end if;
  perform public.lock_contract_occupancy_room(new.room_id);
  if new.retired_at is not null then
    if new.status<>'unavailable' then raise exception 'Retired beds must remain unavailable'; end if;
    if tg_op='INSERT' or old.retired_at is null then
      if public.bed_has_history(new.id) or (tg_op='UPDATE' and old.status<>'available') then
        raise exception 'Occupied, reserved or historically referenced beds cannot be retired'; end if;
    end if;
  elsif tg_op='UPDATE' and old.retired_at is not null then
    raise exception 'Retired bed identities are preserved; add a new physical bed instead';
  end if;
  return new;
end $$;

create or replace function public.validate_bed_space_capacity() returns trigger
language plpgsql security definer set search_path='' as $$
declare cap integer;
begin
  perform public.lock_contract_occupancy_room(new.room_id);
  select capacity into cap from public.rooms where id=new.room_id;
  if new.retired_at is null and (select count(*) from public.bed_spaces
    where room_id=new.room_id and retired_at is null and id<>new.id)>=cap then
    raise exception 'Room capacity cannot be exceeded'; end if;
  return new;
end $$;
create or replace function public.validate_room_capacity() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.capacity<(select count(*) from public.bed_spaces where room_id=new.id and retired_at is null) then
    raise exception 'Retire eligible unused beds before reducing capacity'; end if;
  return new;
end $$;
-- A deferred check prevents direct writes from leaving capacity/bed count out of sync.
create function public.check_physical_room_capacity() returns trigger
language plpgsql security definer set search_path='' as $$
declare rid uuid; cap integer;
begin
  if tg_table_name='rooms' then rid:=new.id;
  elsif tg_op='DELETE' then rid:=old.room_id; else rid:=new.room_id; end if;
  select capacity into cap from public.rooms where id=rid;
  if found and cap<>(select count(*) from public.bed_spaces where room_id=rid and retired_at is null) then
    raise exception 'Physical bed count must match room capacity'; end if;
  return null;
end $$;
create constraint trigger physical_room_capacity after insert or update on public.rooms
  deferrable initially deferred for each row execute function public.check_physical_room_capacity();
create constraint trigger physical_bed_capacity after insert or update or delete on public.bed_spaces
  deferrable initially deferred for each row execute function public.check_physical_room_capacity();

create or replace function public.ensure_four_beds_after_room_insert() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  insert into public.bed_spaces(room_id,label) select new.id,'Bed '||n from generate_series(1,new.capacity) n;
  return new;
end $$;
create or replace function public.guard_occupancy_room_metadata() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from public.contract_occupancy_arrangements where room_id=old.id and not released)
    and (new.capacity<old.capacity or new.room_number<>old.room_number or new.is_active<>old.is_active) then
    raise exception 'Preserve room identity and reserved capacity until contracts and assignments are resolved'; end if;
  return new;
end $$;

create function public.create_room_with_capacity(p_room_number text,p_floor text,p_description text default '',p_capacity integer default 4)
returns uuid language plpgsql security definer set search_path='' as $$
declare rid uuid;
begin
  if auth.uid() is null or not coalesce(public.is_owner(),false) then raise exception 'Only the owner can create rooms'; end if;
  if p_capacity is null or p_capacity<1 then raise exception 'Enter a positive physical bed capacity'; end if;
  insert into public.rooms(room_number,floor,description,capacity) values(btrim(p_room_number),btrim(p_floor),btrim(coalesce(p_description,'')),p_capacity) returning id into rid;
  return rid;
end $$;
create function public.configure_room_capacity(p_room_id uuid,p_capacity integer,p_expected_capacity integer,
  p_room_number text,p_floor text,p_description text)
returns void language plpgsql security definer set search_path='' as $$
declare r public.rooms; b record; remaining integer; seq integer;
begin
  if auth.uid() is null or not coalesce(public.is_owner(),false) then raise exception 'Only the owner can change physical bed capacity'; end if;
  if p_capacity is null or p_capacity<1 then raise exception 'Enter a positive physical bed capacity'; end if;
  perform public.lock_contract_occupancy_room(p_room_id);
  select * into r from public.rooms where id=p_room_id;
  if r.capacity is distinct from p_expected_capacity then raise exception 'Room capacity changed. Refresh and retry'; end if;
  if not r.is_active and p_capacity<>r.capacity then raise exception 'Restore the archived room before changing capacity'; end if;
  if p_capacity<r.capacity then
    if exists(select 1 from public.contract_occupancy_arrangements where room_id=r.id and not released) then
      raise exception 'Resolve occupancy contracts before reducing physical capacity'; end if;
    remaining:=r.capacity-p_capacity;
    for b in select * from public.bed_spaces where room_id=r.id and retired_at is null and status='available' order by created_at desc,id for update loop
      if not public.bed_has_history(b.id) then
        update public.bed_spaces set retired_at=statement_timestamp(),status='unavailable' where id=b.id;
        remaining:=remaining-1;
        exit when remaining=0;
      end if;
    end loop;
    if remaining<>0 then raise exception 'Capacity decrease conflicts with occupied, reserved or historical beds'; end if;
  end if;
  update public.rooms set capacity=p_capacity,room_number=p_room_number,floor=p_floor,description=p_description where id=r.id;
  if p_capacity>r.capacity then
    seq:=1;
    for remaining in 1..(p_capacity-r.capacity) loop
      while exists(select 1 from public.bed_spaces where room_id=r.id and label='Bed '||seq) loop seq:=seq+1; end loop;
      insert into public.bed_spaces(room_id,label) values(r.id,'Bed '||seq);
      seq:=seq+1;
    end loop;
  end if;
end $$;
revoke all on function public.bed_has_history(uuid), public.check_physical_room_capacity() from public,anon,authenticated;
revoke all on function public.create_room_with_capacity(text,text,text,integer),public.configure_room_capacity(uuid,integer,integer,text,text,text) from public,anon;
grant execute on function public.create_room_with_capacity(text,text,text,integer),public.configure_room_capacity(uuid,integer,integer,text,text,text) to authenticated;
commit;

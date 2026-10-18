-- Preserve the existing history, status, retired-bed and concurrency guards.
-- Follow-up for projects that already applied 202610190001. Only the
-- cross-room restriction is narrowed for independently priced occupancy modes.
begin;
create or replace function public.guard_contract_occupancy_assignment() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_room uuid; v_group public.contract_occupancy_arrangements; v_member jsonb;
begin
  if tg_op='DELETE' then
    if exists(select 1 from public.tenant_contracts where tenant_id=old.tenant_id and occupancy_id is not null) then
      raise exception 'Preserve occupancy assignment history'; end if;
    return old;
  end if;
  if tg_op='UPDATE' and new.status<>'active' then
    select room_id into v_room from public.bed_spaces where id=old.bed_space_id;
    perform public.lock_contract_occupancy_room(v_room);
    return new;
  end if;
  if new.status<>'active' then return new; end if;
  select room_id into v_room from public.bed_spaces where id=new.bed_space_id;
  perform public.lock_contract_occupancy_room(v_room);
  -- Also lock the tenant across rooms and competing preparations.
  if not pg_catalog.pg_try_advisory_xact_lock(pg_catalog.hashtextextended(new.tenant_id::text,493)) then raise exception using errcode='55P03',message='This tenant is being assigned by another staff session. Refresh and retry.'; end if;
  if exists(select 1 from public.bed_spaces where id=new.bed_space_id and retired_at is not null) then
    raise exception 'Retired beds cannot receive assignments'; end if;
  if exists(select 1 from public.contract_occupancy_arrangements where room_id=v_room and not released) then
    if exists(select 1 from public.contract_occupancy_arrangements g where g.room_id=v_room and not g.released
      and g.snapshot->>'mode'<>'standard_shared' and not exists(
        select 1 from jsonb_array_elements(g.snapshot->'members') x
        where x->>'tenant_id'=new.tenant_id::text and x->>'bed_id'=new.bed_space_id::text)) then
      raise exception 'Room reserved by a contract occupancy arrangement'; end if;
    select * into v_group from public.contract_occupancy_arrangements g
      where g.room_id=v_room and not g.released and exists(
        select 1 from jsonb_array_elements(g.snapshot->'members') x
        where x->>'tenant_id'=new.tenant_id::text and x->>'bed_id'=new.bed_space_id::text);
    if not found then raise exception 'Prepare an individual Standard Shared contract before assigning this bed'; end if;
    if exists(select 1 from public.tenant_contracts where occupancy_id=v_group.id) and not exists(
      select 1 from public.tenant_contracts where occupancy_id=v_group.id and tenant_id=new.tenant_id and status in ('draft','active')) then
      raise exception 'This occupant contract ended; an approved group amendment is required'; end if;
  end if;
  if exists(select 1 from public.tenant_contracts c join public.contract_occupancy_arrangements g on g.id=c.occupancy_id
    where c.tenant_id=new.tenant_id and not g.released and g.room_id<>v_room
      and g.snapshot->>'mode' in ('shared','exclusive_shared')) then
    raise exception 'Occupancy changes require an approved group amendment'; end if;
  if (select count(*) from public.tenant_assignments a join public.bed_spaces b on b.id=a.bed_space_id
    where a.status='active' and b.room_id=v_room and a.id<>new.id) >= (select capacity from public.rooms where id=v_room) then
    raise exception 'Room capacity exceeded'; end if;
  return new;
end $$;
commit;

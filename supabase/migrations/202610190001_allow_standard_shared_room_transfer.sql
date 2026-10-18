-- Migration: 202610190001_allow_standard_shared_room_transfer
-- Purpose: Allow Standard Shared tenants to use the regular Room Transfer workflow.
--
-- Root cause: Two triggers blocked ALL tenants whose contract has occupancy_id IS NOT NULL,
-- including standard_shared tenants who have independent fixed rents. Only shared and
-- exclusive_shared modes truly require the group amendment workflow (because moving one
-- member changes the rent split for everyone).
--
-- Fix: Narrow the block so that standard_shared (and solo) occupancy modes are allowed
-- through the normal room-transfer path.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Fix: guard_group_room_transfer
--    Fires BEFORE INSERT on public.room_transfers.
--    Old: rejects any contract with occupancy_id IS NOT NULL.
--    New: rejects only shared / exclusive_shared modes.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.guard_group_room_transfer() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if exists(
    select 1
    from public.tenant_contracts c
    join public.contract_occupancy_arrangements g on g.id = c.occupancy_id
    where c.id = new.contract_id
      and g.snapshot->>'mode' in ('shared', 'exclusive_shared')
  ) then
    raise exception 'Group occupancy room changes require an approved group amendment workflow';
  end if;
  return new;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Fix: guard_contract_occupancy_assignment
--    Fires BEFORE INSERT OR UPDATE on public.tenant_assignments.
--    The problematic check (lines 134-136 in 202610160005) blocks an assignment
--    when the tenant already belongs to a non-released occupancy group in a
--    different room — regardless of mode. For standard_shared tenants the
--    transfer is legitimate so we exclude that mode.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function public.guard_contract_occupancy_assignment() returns trigger
language plpgsql security definer set search_path='' as $$
declare
  v_room uuid;
  v_group public.contract_occupancy_arrangements;
begin
  -- Resolve the room being assigned (bed_space_id → room_id)
  select room_id into v_room from public.bed_spaces where id = new.bed_space_id;

  -- Block if the room itself is reserved by a non-standard-shared occupancy
  -- arrangement that doesn't include this tenant+bed combination.
  if exists(
    select 1 from public.contract_occupancy_arrangements g
    where g.room_id = v_room
      and not g.released
      and g.snapshot->>'mode' <> 'standard_shared'
      and not exists(
        select 1 from jsonb_array_elements(g.snapshot->'members') x
        where x->>'tenant_id' = new.tenant_id::text
          and x->>'bed_id'    = new.bed_space_id::text
      )
  ) then
    raise exception 'Room reserved by a contract occupancy arrangement';
  end if;

  -- For standard_shared rooms: the tenant must be a declared member of an arrangement.
  select * into v_group from public.contract_occupancy_arrangements g
    where g.room_id = v_room
      and not g.released
      and exists(
        select 1 from jsonb_array_elements(g.snapshot->'members') x
        where x->>'tenant_id' = new.tenant_id::text
          and x->>'bed_id'    = new.bed_space_id::text
      );

  if found then
    -- If the group already has contracts, this tenant must have one too.
    if exists(select 1 from public.tenant_contracts where occupancy_id = v_group.id)
      and not exists(
        select 1 from public.tenant_contracts
        where occupancy_id = v_group.id
          and tenant_id    = new.tenant_id
          and status in ('draft', 'active')
      ) then
      raise exception 'This occupant contract ended; an approved group amendment is required';
    end if;
  elsif exists(
    -- Room has a standard_shared arrangement but tenant is not a declared member.
    select 1 from public.contract_occupancy_arrangements g
    where g.room_id = v_room and not g.released and g.snapshot->>'mode' = 'standard_shared'
  ) then
    raise exception 'Prepare an individual Standard Shared contract before assigning this bed';
  end if;

  -- Block cross-room occupancy change ONLY for shared / exclusive_shared modes.
  -- Standard_shared tenants with independent fixed rents may move via normal room transfer.
  if exists(
    select 1
    from public.tenant_contracts c
    join public.contract_occupancy_arrangements g on g.id = c.occupancy_id
    where c.tenant_id = new.tenant_id
      and not g.released
      and g.room_id <> v_room
      and g.snapshot->>'mode' in ('shared', 'exclusive_shared')
  ) then
    raise exception 'Occupancy changes require an approved group amendment';
  end if;

  -- Capacity guard
  if (
    select count(*) from public.tenant_assignments a
    join public.bed_spaces b on b.id = a.bed_space_id
    where a.status = 'active'
      and b.room_id = v_room
      and a.id <> new.id
  ) >= (select capacity from public.rooms where id = v_room) then
    raise exception 'Room capacity exceeded';
  end if;

  return new;
end $$;


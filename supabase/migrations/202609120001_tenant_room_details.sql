-- Migration: 202609120001_tenant_room_details.sql
-- Provides an RPC function for tenants (and their guardians or staff) to fetch
-- their active room, bed space, occupancy, and co-assigned roommates without
-- violating global profile confidentiality policies.

create or replace function public.get_my_room_details(p_tenant_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_id uuid;
  v_assignment record;
  v_room record;
  v_bed record;
  v_occupied_count int;
  v_roommates jsonb;
begin
  -- Resolve target tenant identity and check permissions
  if p_tenant_id is not null then
    if not (
      public.is_staff()
      or public.is_guardian_of(p_tenant_id)
      or auth.uid() = p_tenant_id
    ) then
      raise exception 'Unauthorized to access this tenant room details';
    end if;
    target_id := p_tenant_id;
  else
    target_id := auth.uid();
    if target_id is null then
      raise exception 'Authentication required';
    end if;
  end if;

  -- Look up active bed assignment for the target tenant
  select a.id as assignment_id, a.bed_space_id, a.starts_on, a.ends_on
  into v_assignment
  from public.tenant_assignments a
  where a.tenant_id = target_id and a.status = 'active'
  order by a.created_at desc
  limit 1;

  if not found then
    return jsonb_build_object('assigned', false);
  end if;

  -- Look up bed space and parent room
  select b.id, b.room_id, b.label as bed_label
  into v_bed
  from public.bed_spaces b
  where b.id = v_assignment.bed_space_id;

  if not found then
    return jsonb_build_object('assigned', false);
  end if;

  select r.id, r.room_number, r.floor, r.capacity, r.description
  into v_room
  from public.rooms r
  where r.id = v_bed.room_id;

  if not found then
    return jsonb_build_object('assigned', false);
  end if;

  -- Count total active assignments (occupied beds) in this room
  select count(distinct a2.bed_space_id)
  into v_occupied_count
  from public.tenant_assignments a2
  join public.bed_spaces b2 on a2.bed_space_id = b2.id
  where b2.room_id = v_room.id and a2.status = 'active';

  -- Aggregate roommates currently assigned to this room
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'name', coalesce(p.full_name, 'Resident'),
        'bed', b3.label,
        'is_self', (a3.tenant_id = target_id)
      ) order by b3.label
    ),
    '[]'::jsonb
  )
  into v_roommates
  from public.tenant_assignments a3
  join public.bed_spaces b3 on a3.bed_space_id = b3.id
  join public.profiles p on p.id = a3.tenant_id
  where b3.room_id = v_room.id and a3.status = 'active';

  return jsonb_build_object(
    'assigned', true,
    'assignment_id', v_assignment.assignment_id,
    'room_id', v_room.id,
    'room_number', v_room.room_number,
    'floor', v_room.floor,
    'capacity', coalesce(v_room.capacity, 4),
    'occupied', coalesce(v_occupied_count, 1),
    'bed_space', v_bed.bed_label,
    'description', coalesce(v_room.description, ''),
    'utility_summary', 'Electricity & water included • Submetered AC',
    'roommates', v_roommates
  );
end;
$$;

revoke all on function public.get_my_room_details(uuid) from public, anon;
grant execute on function public.get_my_room_details(uuid) to authenticated;


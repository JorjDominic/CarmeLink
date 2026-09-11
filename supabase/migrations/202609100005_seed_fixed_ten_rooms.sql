-- Seed the exact fixed 10 rooms for Carmelita's Dormitory (40 beds total)
-- Ground Floor: 101, 102, 103, 104, 105
-- Second Floor: 201, 202, 203, 204, 205

do $$
declare
  r record;
  new_room_id uuid;
  bed_num int;
  fixed_rooms jsonb := '[
    {"number": "101", "floor": "Ground floor"},
    {"number": "102", "floor": "Ground floor"},
    {"number": "103", "floor": "Ground floor"},
    {"number": "104", "floor": "Ground floor"},
    {"number": "105", "floor": "Ground floor"},
    {"number": "201", "floor": "Second floor"},
    {"number": "202", "floor": "Second floor"},
    {"number": "203", "floor": "Second floor"},
    {"number": "204", "floor": "Second floor"},
    {"number": "205", "floor": "Second floor"}
  ]'::jsonb;
begin
  -- Upsert the 10 fixed rooms
  for r in select * from jsonb_to_recordset(fixed_rooms) as x(number text, floor text) loop
    insert into public.rooms (room_number, floor, capacity, description)
    values (r.number, r.floor, 4, '')
    on conflict (room_number) do update
      set floor = excluded.floor,
          capacity = 4;

    select id into new_room_id from public.rooms where room_number = r.number;

    -- Ensure exactly 4 bed spaces exist per room without exceeding capacity
    for bed_num in 1..4 loop
      if not exists (
        select 1 from public.bed_spaces
        where room_id = new_room_id and label = 'Bed ' || bed_num
      ) and (
        select count(*) from public.bed_spaces where room_id = new_room_id
      ) < 4 then
        insert into public.bed_spaces (room_id, label, status)
        values (new_room_id, 'Bed ' || bed_num, 'available')
        on conflict (room_id, label) do nothing;
      end if;
    end loop;
  end loop;

  -- Safely remove any unassigned stray/test rooms that do not belong to the physical layout
  delete from public.rooms
  where room_number not in ('101', '102', '103', '104', '105', '201', '202', '203', '204', '205')
    and not exists (
      select 1 from public.bed_spaces b
      join public.tenant_assignments a on a.bed_space_id = b.id
      where b.room_id = rooms.id
    );
end $$;


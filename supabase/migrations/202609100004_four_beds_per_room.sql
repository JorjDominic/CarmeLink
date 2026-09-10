-- Every room has a fixed capacity of four. Normalize existing rooms first.
do $$
declare
  room_row record;
  bed_number integer;
begin
  if exists (
    select 1 from public.rooms r
    where (select count(*) from public.bed_spaces b where b.room_id = r.id) > 4
  ) then
    raise exception 'Cannot enforce four beds: an existing room has more than four bed spaces';
  end if;

  update public.rooms set capacity = 4 where capacity <> 4;
  for room_row in select id from public.rooms loop
    for bed_number in 1..4 loop
      exit when (select count(*) from public.bed_spaces where room_id = room_row.id) >= 4;
      insert into public.bed_spaces (room_id, label)
      values (room_row.id, 'Bed ' || bed_number)
      on conflict (room_id, label) do nothing;
    end loop;
  end loop;
end $$;

alter table public.rooms add constraint rooms_capacity_is_four check (capacity = 4);

create or replace function public.create_room_with_four_beds(
  p_room_number text, p_floor text, p_description text default ''
) returns uuid language plpgsql security definer set search_path = '' as $$
declare new_room_id uuid;
begin
  if not public.is_staff() then raise exception 'Staff access required'; end if;
  insert into public.rooms (room_number, floor, capacity, description)
  values (trim(p_room_number), trim(p_floor), 4, trim(coalesce(p_description, '')))
  returning id into new_room_id;
  insert into public.bed_spaces (room_id, label)
  select new_room_id, 'Bed ' || n from generate_series(1, 4) n;
  return new_room_id;
end; $$;

revoke all on function public.create_room_with_four_beds(text, text, text) from public, anon;
grant execute on function public.create_room_with_four_beds(text, text, text) to authenticated;

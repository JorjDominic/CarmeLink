begin;

alter table public.dormitory_options drop constraint dormitory_options_group_key_check;
alter table public.dormitory_options add constraint dormitory_options_group_key_check
  check (group_key in ('maintenance_category', 'common_area', 'report_type',
    'announcement_category', 'payment_method'));
alter table public.dormitory_options add column instructions text not null default ''
  check (char_length(instructions) <= 1000);

insert into public.dormitory_options(group_key, code, label, sort_order)
select 'announcement_category', value, initcap(value), position::integer
from unnest(array['general','maintenance','utility','billing','emergency','event'])
with ordinality as choices(value, position);

insert into public.dormitory_options(group_key, code, label, sort_order, instructions)
select 'payment_method', value, value, position::integer,
  case when value = 'Cash' then 'Pay at the dormitory office and request an official receipt.'
    else 'Confirm the payment account with dormitory staff before sending payment. Attach a readable receipt.' end
from unnest(array['GCash','Maya','Bank transfer','Cash','Other'])
with ordinality as choices(value, position);

alter table public.announcements drop constraint announcements_category_check;
alter table public.announcements add column category_label text;
update public.announcements set category_label = initcap(category);

create or replace function public.snapshot_announcement_category()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_label text;
begin
  if tg_op = 'UPDATE' and new.category = old.category then
    new.category_label := old.category_label;
    return new;
  end if;
  select label into v_label from public.dormitory_options
  where group_key = 'announcement_category' and code = new.category and is_active;
  if not found then raise exception 'Choose an active announcement category'; end if;
  new.category_label := v_label;
  return new;
end;
$$;
create trigger snapshot_announcement_category before insert or update
on public.announcements for each row execute function public.snapshot_announcement_category();

alter table public.payment_transactions drop constraint payment_transactions_payment_method_check;
alter table public.payments drop constraint payments_payment_method_check;
create or replace function public.validate_configured_payment_method()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.payment_method is null then return new; end if;
  if tg_op = 'UPDATE' and new.payment_method is not distinct from old.payment_method then
    return new;
  end if;
  select label into new.payment_method from public.dormitory_options
  where group_key = 'payment_method' and is_active
    and (code = new.payment_method or lower(btrim(label)) = lower(btrim(new.payment_method)))
  order by (code = new.payment_method) desc limit 1;
  if not found then raise exception 'Choose an active payment method'; end if;
  return new;
end;
$$;
create trigger validate_configured_payment_method before insert or update of payment_method
on public.payment_transactions for each row execute function public.validate_configured_payment_method();
create trigger validate_configured_payment_method before insert or update of payment_method
on public.payments for each row execute function public.validate_configured_payment_method();

-- Preserve the original drawing slot independently of the visible room name.
alter table public.rooms add column layout_number text;
alter table public.rooms add column layout_floor text;
alter table public.rooms disable trigger protect_room_lifecycle;
update public.rooms set layout_number = room_number, layout_floor = floor;
alter table public.rooms enable trigger protect_room_lifecycle;

create or replace function public.protect_room_lifecycle()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'DELETE' then raise exception 'Archive rooms instead of deleting history'; end if;
  if coalesce(public.current_user_role()::text, '') <> 'owner' then
    raise exception 'Only the owner can change dormitory room structure';
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
      and exists(select 1 from public.tenant_assignments a
        join public.bed_spaces b on b.id = a.bed_space_id
        where b.room_id = new.id and a.status = 'active') then
      raise exception 'Move all residents before archiving this room';
    end if;
  end if;
  return new;
end;
$$;

-- Keep historical location text, but link exact room labels to stable IDs.
alter table public.maintenance_reports add column room_id uuid references public.rooms(id);
update public.maintenance_reports report set room_id = room.id
from public.rooms room
where lower(btrim(report.location)) in (lower('Room ' || room.room_number), lower('Room ' || room.room_number || ' • Bathroom'));
create or replace function public.link_maintenance_room()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and new.location is not distinct from old.location then
    new.room_id := old.room_id;
    return new;
  end if;
  select id into new.room_id from public.rooms
  where is_active and lower(btrim(new.location)) in
    (lower('Room ' || room_number), lower('Room ' || room_number || ' • Bathroom'));
  return new;
end;
$$;
create trigger zz_link_maintenance_room before insert or update on public.maintenance_reports
for each row execute function public.link_maintenance_room();

-- Rename/merge all rooms in a floor atomically. Archived rooms move too.
create or replace function public.rename_room_floor(p_from text, p_to text, p_expected_count integer)
returns integer language plpgsql security definer set search_path = '' as $$
declare v_count integer;
begin
  if not public.is_owner() then raise exception 'Only the owner can rename floors'; end if;
  if char_length(btrim(p_to)) not between 1 and 60 then raise exception 'Enter a valid floor'; end if;
  lock table public.rooms in share row exclusive mode;
  select count(*) into v_count from public.rooms where floor = p_from;
  if v_count = 0 or v_count <> p_expected_count then
    raise exception 'Floor rooms changed. Refresh and review again';
  end if;
  update public.rooms set floor = btrim(p_to) where floor = p_from;
  return v_count;
end;
$$;
revoke all on function public.rename_room_floor(text,text,integer) from public, anon;
grant execute on function public.rename_room_floor(text,text,integer) to authenticated;
revoke all on function public.snapshot_announcement_category(),
  public.validate_configured_payment_method(), public.link_maintenance_room()
  from public, anon, authenticated;

commit;

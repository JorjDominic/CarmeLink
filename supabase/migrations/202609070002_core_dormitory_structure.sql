create type public.bed_space_status as enum (
  'available',
  'reserved',
  'maintenance',
  'unavailable'
);

create type public.assignment_status as enum (
  'active',
  'ended',
  'cancelled'
);

create table public.rooms (
  id uuid primary key default gen_random_uuid(),
  room_number text not null unique,
  floor text not null,
  capacity integer not null check (capacity > 0),
  description text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.bed_spaces (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  label text not null,
  status public.bed_space_status not null default 'available',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (room_id, label)
);

create table public.guardian_tenant_links (
  id uuid primary key default gen_random_uuid(),
  guardian_id uuid not null references public.profiles(id) on delete cascade,
  tenant_id uuid not null references public.profiles(id) on delete cascade,
  relationship text not null default 'Guardian',
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  check (guardian_id <> tenant_id),
  unique (guardian_id, tenant_id)
);

create table public.tenant_assignments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.profiles(id) on delete cascade,
  bed_space_id uuid not null references public.bed_spaces(id) on delete restrict,
  starts_on date not null default current_date,
  ends_on date,
  status public.assignment_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on is null or ends_on >= starts_on)
);

-- A tenant and a bed can each have only one active assignment.
create unique index tenant_assignments_one_active_per_tenant
on public.tenant_assignments (tenant_id)
where status = 'active';

create unique index tenant_assignments_one_active_per_bed
on public.tenant_assignments (bed_space_id)
where status = 'active';

create index bed_spaces_room_id_idx on public.bed_spaces (room_id);
create index guardian_links_guardian_id_idx
on public.guardian_tenant_links (guardian_id);
create index guardian_links_tenant_id_idx
on public.guardian_tenant_links (tenant_id);
create index tenant_assignments_tenant_id_idx
on public.tenant_assignments (tenant_id);
create index tenant_assignments_bed_space_id_idx
on public.tenant_assignments (bed_space_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger rooms_set_updated_at
before update on public.rooms
for each row execute function public.set_updated_at();

create trigger bed_spaces_set_updated_at
before update on public.bed_spaces
for each row execute function public.set_updated_at();

create trigger tenant_assignments_set_updated_at
before update on public.tenant_assignments
for each row execute function public.set_updated_at();

create or replace function public.validate_bed_space_capacity()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  room_capacity integer;
  bed_count integer;
begin
  select capacity into room_capacity
  from public.rooms
  where id = new.room_id
  for update;

  select count(*) into bed_count
  from public.bed_spaces
  where room_id = new.room_id
    and (tg_op = 'INSERT' or id <> new.id);

  if bed_count >= room_capacity then
    raise exception 'Room capacity cannot be exceeded';
  end if;
  return new;
end;
$$;

create trigger bed_spaces_validate_capacity
before insert or update of room_id on public.bed_spaces
for each row execute function public.validate_bed_space_capacity();

create or replace function public.validate_room_capacity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.capacity < (
    select count(*) from public.bed_spaces where room_id = new.id
  ) then
    raise exception 'Room capacity cannot be lower than its bed-space count';
  end if;
  return new;
end;
$$;

create trigger rooms_validate_capacity
before update of capacity on public.rooms
for each row execute function public.validate_room_capacity();

create or replace function public.validate_bed_space_status()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status <> 'available' and exists (
    select 1 from public.tenant_assignments
    where bed_space_id = new.id and status = 'active'
  ) then
    raise exception 'An occupied bed space cannot be made unavailable';
  end if;
  return new;
end;
$$;

create trigger bed_spaces_validate_status
before update of status on public.bed_spaces
for each row execute function public.validate_bed_space_status();

create or replace function public.validate_dormitory_relationships()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_table_name = 'guardian_tenant_links' then
    if (select role from public.profiles where id = new.guardian_id) <> 'guardian' then
      raise exception 'guardian_id must reference a guardian profile';
    end if;
    if (select role from public.profiles where id = new.tenant_id) <> 'tenant' then
      raise exception 'tenant_id must reference a tenant profile';
    end if;
  elsif tg_table_name = 'tenant_assignments' then
    if (select role from public.profiles where id = new.tenant_id) <> 'tenant' then
      raise exception 'tenant_id must reference a tenant profile';
    end if;
    if new.status = 'active' and
       (select status from public.bed_spaces where id = new.bed_space_id) <> 'available' then
      raise exception 'Only an available bed space can receive an active assignment';
    end if;
  end if;
  return new;
end;
$$;

create trigger guardian_tenant_links_validate_roles
before insert or update on public.guardian_tenant_links
for each row execute function public.validate_dormitory_relationships();

create trigger tenant_assignments_validate_role
before insert or update on public.tenant_assignments
for each row execute function public.validate_dormitory_relationships();

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select role = 'owner_caretaker'
     from public.profiles
     where id = (select auth.uid())),
    false
  );
$$;

create or replace function public.is_guardian_of(requested_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.guardian_tenant_links
    where guardian_id = (select auth.uid())
      and tenant_id = requested_tenant_id
  );
$$;

revoke all on function public.is_staff() from public;
revoke all on function public.is_guardian_of(uuid) from public;
grant execute on function public.is_staff() to authenticated;
grant execute on function public.is_guardian_of(uuid) to authenticated;

alter table public.rooms enable row level security;
alter table public.bed_spaces enable row level security;
alter table public.guardian_tenant_links enable row level security;
alter table public.tenant_assignments enable row level security;

create policy "staff manage rooms"
on public.rooms for all to authenticated
using ((select public.is_staff()))
with check ((select public.is_staff()));

create policy "assigned users read rooms"
on public.rooms for select to authenticated
using (exists (
  select 1
  from public.bed_spaces b
  join public.tenant_assignments a on a.bed_space_id = b.id
  where b.room_id = rooms.id
    and a.status = 'active'
    and (a.tenant_id = (select auth.uid()) or public.is_guardian_of(a.tenant_id))
));

create policy "staff manage bed spaces"
on public.bed_spaces for all to authenticated
using ((select public.is_staff()))
with check ((select public.is_staff()));

create policy "assigned users read bed spaces"
on public.bed_spaces for select to authenticated
using (exists (
  select 1
  from public.tenant_assignments a
  where a.bed_space_id = bed_spaces.id
    and a.status = 'active'
    and (a.tenant_id = (select auth.uid()) or public.is_guardian_of(a.tenant_id))
));

create policy "staff manage guardian links"
on public.guardian_tenant_links for all to authenticated
using ((select public.is_staff()))
with check ((select public.is_staff()));

create policy "linked users read guardian links"
on public.guardian_tenant_links for select to authenticated
using (
  guardian_id = (select auth.uid())
  or tenant_id = (select auth.uid())
);

create policy "staff manage tenant assignments"
on public.tenant_assignments for all to authenticated
using ((select public.is_staff()))
with check ((select public.is_staff()));

create policy "assigned users read tenant assignments"
on public.tenant_assignments for select to authenticated
using (
  tenant_id = (select auth.uid())
  or public.is_guardian_of(tenant_id)
);

-- Extend profile visibility without allowing users to modify roles.
create policy "staff read all profiles"
on public.profiles for select to authenticated
using ((select public.is_staff()));

create policy "linked users read profiles"
on public.profiles for select to authenticated
using (
  public.is_guardian_of(id)
  or exists (
    select 1
    from public.guardian_tenant_links link
    where link.tenant_id = (select auth.uid())
      and link.guardian_id = profiles.id
  )
);

-- Connect the provisioned guardian and tenant test profiles.
insert into public.guardian_tenant_links (guardian_id, tenant_id, relationship, is_primary)
select guardian.id, tenant.id, 'Mother', true
from public.profiles guardian
cross join public.profiles tenant
where guardian.role = 'guardian'
  and tenant.role = 'tenant'
  and guardian.id = (select id from auth.users where email = 'guardian@carmelita.test')
  and tenant.id = (select id from auth.users where email = 'tenant@carmelita.test')
on conflict (guardian_id, tenant_id) do nothing;

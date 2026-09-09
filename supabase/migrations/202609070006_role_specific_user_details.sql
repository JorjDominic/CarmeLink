create table public.tenant_details (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  birth_date date,
  address text not null default '',
  school_name text not null default '',
  course_or_program text not null default '',
  year_level smallint check (year_level is null or year_level between 1 and 20),
  emergency_contact_name text not null default '',
  emergency_contact_phone text not null default '',
  emergency_contact_relationship text not null default '',
  contract_starts_on date,
  contract_ends_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    contract_ends_on is null
    or contract_starts_on is null
    or contract_ends_on >= contract_starts_on
  )
);

create table public.staff_details (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  employee_code text unique,
  position text not null,
  hired_on date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger tenant_details_set_updated_at
before update on public.tenant_details
for each row execute function public.set_updated_at();

create trigger staff_details_set_updated_at
before update on public.staff_details
for each row execute function public.set_updated_at();

create or replace function public.validate_role_detail_record()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  profile_role public.app_role;
begin
  select role into profile_role
  from public.profiles
  where id = new.profile_id;

  if tg_table_name = 'tenant_details' and profile_role <> 'tenant' then
    raise exception 'tenant_details must reference a tenant profile';
  end if;

  if tg_table_name = 'staff_details' and
     profile_role not in ('owner', 'caretaker') then
    raise exception 'staff_details must reference an owner or caretaker profile';
  end if;

  return new;
end;
$$;

create trigger tenant_details_validate_role
before insert or update of profile_id on public.tenant_details
for each row execute function public.validate_role_detail_record();

create trigger staff_details_validate_role
before insert or update of profile_id on public.staff_details
for each row execute function public.validate_role_detail_record();

alter table public.tenant_details enable row level security;
alter table public.staff_details enable row level security;

-- Tenant information is visible only to that tenant, linked guardians, and
-- operational staff. Only staff may create or change these records.
create policy "authorized users read tenant details"
on public.tenant_details for select to authenticated
using (
  profile_id = (select auth.uid())
  or public.is_guardian_of(profile_id)
  or (select public.is_staff())
);

create policy "staff manage tenant details"
on public.tenant_details for all to authenticated
using ((select public.is_staff()))
with check ((select public.is_staff()));

-- Staff employment data is more restricted: staff can read their own row,
-- while only owners may view and manage other staff records.
create policy "staff read own employment details"
on public.staff_details for select to authenticated
using (profile_id = (select auth.uid()));

create policy "owners manage staff details"
on public.staff_details for all to authenticated
using ((select public.is_owner()))
with check ((select public.is_owner()));

revoke all on table public.tenant_details from anon;
revoke all on table public.staff_details from anon;
revoke all on table public.tenant_details from authenticated;
revoke all on table public.staff_details from authenticated;
grant select, insert, update, delete on public.tenant_details to authenticated;
grant select, insert, update, delete on public.staff_details to authenticated;

revoke all on function public.validate_role_detail_record()
from public, anon, authenticated;

-- Ensure existing accounts receive their correct role-specific row.
insert into public.tenant_details (profile_id)
select id from public.profiles where role = 'tenant'
on conflict (profile_id) do nothing;

insert into public.staff_details (profile_id, position)
select id, case role when 'owner' then 'Owner' else 'Caretaker' end
from public.profiles
where role in ('owner', 'caretaker')
on conflict (profile_id) do nothing;

create table public.maintenance_reports (
  id uuid primary key default gen_random_uuid(),

  tenant_id uuid not null
    references public.profiles(id)
    on delete cascade,

  category text not null
    check (char_length(trim(category)) between 2 and 80),

  description text not null
    check (char_length(trim(description)) between 3 and 1000),

  location text not null
    check (char_length(trim(location)) between 2 and 120),

  urgency text not null default 'medium'
    check (urgency in ('low', 'medium', 'high')),

  status text not null default 'pending'
    check (
      status in (
        'pending',
        'assigned',
        'in_progress',
        'resolved',
        'cancelled'
      )
    ),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index maintenance_reports_tenant_id_idx
  on public.maintenance_reports (tenant_id);

create index maintenance_reports_status_idx
  on public.maintenance_reports (status);

create index maintenance_reports_created_at_idx
  on public.maintenance_reports (created_at desc);


-- Reuse the updated_at function already created by the earlier migrations.
create trigger maintenance_reports_set_updated_at
before update on public.maintenance_reports
for each row
execute function public.set_updated_at();


-- Prevent a tenant from changing protected workflow fields.
-- Tenants may edit only their own report details while the report is pending.
create or replace function public.protect_tenant_maintenance_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if public.current_user_role() = 'tenant' then

    if old.tenant_id <> new.tenant_id then
      raise exception 'Tenant cannot change maintenance report ownership';
    end if;

    if old.status <> new.status then
      raise exception 'Tenant cannot change maintenance report status';
    end if;

    if old.created_at <> new.created_at then
      raise exception 'Tenant cannot change maintenance report creation time';
    end if;

    if old.status <> 'pending' then
      raise exception 'Only pending maintenance reports can be edited';
    end if;

  end if;

  return new;
end;
$$;

create trigger maintenance_reports_protect_tenant_update
before update on public.maintenance_reports
for each row
execute function public.protect_tenant_maintenance_update();


alter table public.maintenance_reports enable row level security;


-- TENANT: READ own reports only.
create policy "tenants read own maintenance reports"
on public.maintenance_reports
for select
to authenticated
using (
  tenant_id = (select auth.uid())
);


-- TENANT: CREATE own pending reports only.
create policy "tenants create own maintenance reports"
on public.maintenance_reports
for insert
to authenticated
with check (
  tenant_id = (select auth.uid())
  and (select public.current_user_role()) = 'tenant'
  and status = 'pending'
);


-- TENANT: UPDATE own reports only while pending.
create policy "tenants update own pending maintenance reports"
on public.maintenance_reports
for update
to authenticated
using (
  tenant_id = (select auth.uid())
  and status = 'pending'
  and (select public.current_user_role()) = 'tenant'
)
with check (
  tenant_id = (select auth.uid())
  and status = 'pending'
  and (select public.current_user_role()) = 'tenant'
);


-- TENANT: DELETE own reports only while pending.
create policy "tenants delete own pending maintenance reports"
on public.maintenance_reports
for delete
to authenticated
using (
  tenant_id = (select auth.uid())
  and status = 'pending'
  and (select public.current_user_role()) = 'tenant'
);


-- OWNER / CARETAKER: READ all reports.
create policy "staff read maintenance reports"
on public.maintenance_reports
for select
to authenticated
using (
  (select public.is_staff())
);


-- OWNER / CARETAKER: UPDATE workflow/status later.
create policy "staff update maintenance reports"
on public.maintenance_reports
for update
to authenticated
using (
  (select public.is_staff())
)
with check (
  (select public.is_staff())
);


revoke all on table public.maintenance_reports from anon;

revoke all on table public.maintenance_reports from authenticated;

grant select, insert, update, delete
on table public.maintenance_reports
to authenticated;


revoke all
on function public.protect_tenant_maintenance_update()
from public, anon, authenticated;
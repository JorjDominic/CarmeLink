create table public.visitor_requests (
  id uuid primary key default gen_random_uuid(),

  tenant_id uuid not null
    references public.profiles(id)
    on delete cascade,

  visitor_name text not null
    check (
      char_length(trim(visitor_name))
      between 2 and 120
    ),

  relationship text not null
    check (
      char_length(trim(relationship))
      between 2 and 80
    ),

  purpose text not null
    check (
      char_length(trim(purpose))
      between 2 and 300
    ),

  schedule timestamptz not null,

  status text not null default 'pending'
    check (
      status in (
        'pending',
        'approved',
        'rejected',
        'cancelled',
        'completed'
      )
    ),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index visitor_requests_tenant_id_idx
  on public.visitor_requests (tenant_id);
create index visitor_requests_status_idx
  on public.visitor_requests (status);
create index visitor_requests_schedule_idx
  on public.visitor_requests (schedule);
create trigger visitor_requests_set_updated_at
before update on public.visitor_requests
for each row
execute function public.set_updated_at();
create or replace function public.protect_tenant_visitor_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if public.current_user_role() = 'tenant' then

    if old.tenant_id <> new.tenant_id then
      raise exception
        'Tenant cannot change visitor request ownership';
    end if;

    if old.status <> new.status then
      raise exception
        'Tenant cannot change visitor request status';
    end if;

    if old.created_at <> new.created_at then
      raise exception
        'Tenant cannot change visitor request creation time';
    end if;

    if old.status <> 'pending' then
      raise exception
        'Only pending visitor requests can be edited';
    end if;

  end if;

  return new;
end;
$$;
create trigger visitor_requests_protect_tenant_update
before update on public.visitor_requests
for each row
execute function public.protect_tenant_visitor_update();
alter table public.visitor_requests
enable row level security;
create policy "tenants read own visitor requests"
on public.visitor_requests
for select
to authenticated
using (
  tenant_id = (select auth.uid())
);
create policy "tenants create own visitor requests"
on public.visitor_requests
for insert
to authenticated
with check (
  tenant_id = (select auth.uid())
  and
  (select public.current_user_role()) = 'tenant'
  and status = 'pending'
);
create policy "tenants update own pending visitor requests"
on public.visitor_requests
for update
to authenticated
using (
  tenant_id = (select auth.uid())
  and status = 'pending'
  and
  (select public.current_user_role()) = 'tenant'
)
with check (
  tenant_id = (select auth.uid())
  and status = 'pending'
  and
  (select public.current_user_role()) = 'tenant'
);
create policy "tenants delete own pending visitor requests"
on public.visitor_requests
for delete
to authenticated
using (
  tenant_id = (select auth.uid())
  and status = 'pending'
  and
  (select public.current_user_role()) = 'tenant'
);
create policy "staff read visitor requests"
on public.visitor_requests
for select
to authenticated
using (
  (select public.is_staff())
);
create policy "staff update visitor requests"
on public.visitor_requests
for update
to authenticated
using (
  (select public.is_staff())
)
with check (
  (select public.is_staff())
);
revoke all
on table public.visitor_requests
from anon;
revoke all
on table public.visitor_requests
from authenticated;
grant select, insert, update, delete
on table public.visitor_requests
to authenticated;
revoke all
on function public.protect_tenant_visitor_update()
from public, anon, authenticated;

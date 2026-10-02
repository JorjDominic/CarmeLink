-- Auditable monitoring-health incidents. No coordinates are stored.
create table if not exists public.location_monitoring_incidents (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (reason in (
    'LOCATION_SERVICES_DISABLED', 'LOCATION_PERMISSION_DENIED',
    'BACKGROUND_LOCATION_DENIED', 'PRECISE_LOCATION_DISABLED'
  )),
  platform text not null check (platform in ('android', 'ios')),
  started_at timestamptz not null default now(),
  recovered_at timestamptz,
  escalated_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index if not exists location_monitoring_one_open_incident
  on public.location_monitoring_incidents (tenant_id)
  where recovered_at is null;
create index if not exists location_monitoring_pending_escalation
  on public.location_monitoring_incidents (started_at)
  where recovered_at is null and escalated_at is null;

alter table public.location_monitoring_incidents enable row level security;
revoke all on public.location_monitoring_incidents from anon, authenticated;
grant select on public.location_monitoring_incidents to authenticated;

create policy location_monitoring_tenant_read_own
on public.location_monitoring_incidents for select to authenticated
using (tenant_id = auth.uid());

create policy location_monitoring_staff_read
on public.location_monitoring_incidents for select to authenticated
using (exists (
  select 1 from public.profiles p
  where p.id = auth.uid() and p.role in ('owner', 'caretaker')
));

create or replace function public.set_my_location_monitoring_health(
  p_available boolean,
  p_reason text default null,
  p_platform text default 'android'
) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare v_id uuid;
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles where id = auth.uid() and role = 'tenant'
  ) then raise exception 'Only authenticated tenants can report monitoring health'; end if;
  if p_platform not in ('android', 'ios') then raise exception 'Invalid platform'; end if;

  if p_available then
    update public.location_monitoring_incidents
       set recovered_at = now()
     where tenant_id = auth.uid() and recovered_at is null
     returning id into v_id;
    return v_id;
  end if;
  if p_reason not in (
    'LOCATION_SERVICES_DISABLED', 'LOCATION_PERMISSION_DENIED',
    'BACKGROUND_LOCATION_DENIED', 'PRECISE_LOCATION_DISABLED'
  ) then raise exception 'Invalid monitoring failure reason'; end if;

  select id into v_id from public.location_monitoring_incidents
   where tenant_id = auth.uid() and recovered_at is null;
  if v_id is null then
    insert into public.location_monitoring_incidents (tenant_id, reason, platform)
    values (auth.uid(), p_reason, p_platform) returning id into v_id;
  end if;
  return v_id;
end; $$;

revoke all on function public.set_my_location_monitoring_health(boolean,text,text) from public, anon;
grant execute on function public.set_my_location_monitoring_health(boolean,text,text) to authenticated;

comment on table public.location_monitoring_incidents is
  'Location monitoring availability only; deliberately contains no coordinates.';

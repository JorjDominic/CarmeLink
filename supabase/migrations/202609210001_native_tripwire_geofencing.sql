-- Native background tripwire support. Raw coordinates remain device-only.

alter table public.gate_events
  add column if not exists client_event_id uuid,
  add column if not exists observed_at timestamptz;

create unique index if not exists gate_events_client_event_id_unique_idx
  on public.gate_events (client_event_id)
  where client_event_id is not null;

alter table public.gate_events
  drop constraint if exists gate_events_checkpoint_type_check;

alter table public.gate_events
  add constraint gate_events_checkpoint_type_check check (
    checkpoint_type in (
      'daytime', 'pre_curfew', 'curfew', 'manual_entry', 'on_demand',
      'native_transition'
    )
  );

create or replace function public.record_tenant_geofence_transition(
  p_direction text,
  p_observed_at timestamptz,
  p_client_event_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant_id uuid := auth.uid();
  v_event_id uuid;
  v_status text := 'Verified';
  v_observed_at timestamptz := p_observed_at;
  v_hour int;
  v_has_approved_exception boolean := false;
begin
  if v_tenant_id is null then
    raise exception 'Authentication required';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = v_tenant_id and role = 'tenant'
  ) then
    raise exception 'Only tenants can record GPS geofence transitions';
  end if;
  if p_direction not in ('IN', 'OUT') then
    raise exception 'Direction must be IN or OUT';
  end if;
  if p_client_event_id is null then
    raise exception 'Client event ID is required';
  end if;
  if v_observed_at < now() - interval '24 hours'
     or v_observed_at > now() + interval '5 minutes' then
    raise exception 'Observed time is outside the accepted range';
  end if;

  select id into v_event_id
    from public.gate_events
   where client_event_id = p_client_event_id;
  if v_event_id is not null then
    return v_event_id;
  end if;

  v_hour := extract(hour from (v_observed_at at time zone 'Asia/Manila'));
  if p_direction = 'OUT' and (v_hour >= 22 or v_hour < 6) then
    select exists (
      select 1 from public.curfew_requests
       where tenant_id = v_tenant_id
         and status = 'approved'
         and v_observed_at between departure_time and expected_return_time
    ) into v_has_approved_exception;
    if not v_has_approved_exception then
      v_status := 'Flagged';
    end if;
  end if;

  insert into public.gate_events (
    tenant_id, direction, verification_method, status, checkpoint_type,
    checked_at, observed_at, created_by, client_event_id
  ) values (
    v_tenant_id, p_direction, 'GPS Geofence', v_status,
    'native_transition', v_observed_at, v_observed_at, v_tenant_id,
    p_client_event_id
  )
  on conflict (client_event_id) where client_event_id is not null do nothing
  returning id into v_event_id;

  if v_event_id is null then
    select id into v_event_id
      from public.gate_events
     where client_event_id = p_client_event_id;
  end if;
  return v_event_id;
end;
$$;

revoke all on function public.record_tenant_geofence_transition(text, timestamptz, uuid)
  from public, anon;
grant execute on function public.record_tenant_geofence_transition(text, timestamptz, uuid)
  to authenticated;

-- Production hardening for GPS events created by older and current clients.
-- Corrects curfew semantics and suppresses rapid duplicate checkpoints.

create or replace function public.normalize_and_deduplicate_geofence_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.verification_method <> 'GPS Geofence' then
    return new;
  end if;

  -- Being verified inside during curfew is compliant, not an exception.
  if new.direction = 'IN' and new.status = 'Flagged' then
    new.status := 'Verified';
  end if;

  -- A retry, double tap, or overlapping foreground/background callback must not
  -- produce an identical second event in the same short acquisition window.
  if exists (
    select 1
      from public.gate_events previous
     where previous.tenant_id = new.tenant_id
       and previous.verification_method = 'GPS Geofence'
       and previous.direction is not distinct from new.direction
       and previous.status = new.status
       and previous.checkpoint_type = new.checkpoint_type
       and previous.checked_at >= new.checked_at - interval '45 seconds'
  ) then
    return null;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_normalize_and_deduplicate_geofence_event
  on public.gate_events;
create trigger trg_normalize_and_deduplicate_geofence_event
before insert on public.gate_events
for each row execute function public.normalize_and_deduplicate_geofence_event();

revoke all on function public.normalize_and_deduplicate_geofence_event()
  from public, anon, authenticated;

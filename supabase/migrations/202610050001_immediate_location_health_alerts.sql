-- Dispatch initial alerts as soon as an outage report commits. Cron remains a retry path.
create schema if not exists private;
create table private.location_health_dispatch_config (
  singleton boolean primary key default true check (singleton),
  endpoint text not null,
  bearer_token text not null
);
revoke all on private.location_health_dispatch_config from public, anon, authenticated;

do $$
declare v_secret text := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
begin
  -- Add a dedicated webhook credential without invalidating either existing cron job.
  insert into public.guardian_alert_cron_credentials (token_hash)
  values (encode(extensions.digest(v_secret, 'sha256'), 'hex'));
  insert into private.location_health_dispatch_config (endpoint, bearer_token)
  values ('https://iuplkgvitovzjbmtzpme.supabase.co/functions/v1/process-location-monitoring-alerts', v_secret);
end $$;

create function private.dispatch_location_health_incident()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_config private.location_health_dispatch_config%rowtype;
begin
  select * into v_config from private.location_health_dispatch_config where singleton;
  if found then
    perform net.http_post(
      url := v_config.endpoint,
      headers := jsonb_build_object('Authorization', 'Bearer ' || v_config.bearer_token,
                                   'Content-Type', 'application/json'),
      body := jsonb_build_object('incident_id', new.id),
      timeout_milliseconds := 10000
    );
  end if;
  return new;
exception when others then
  -- Network queue failure must not discard the incident; cron can retry it.
  raise warning 'Immediate location-health dispatch could not be queued; scheduled retry remains active';
  return new;
end $$;
revoke all on function private.dispatch_location_health_incident() from public, anon, authenticated;

create trigger location_health_incident_immediate_dispatch
after insert on public.location_monitoring_incidents
for each row when (new.recovered_at is null)
execute function private.dispatch_location_health_incident();

-- Serialize webhook and cron processing so concurrent requests cannot send the same push.
alter table public.location_monitoring_incidents add column dispatch_claimed_until timestamptz;

create function public.claim_location_monitoring_alerts(p_incident_id uuid default null)
returns setof public.location_monitoring_incidents
language sql security definer set search_path = '' as $$
  with pending as (
    select id from public.location_monitoring_incidents
    where recovered_at is null
      and (p_incident_id is null or id = p_incident_id)
      and (dispatch_claimed_until is null or dispatch_claimed_until <= now())
      and (guardian_notified_at is null
           or (escalated_at is null and started_at <= now() - interval '30 minutes'))
    order by started_at
    limit 50
    for update skip locked
  )
  update public.location_monitoring_incidents as incident
  set dispatch_claimed_until = now() + interval '5 minutes'
  from pending where incident.id = pending.id
  returning incident.*;
$$;
revoke all on function public.claim_location_monitoring_alerts(uuid) from public, anon, authenticated;
grant execute on function public.claim_location_monitoring_alerts(uuid) to service_role;

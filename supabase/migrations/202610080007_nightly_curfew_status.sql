begin;

create extension if not exists pg_cron with schema pg_catalog;

-- Persist the 11 PM Asia/Manila snapshot for every tenant. The existing generic
-- notification trigger queues pushes, so tenants need not have the app open.
create or replace function private.process_nightly_curfew_status()
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_day date := (now() at time zone 'Asia/Manila')::date;
  v_tenant record;
  v_key text;
  v_body text;
  v_data jsonb;
begin
  -- Serialise overlapping scheduler attempts; event keys prevent duplicate sends.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('nightly-curfew-status', 0));
  if (now() at time zone 'Asia/Manila')::time < time '23:00' then return; end if;
  for v_tenant in
    select p.id, p.full_name, coalesce(t.current_gate_status, 'UNAVAILABLE') as presence,
           t.last_gate_event_at
    from public.profiles p left join public.tenant_details t on t.profile_id = p.id
    where p.role::text = 'tenant'
  loop
    v_key := 'nightly_curfew:' || v_day::text || ':' || v_tenant.id::text;
    v_body := coalesce(v_tenant.full_name, 'Tenant') || ' at the 11 PM curfew: ' ||
      case v_tenant.presence when 'IN' then 'IN the dormitory.'
        when 'OUT' then 'OUT of the dormitory.'
        else 'Presence unavailable; please verify their location.' end;
    v_data := jsonb_build_object('tenant_id', v_tenant.id, 'presence', v_tenant.presence,
      'curfew_date', v_day, 'cutoff', '23:00', 'timezone', 'Asia/Manila',
      'last_gate_event_at', v_tenant.last_gate_event_at);
    perform public.emit_tenant_circle_notification(v_tenant.id, true, true,
      'curfew', '11 PM curfew status', v_body, 'gate', v_tenant.id, v_data, v_key, 0);
    perform public.emit_staff_notification('curfew', '11 PM curfew status', v_body,
      'gate', v_tenant.id, v_data, v_key, 0);
  end loop;
  perform private.dispatch_report_pushes();
end;
$$;
revoke all on function private.process_nightly_curfew_status() from public, anon, authenticated;

do $$
declare v_job record;
begin
  for v_job in select jobid from cron.job where jobname = 'nightly-curfew-status'
  loop perform cron.unschedule(v_job.jobid); end loop;
  -- pg_cron runs in UTC: 15:00 UTC is 23:00 in the Philippines.
  perform cron.schedule('nightly-curfew-status', '0 15 * * *',
    'select private.process_nightly_curfew_status();');
end;
$$;
commit;

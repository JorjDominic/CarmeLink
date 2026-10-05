-- Reuse the private cron credential created for scheduled guardian alerts.
do $$
declare v_secret text := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
        v_headers jsonb; v_command text; v_job record;
begin
  update public.guardian_alert_cron_credentials set is_active = false;
  insert into public.guardian_alert_cron_credentials (token_hash)
  values (encode(extensions.digest(v_secret, 'sha256'), 'hex'));
  for v_job in select jobid from cron.job where jobname in ('guardian-presence-alerts', 'location-monitoring-alerts')
  loop perform cron.unschedule(v_job.jobid); end loop;
  v_headers := jsonb_build_object('Authorization', 'Bearer ' || v_secret, 'Content-Type', 'application/json');
  v_command := format('select net.http_post(url := %L, headers := %L::jsonb, body := %L::jsonb);',
    'https://iuplkgvitovzjbmtzpme.supabase.co/functions/v1/process-guardian-presence-alerts', v_headers::text, '{}'::jsonb::text);
  perform cron.schedule('guardian-presence-alerts', '*/5 * * * *', v_command);
  v_command := format('select net.http_post(url := %L, headers := %L::jsonb, body := %L::jsonb);',
    'https://iuplkgvitovzjbmtzpme.supabase.co/functions/v1/process-location-monitoring-alerts', v_headers::text, '{}'::jsonb::text);
  perform cron.schedule('location-monitoring-alerts', '*/5 * * * *', v_command);
end $$;

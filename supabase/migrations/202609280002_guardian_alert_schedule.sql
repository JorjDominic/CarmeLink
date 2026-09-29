-- Secure five-minute scheduler for guardian outside-after-cutoff FCM alerts.
-- The raw credential is generated remotely and exists only in cron.job.command;
-- this table stores its SHA-256 hash for Edge Function verification.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

create table if not exists public.guardian_alert_cron_credentials (
  id uuid primary key default gen_random_uuid(),
  token_hash text not null unique check (token_hash ~ '^[a-f0-9]{64}$'),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.guardian_alert_cron_credentials enable row level security;
revoke all on public.guardian_alert_cron_credentials from anon, authenticated;

do $$
declare
  v_secret text := replace(gen_random_uuid()::text, '-', '') ||
                   replace(gen_random_uuid()::text, '-', '');
  v_headers jsonb;
  v_command text;
  v_job record;
begin
  update public.guardian_alert_cron_credentials set is_active = false;
  insert into public.guardian_alert_cron_credentials (token_hash)
  values (encode(extensions.digest(v_secret, 'sha256'), 'hex'));

  for v_job in select jobid from cron.job where jobname = 'guardian-presence-alerts'
  loop
    perform cron.unschedule(v_job.jobid);
  end loop;

  v_headers := jsonb_build_object(
    'Authorization', 'Bearer ' || v_secret,
    'Content-Type', 'application/json'
  );
  v_command := format(
    'select net.http_post(url := %L, headers := %L::jsonb, body := %L::jsonb);',
    'https://iuplkgvitovzjbmtzpme.supabase.co/functions/v1/process-guardian-presence-alerts',
    v_headers::text,
    '{}'::jsonb::text
  );
  perform cron.schedule('guardian-presence-alerts', '*/5 * * * *', v_command);
end $$;

comment on table public.guardian_alert_cron_credentials is
  'Private hashes used to authenticate the pg_cron guardian presence-alert processor.';

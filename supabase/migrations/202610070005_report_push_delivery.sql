begin;

-- Database-triggered report notifications cannot call the authenticated client
-- notification dispatcher. Queue only those server-created notifications and
-- deliver them through a service-role Edge Function.
create table public.notification_push_jobs (
  notification_id uuid primary key
    references public.app_notifications(id) on delete cascade,
  available_at timestamptz not null default now(),
  attempts integer not null default 0 check (attempts >= 0),
  completed_at timestamptz
);

create table public.notification_push_deliveries (
  notification_id uuid not null
    references public.app_notifications(id) on delete cascade,
  device_id uuid not null
    references public.push_device_tokens(id) on delete cascade,
  delivered_at timestamptz not null default now(),
  primary key (notification_id, device_id)
);

create index notification_push_jobs_pending_idx
  on public.notification_push_jobs(available_at)
  where completed_at is null;

alter table public.notification_push_jobs enable row level security;
alter table public.notification_push_deliveries enable row level security;

revoke all on public.notification_push_jobs,
  public.notification_push_deliveries from public, anon, authenticated;
grant all on public.notification_push_jobs,
  public.notification_push_deliveries to service_role;

create or replace function public.queue_server_report_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.route_type in ('confidential_report', 'cleaning_report')
     or new.data ->> 'server_push' = 'true' then
    insert into public.notification_push_jobs(notification_id)
    values (new.id)
    on conflict (notification_id) do nothing;
  end if;
  return new;
end;
$$;

revoke all on function public.queue_server_report_push()
  from public, anon, authenticated;

drop trigger if exists queue_server_report_push
  on public.app_notifications;

create trigger queue_server_report_push
after insert on public.app_notifications
for each row
execute function public.queue_server_report_push();

create or replace function public.claim_report_push_jobs()
returns setof public.app_notifications
language sql
security definer
set search_path = ''
as $$
  with pending as (
    select job.notification_id
    from public.notification_push_jobs job
    where job.completed_at is null
      and job.available_at <= now()
      and job.attempts < 20
    order by job.available_at
    limit 50
    for update skip locked
  ),
  claimed as (
    update public.notification_push_jobs job
    set available_at = now() + interval '5 minutes',
        attempts = job.attempts + 1
    from pending
    where job.notification_id = pending.notification_id
    returning job.notification_id
  )
  select notification.*
  from public.app_notifications notification
  join claimed on claimed.notification_id = notification.id;
$$;

revoke all on function public.claim_report_push_jobs()
  from public, anon, authenticated;
grant execute on function public.claim_report_push_jobs()
  to service_role;

create table private.report_push_dispatch_config (
  singleton boolean primary key default true check (singleton),
  endpoint text not null,
  bearer_token text not null
);

revoke all on private.report_push_dispatch_config
  from public, anon, authenticated;

do $$
declare
  v_secret text := replace(gen_random_uuid()::text, '-', '')
    || replace(gen_random_uuid()::text, '-', '');
begin
  insert into public.guardian_alert_cron_credentials(token_hash)
  values (encode(extensions.digest(v_secret, 'sha256'), 'hex'));

  insert into private.report_push_dispatch_config(
    singleton,
    endpoint,
    bearer_token
  ) values (
    true,
    'https://iuplkgvitovzjbmtzpme.supabase.co/functions/v1/process-report-pushes',
    v_secret
  );
end;
$$;

create or replace function private.dispatch_report_pushes()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_config private.report_push_dispatch_config%rowtype;
begin
  if not exists (
    select 1
    from public.notification_push_jobs
    where completed_at is null
      and available_at <= now()
      and attempts < 20
  ) then
    return;
  end if;

  select *
  into v_config
  from private.report_push_dispatch_config
  where singleton;

  perform net.http_post(
    url := v_config.endpoint,
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || v_config.bearer_token,
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 10000
  );
end;
$$;

revoke all on function private.dispatch_report_pushes()
  from public, anon, authenticated;

select cron.schedule(
  'report-push-delivery',
  '* * * * *',
  'select private.dispatch_report_pushes();'
);

commit;

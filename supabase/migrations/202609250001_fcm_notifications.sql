begin;

create table public.push_device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  fcm_token text not null unique check (char_length(fcm_token) between 20 and 4096),
  platform text not null check (platform in ('android', 'ios')),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create index push_device_tokens_active_user_idx
  on public.push_device_tokens(user_id)
  where revoked_at is null;

alter table public.push_device_tokens enable row level security;
revoke all on public.push_device_tokens from anon, authenticated;
grant select, insert, update, delete on public.push_device_tokens to authenticated;

create policy "users read own push tokens"
on public.push_device_tokens for select to authenticated
using (user_id = (select auth.uid()));

create policy "users register own push tokens"
on public.push_device_tokens for insert to authenticated
with check (user_id = (select auth.uid()));

create policy "users update own push tokens"
on public.push_device_tokens for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy "users delete own push tokens"
on public.push_device_tokens for delete to authenticated
using (user_id = (select auth.uid()));

create table public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  notification_type text not null check (
    notification_type in (
      'announcement', 'payment', 'maintenance', 'curfew', 'visitor',
      'gate', 'safety', 'onboarding', 'message', 'system'
    )
  ),
  title text not null check (char_length(trim(title)) between 1 and 120),
  body text not null check (char_length(trim(body)) between 1 and 500),
  route_type text,
  route_id uuid,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  push_sent_at timestamptz,
  push_error text check (push_error is null or char_length(push_error) <= 500)
);

create index app_notifications_recipient_created_idx
  on public.app_notifications(recipient_id, created_at desc);

alter table public.app_notifications enable row level security;
revoke all on public.app_notifications from anon, authenticated;
grant select on public.app_notifications to authenticated;

create policy "users read own notifications"
on public.app_notifications for select to authenticated
using (recipient_id = (select auth.uid()));

create or replace function public.mark_notification_read(p_notification_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.app_notifications
  set read_at = coalesce(read_at, now())
  where id = p_notification_id and recipient_id = auth.uid();
end;
$$;

revoke all on function public.mark_notification_read(uuid) from public;
grant execute on function public.mark_notification_read(uuid) to authenticated;

commit;

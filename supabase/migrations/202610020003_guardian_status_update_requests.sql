begin;

create table public.guardian_status_update_requests (
  id uuid primary key default gen_random_uuid(),
  guardian_id uuid not null references public.profiles(id) on delete cascade,
  tenant_id uuid not null references public.profiles(id) on delete cascade,
  requested_at timestamptz not null default now(),
  dispatched_at timestamptz,
  push_delivered_at timestamptz
);

create index guardian_status_requests_guardian_tenant_idx
  on public.guardian_status_update_requests (guardian_id, tenant_id, requested_at desc);

alter table public.guardian_status_update_requests enable row level security;
revoke all on public.guardian_status_update_requests from anon, authenticated;
grant select on public.guardian_status_update_requests to authenticated;

create policy "participants read status update requests"
on public.guardian_status_update_requests for select to authenticated
using (
  guardian_id = (select auth.uid())
  or tenant_id = (select auth.uid())
  or exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role in ('owner', 'caretaker')
  )
);

create or replace function public.request_tenant_status_update(p_tenant_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_guardian_id uuid := auth.uid();
  v_request_id uuid;
begin
  if v_guardian_id is null then
    raise exception 'Sign in to request a presence update.';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = v_guardian_id and role = 'guardian'
  ) then
    raise exception 'Only guardians can request a presence update.';
  end if;

  if not exists (
    select 1 from public.guardian_tenant_links
    where guardian_id = v_guardian_id and tenant_id = p_tenant_id
  ) then
    raise exception 'No guardian link exists for this tenant.';
  end if;

  -- Serialize requests for this guardian/tenant pair so two devices cannot
  -- both pass the cooldown check at the same instant.
  perform pg_advisory_xact_lock(
    hashtextextended(v_guardian_id::text || ':' || p_tenant_id::text, 0)
  );

  if exists (
    select 1 from public.guardian_status_update_requests
    where guardian_id = v_guardian_id
      and tenant_id = p_tenant_id
      and requested_at > now() - interval '30 minutes'
  ) then
    raise exception 'Please wait 30 minutes before sending another reminder.';
  end if;

  if (
    select count(*) from public.guardian_status_update_requests
    where guardian_id = v_guardian_id
      and tenant_id = p_tenant_id
      and requested_at > now() - interval '24 hours'
  ) >= 5 then
    raise exception 'The daily limit of 5 reminders has been reached.';
  end if;

  insert into public.guardian_status_update_requests (guardian_id, tenant_id)
  values (v_guardian_id, p_tenant_id)
  returning id into v_request_id;

  return v_request_id;
end;
$$;

revoke all on function public.request_tenant_status_update(uuid) from public;
grant execute on function public.request_tenant_status_update(uuid) to authenticated;

commit;

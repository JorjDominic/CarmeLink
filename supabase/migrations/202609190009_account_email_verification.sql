-- Persist independent email/mobile verification state. SMS delivery remains
-- intentionally disabled until a provider is selected.
alter table public.profiles
  add column email_verification_sent_at timestamptz,
  add column email_verified_at timestamptz,
  add column email_verification_attempts integer not null default 0
    check (email_verification_attempts between 0 and 5),
  add column email_verification_window_started_at timestamptz,
  add column phone_verification_sent_at timestamptz,
  add column phone_verified_at timestamptz,
  add column invitation_email_id text;

-- Preserve the verified state of existing accounts when this migration lands.
update public.profiles p
set email_verified_at = u.email_confirmed_at
from auth.users u
where u.id = p.id and u.email_confirmed_at is not null;

create or replace function public.sync_current_email_verification()
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_confirmed_at timestamptz;
begin
  select email_confirmed_at into v_confirmed_at
  from auth.users
  where id = auth.uid();

  if v_confirmed_at is not null then
    update public.profiles
    set email_verified_at = coalesce(email_verified_at, v_confirmed_at)
    where id = auth.uid();
  end if;
  return v_confirmed_at;
end;
$$;

grant execute on function public.sync_current_email_verification() to authenticated;
revoke execute on function public.sync_current_email_verification() from public, anon;

create or replace function public.require_verified_email_for_active_contract()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'active' and (tg_op = 'INSERT' or old.status is distinct from 'active') then
    if not exists (
      select 1 from public.profiles
      where id = new.tenant_id and email_verified_at is not null
    ) then
      raise exception 'Tenant email must be verified before contract activation';
    end if;
  end if;
  return new;
end;
$$;

create trigger tenant_contracts_require_verified_email
before insert or update of status on public.tenant_contracts
for each row execute function public.require_verified_email_for_active_contract();

revoke all on function public.require_verified_email_for_active_contract()
  from public, anon, authenticated;

comment on column public.profiles.phone_verification_sent_at is
  'Reserved for SMS OTP; delivery is disabled until a provider is selected.';

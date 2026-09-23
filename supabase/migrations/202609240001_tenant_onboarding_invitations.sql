-- Secure QR-code onboarding invitations for tenants. Each invitation contains
-- an opaque token that the tenant scans to open the onboarding form. The token
-- does not embed personal data; it is validated server-side by the RPCs below.
create table public.tenant_onboarding_invitations (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.profiles(id) on delete cascade,
  token       text not null unique
                default encode(extensions.gen_random_bytes(32), 'hex'),
  status      text not null default 'pending'
                check (status in ('pending', 'completed', 'expired', 'revoked')),
  expires_at  timestamptz not null default now() + interval '7 days',
  created_by  uuid not null default auth.uid()
                references public.profiles(id) on delete restrict,
  created_at  timestamptz not null default now(),
  completed_at timestamptz,
  constraint onboarding_invitation_completed_at_valid check (
    (status = 'completed' and completed_at is not null)
    or (status <> 'completed' and completed_at is null)
  )
);

create index tenant_onboarding_invitations_tenant_idx
  on public.tenant_onboarding_invitations(tenant_id, created_at desc);
create index tenant_onboarding_invitations_token_idx
  on public.tenant_onboarding_invitations(token)
  where status = 'pending';

create trigger tenant_onboarding_invitations_set_updated_at
before update on public.tenant_onboarding_invitations
for each row execute function public.set_updated_at() ;

-- Rename trigger: set_updated_at is not actually adding updated_at here, so
-- drop that trigger since the table has no updated_at column.
drop trigger tenant_onboarding_invitations_set_updated_at
  on public.tenant_onboarding_invitations;

alter table public.tenant_onboarding_invitations enable row level security;

-- Owner and caretaker can create and view all invitations.
create policy onboarding_invitations_staff_select
  on public.tenant_onboarding_invitations for select to authenticated
  using ((select public.is_staff()));

create policy onboarding_invitations_staff_insert
  on public.tenant_onboarding_invitations for insert to authenticated
  with check (
    (select public.is_staff())
    and created_by = auth.uid()
  );

create policy onboarding_invitations_staff_update
  on public.tenant_onboarding_invitations for update to authenticated
  using ((select public.is_staff()))
  with check ((select public.is_staff()));

-- Tenant can view only their own invitation (needed for the claim RPC below).
create policy onboarding_invitations_tenant_select
  on public.tenant_onboarding_invitations for select to authenticated
  using (
    tenant_id = auth.uid()
    and (select public.current_user_role()) = 'tenant'
  );

grant select, insert, update on public.tenant_onboarding_invitations to authenticated;
revoke all on public.tenant_onboarding_invitations from anon;

-- ---------------------------------------------------------------------------
-- RPC: claim_onboarding_invitation
-- Called by the tenant when they scan the QR. Validates ownership + expiry
-- and returns the invitation row so the app can open the onboarding form.
-- Does NOT mark the invitation completed; that happens after the form submit.
-- ---------------------------------------------------------------------------
create or replace function public.claim_onboarding_invitation(p_token text)
returns public.tenant_onboarding_invitations
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.tenant_onboarding_invitations;
begin
  -- Only tenants may claim invitations.
  if (select public.current_user_role()) <> 'tenant' then
    raise exception 'Only tenants can claim an onboarding invitation';
  end if;

  select * into v_row
  from public.tenant_onboarding_invitations
  where token = p_token;

  if not found then
    raise exception 'Invalid invitation link';
  end if;

  if v_row.tenant_id <> auth.uid() then
    raise exception 'This invitation does not belong to your account';
  end if;

  if v_row.status = 'revoked' then
    raise exception 'This invitation has been revoked by staff';
  end if;

  if v_row.status = 'completed' then
    raise exception 'This invitation has already been completed';
  end if;

  if v_row.status = 'expired' or v_row.expires_at < now() then
    -- Mark as expired if not already.
    update public.tenant_onboarding_invitations
    set status = 'expired'
    where id = v_row.id and status = 'pending';

    raise exception 'This invitation link has expired. Ask staff to send a new one';
  end if;

  return v_row;
end;
$$;

grant execute on function public.claim_onboarding_invitation(text) to authenticated;
revoke execute on function public.claim_onboarding_invitation(text) from anon;

-- ---------------------------------------------------------------------------
-- RPC: complete_onboarding_invitation
-- Called when the tenant submits the onboarding form. Validates ownership,
-- saves the submitted data to tenant_details, and marks the invitation done.
-- ---------------------------------------------------------------------------
create or replace function public.complete_onboarding_invitation(
  p_token                      text,
  p_school_name                text    default '',
  p_course_or_program          text    default '',
  p_year_level                 smallint default null,
  p_emergency_contact_name     text    default '',
  p_emergency_contact_phone    text    default '',
  p_emergency_contact_relationship text default ''
)
returns public.tenant_onboarding_invitations
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.tenant_onboarding_invitations;
begin
  -- Validate via claim first (reuses the same guard logic).
  -- We call it inline rather than nesting RPCs; duplicate the critical checks.
  if (select public.current_user_role()) <> 'tenant' then
    raise exception 'Only tenants can complete an onboarding invitation';
  end if;

  select * into v_row
  from public.tenant_onboarding_invitations
  where token = p_token;

  if not found then
    raise exception 'Invalid invitation link';
  end if;

  if v_row.tenant_id <> auth.uid() then
    raise exception 'This invitation does not belong to your account';
  end if;

  if v_row.status = 'revoked' then
    raise exception 'This invitation has been revoked by staff';
  end if;

  if v_row.status = 'completed' then
    raise exception 'This invitation has already been completed';
  end if;

  if v_row.status = 'expired' or v_row.expires_at < now() then
    update public.tenant_onboarding_invitations
    set status = 'expired'
    where id = v_row.id and status = 'pending';
    raise exception 'This invitation link has expired. Ask staff to send a new one';
  end if;

  -- Update the tenant_details row for this tenant.
  update public.tenant_details
  set
    school_name                   = coalesce(nullif(trim(p_school_name), ''), school_name),
    course_or_program             = coalesce(nullif(trim(p_course_or_program), ''), course_or_program),
    year_level                    = coalesce(p_year_level, year_level),
    emergency_contact_name        = coalesce(nullif(trim(p_emergency_contact_name), ''), emergency_contact_name),
    emergency_contact_phone       = coalesce(nullif(trim(p_emergency_contact_phone), ''), emergency_contact_phone),
    emergency_contact_relationship = coalesce(nullif(trim(p_emergency_contact_relationship), ''), emergency_contact_relationship)
  where profile_id = auth.uid();

  if not found then
    raise exception 'Tenant profile details record not found';
  end if;

  -- Mark invitation completed.
  update public.tenant_onboarding_invitations
  set status = 'completed', completed_at = now()
  where id = v_row.id
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.complete_onboarding_invitation(text, text, text, smallint, text, text, text)
  to authenticated;
revoke execute on function public.complete_onboarding_invitation(text, text, text, smallint, text, text, text)
  from anon;

comment on table public.tenant_onboarding_invitations is
  'Secure one-time QR invitation tokens for tenant onboarding data submission.';

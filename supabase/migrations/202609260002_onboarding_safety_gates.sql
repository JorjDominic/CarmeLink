-- Safety alignment for tenant onboarding and curfew routing.
-- Decision: guardian linking remains optional for activation. Overnight-leave
-- requests skip guardian review only when no guardian is linked, and always
-- continue through staff review. This prevents unreviewable requests without
-- pretending guardian consent exists.

create or replace function public.submit_curfew_request(
  p_destination text,
  p_reason text,
  p_departure_time timestamptz,
  p_expected_return_time timestamptz,
  p_request_type text default 'late_return'
) returns public.curfew_requests
language plpgsql security definer set search_path = '' as $$
declare
  v_row public.curfew_requests;
  v_status text;
begin
  if public.current_user_role() <> 'tenant' then
    raise exception 'Only tenants can submit curfew requests';
  end if;
  if p_request_type not in ('late_return', 'overnight_leave') then
    raise exception 'Invalid curfew request type';
  end if;
  if char_length(trim(coalesce(p_destination, ''))) < 2 then
    raise exception 'A destination is required';
  end if;
  if char_length(trim(coalesce(p_reason, ''))) < 3 then
    raise exception 'A reason is required';
  end if;
  if p_expected_return_time <= p_departure_time then
    raise exception 'Expected return must be after departure';
  end if;

  v_status := case
    when p_request_type = 'overnight_leave' and exists (
      select 1 from public.guardian_tenant_links
      where tenant_id = auth.uid()
    ) then 'pending_guardian'
    else 'pending_staff'
  end;

  insert into public.curfew_requests (
    tenant_id, destination, reason, departure_time,
    expected_return_time, request_type, status
  ) values (
    auth.uid(), trim(p_destination), trim(p_reason), p_departure_time,
    p_expected_return_time, p_request_type, v_status
  ) returning * into v_row;
  return v_row;
end $$;

revoke insert on public.curfew_requests from authenticated;
revoke all on function public.submit_curfew_request(text,text,timestamptz,timestamptz,text)
  from public, anon;
grant execute on function public.submit_curfew_request(text,text,timestamptz,timestamptz,text)
  to authenticated;

-- Emergency contact is a duty-of-care activation gate. The mobile form
-- already requires all three values; this trigger also protects direct API use.
create or replace function public.require_verified_email_for_active_contract()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' and new.status = 'active' then
    raise exception 'Contracts must be created as Draft before activation';
  end if;
  if new.status = 'active' and (tg_op = 'INSERT' or old.status is distinct from 'active') then
    if not exists (
      select 1 from public.profiles where id = new.tenant_id and email_verified_at is not null
    ) then raise exception 'Tenant email must be verified before contract activation'; end if;
    if not exists (
      select 1 from public.tenant_details
      where profile_id = new.tenant_id
        and char_length(trim(emergency_contact_name)) >= 2
        and char_length(trim(emergency_contact_phone)) >= 7
        and char_length(trim(emergency_contact_relationship)) >= 2
    ) then raise exception 'Complete emergency contact information is required before contract activation'; end if;
    if new.signature_status <> 'verified' then
      raise exception 'Signed contract document must be owner-verified before activation';
    end if;
    if exists (
      select 1 from public.contract_requirements
      where contract_id = new.id and is_required and status <> 'verified'
    ) then raise exception 'Required onboarding documents must be verified before activation'; end if;
    if exists (
      select 1 from public.contract_signers
      where contract_id = new.id and is_required and status <> 'verified'
    ) then raise exception 'Every required contract signer must be verified before activation'; end if;
  end if;
  return new;
end $$;

comment on function public.submit_curfew_request(text,text,timestamptz,timestamptz,text)
is 'Routes overnight leave to a linked guardian when present, otherwise directly to mandatory staff review.';

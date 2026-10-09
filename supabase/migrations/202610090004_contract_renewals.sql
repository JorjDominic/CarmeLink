-- Renewals are separately signed terms. Existing rent and issued bills never change.
begin;

alter table public.tenant_contracts add column previous_contract_id uuid
  references public.tenant_contracts(id) on delete restrict;
alter table public.tenant_contracts add constraint contract_renewal_not_self
  check (previous_contract_id is distinct from id);
create unique index tenant_contracts_one_live_renewal
  on public.tenant_contracts(previous_contract_id)
  where previous_contract_id is not null and status <> 'terminated';

alter table public.security_deposit_receipts add column transferred_to_contract_id uuid
  references public.tenant_contracts(id) on delete restrict;

create or replace function public.guard_contract_renewal()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  p public.tenant_contracts;
  v_today date := (now() at time zone 'Asia/Manila')::date;
begin
  -- Serialize renewals for a tenant, including direct table writes.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.tenant_id::text, 493));
  if tg_op = 'UPDATE' then
    if old.previous_contract_id is distinct from new.previous_contract_id then
      raise exception 'The previous contract link cannot be changed';
    end if;
    if exists(select 1 from public.tenant_contracts
      where previous_contract_id=old.id and status <> 'terminated') and (
      new.tenant_id is distinct from old.tenant_id or new.starts_on is distinct from old.starts_on
      or new.ends_on is distinct from old.ends_on or new.contract_number is distinct from old.contract_number
      or new.monthly_rent is distinct from old.monthly_rent
      or new.security_deposit is distinct from old.security_deposit
      or new.status not in ('active','expired')
    ) then raise exception 'A contract with a renewal must retain its original terms'; end if;
  end if;
  if new.previous_contract_id is null then
    -- A separate unlinked draft must not compete with an existing renewal draft.
    if tg_op = 'INSERT' and new.status in ('draft','active') and exists (
      select 1 from public.tenant_contracts where tenant_id=new.tenant_id
      and previous_contract_id is not null and status in ('draft','active')
    ) then raise exception 'This tenant already has a renewal contract'; end if;
    return new;
  end if;
  -- Authorized signing RPCs update signature_status using the tenant/guardian
  -- session. This metadata update must not require owner lifecycle privileges.
  -- Direct contract UPDATE remains protected by the existing owner-only RLS.
  if tg_op='UPDATE' and new.status=old.status and new.tenant_id=old.tenant_id
    and new.starts_on=old.starts_on and new.ends_on=old.ends_on
    and new.contract_number=old.contract_number and new.monthly_rent=old.monthly_rent
    and new.security_deposit=old.security_deposit and new.notes is not distinct from old.notes then
    return new;
  end if;
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then
    raise exception 'Owner access required';
  end if;
  if tg_op='UPDATE' and old.status <> 'draft' then
    if new.status='draft' or new.tenant_id is distinct from old.tenant_id
      or new.starts_on is distinct from old.starts_on or new.ends_on is distinct from old.ends_on
      or new.contract_number is distinct from old.contract_number
      or new.monthly_rent is distinct from old.monthly_rent
      or new.security_deposit is distinct from old.security_deposit then
      raise exception 'Activated or closed renewal terms cannot be changed';
    end if;
    if new.status='active' and old.status <> 'active' then
      raise exception 'A closed renewal cannot be reactivated';
    end if;
    return new;
  end if;
  select * into p from public.tenant_contracts where id=new.previous_contract_id for update;
  if not found or p.status not in ('active','expired') then
    raise exception 'Only an active or expired contract can be renewed';
  end if;
  if p.tenant_id <> new.tenant_id then raise exception 'Renewal tenant must match the previous contract'; end if;
  if new.starts_on <= p.ends_on then raise exception 'Renewal must start after the previous contract ends'; end if;
  if new.security_deposit <> p.security_deposit then raise exception 'Renewals carry the existing deposit terms'; end if;
  if exists(select 1 from public.tenant_contracts c where c.tenant_id=new.tenant_id
    and c.id not in (p.id,new.id) and c.status <> 'terminated'
    and (c.status in ('draft','active') or c.ends_on >= new.starts_on)) then
    raise exception 'Another contract or renewal already exists for this tenant';
  end if;
  if exists(select 1 from public.move_out_cases where contract_id=p.id and status <> 'cancelled') then
    raise exception 'This contract has a move-out case; cancel it before renewing';
  end if;
  if tg_op = 'INSERT' then
    if new.status <> 'draft' then raise exception 'Renewals must be created as Draft'; end if;
  elsif new.status = 'active' and old.status <> 'active' then
    if old.status <> 'draft' then raise exception 'Only draft renewals can be activated'; end if;
    if new.starts_on > v_today or p.ends_on >= v_today then
      raise exception 'Activate the renewal on or after its start date, after the previous term ends';
    end if;
    if new.ends_on < v_today then raise exception 'The renewal term has already ended'; end if;
    -- Existing signature, email, document and signer triggers still run. Any
    -- failure rolls this expiration back together with the activation.
    update public.tenant_contracts set status='expired' where id=p.id and status='active';
  elsif old.status <> 'draft' and new.status='draft' then
    raise exception 'A completed renewal cannot be reopened as Draft';
  end if;
  return new;
end;
$$;
create trigger tenant_contracts_renewal_guard before insert or update on public.tenant_contracts
  for each row execute function public.guard_contract_renewal();
revoke all on function public.guard_contract_renewal() from public,anon,authenticated;

create or replace function public.renew_tenant_contract(
  p_previous_contract_id uuid, p_starts_on date, p_ends_on date,
  p_monthly_rent numeric, p_notes text default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare p public.tenant_contracts; c public.tenant_contracts; v_id uuid;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then
    raise exception 'Owner access required';
  end if;
  select * into p from public.tenant_contracts where id=p_previous_contract_id;
  if not found then raise exception 'Previous contract not found'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p.tenant_id::text,493));
  select * into p from public.tenant_contracts where id=p_previous_contract_id for update;
  if p.status not in ('active','expired') then raise exception 'Only an active or expired contract can be renewed'; end if;
  if p_starts_on is null or p_ends_on is null or p_starts_on <= p.ends_on or p_ends_on < p_starts_on then
    raise exception 'Enter a valid renewal period after the previous contract ends';
  end if;
  if p_monthly_rent is null or p_monthly_rent::text in ('NaN','Infinity','-Infinity')
    or p_monthly_rent < 0 or p_monthly_rent > 9999999999.99
    or p_monthly_rent <> round(p_monthly_rent,2) then
    raise exception 'Enter a valid monthly rent with at most two decimals';
  end if;
  select * into c from public.tenant_contracts where previous_contract_id=p.id and status <> 'terminated';
  if found then
    if c.status='draft' and c.starts_on=p_starts_on and c.ends_on=p_ends_on
      and c.monthly_rent=p_monthly_rent and c.notes is not distinct from nullif(btrim(p_notes),'') then
      return c.id; -- A retry of the same save does not duplicate a draft.
    end if;
    raise exception 'This contract already has a renewal';
  end if;
  insert into public.tenant_contracts(tenant_id,starts_on,ends_on,monthly_rent,security_deposit,status,notes,previous_contract_id)
  values(p.tenant_id,p_starts_on,p_ends_on,p_monthly_rent,p.security_deposit,'draft',nullif(btrim(p_notes),''),p.id)
  returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.renew_tenant_contract(uuid,date,date,numeric,text) from public,anon;
grant execute on function public.renew_tenant_contract(uuid,date,date,numeric,text) to authenticated;

-- Renewal drafts have no new deposit payment. Transfer existing held money only
-- when the signed renewal is activated, preserving an audit event on both sides.
create or replace function public.receive_deposit_on_contract_creation()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.previous_contract_id is null then
    perform public.initialize_contract_deposit_receipt(new.id,false);
  else
    insert into public.security_deposit_receipts(contract_id,tenant_id) values(new.id,new.tenant_id);
  end if;
  return new;
end;
$$;

create or replace function public.guard_renewal_deposit_receipt()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op='UPDATE' and old.transferred_to_contract_id is not null and new is distinct from old then
    raise exception 'This deposit has already transferred to the renewed contract';
  end if;
  if new.received_amount > 0 and exists(select 1 from public.tenant_contracts
    where id=new.contract_id and previous_contract_id is not null and status='draft') then
    raise exception 'A renewal draft cannot record a new deposit payment';
  end if;
  return new;
end;
$$;
create trigger security_deposit_receipts_renewal_guard before insert or update on public.security_deposit_receipts
  for each row execute function public.guard_renewal_deposit_receipt();
revoke all on function public.guard_renewal_deposit_receipt() from public,anon,authenticated;

create or replace function public.transfer_renewal_deposit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare r public.security_deposit_receipts; target public.security_deposit_receipts; v_reference text;
begin
  if new.previous_contract_id is null or new.status <> 'active' or old.status='active' then return new; end if;
  select * into r from public.security_deposit_receipts where contract_id=new.previous_contract_id for update;
  if not found then raise exception 'Record the previous contract deposit before activating the renewal'; end if;
  if r.settled_at is not null or r.refunded_amount<>0 or r.approved_deductions<>0
    or r.transferred_to_contract_id is not null then
    raise exception 'A settled or deducted deposit cannot be carried into a renewal';
  end if;
  select * into target from public.security_deposit_receipts where contract_id=new.id for update;
  if not found or target.received_amount<>0 or target.settled_at is not null
    or target.refunded_amount<>0 or target.approved_deductions<>0 then
    raise exception 'The renewal deposit receipt is not empty';
  end if;
  v_reference := 'Carried from ' || new.previous_contract_id::text;
  update public.security_deposit_receipts set received_amount=r.received_amount,received_on=r.received_on,
    method='Contract renewal carryover',reference=v_reference,updated_at=now() where contract_id=new.id;
  insert into public.security_deposit_receipt_events(contract_id,actor_id,reason,previous_amount,received_amount,received_on,method,reference)
  values(new.id,auth.uid(),'Existing deposit carried forward; no new payment received',0,r.received_amount,r.received_on,'Contract renewal carryover',v_reference);
  update public.security_deposit_receipts set received_amount=0,received_on=null,
    method='Transferred to renewed contract',reference=new.contract_number,
    transferred_to_contract_id=new.id,settled_at=now(),updated_at=now() where contract_id=r.contract_id;
  insert into public.security_deposit_receipt_events(contract_id,actor_id,reason,previous_amount,received_amount,received_on,method,reference)
  values(r.contract_id,auth.uid(),'Deposit transferred to ' || new.contract_number || '; not refunded',r.received_amount,0,null,'Contract renewal carryover',new.contract_number);
  return new;
end;
$$;
create trigger tenant_contracts_transfer_renewal_deposit after update of status on public.tenant_contracts
  for each row execute function public.transfer_renewal_deposit();
revoke all on function public.transfer_renewal_deposit() from public,anon,authenticated;

-- A move-out request may have read the old active contract before renewal
-- activation completed. Serialize it and reject that stale contract snapshot.
create or replace function public.guard_move_out_after_renewal()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_tenant uuid;
begin
  if new.contract_id is null or new.status='cancelled' then return new; end if;
  select tenant_id into v_tenant from public.tenant_contracts where id=new.contract_id;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_tenant::text,493));
  perform 1 from public.tenant_contracts where id=new.contract_id for update;
  if exists(select 1 from public.security_deposit_receipts
    where contract_id=new.contract_id and transferred_to_contract_id is not null) then
    raise exception 'This contract was renewed; create the move-out case using the current contract';
  end if;
  return new;
end;
$$;
create trigger move_out_cases_renewal_guard before insert or update on public.move_out_cases
  for each row execute function public.guard_move_out_after_renewal();
revoke all on function public.guard_move_out_after_renewal() from public,anon,authenticated;

-- Keep get_my_contract() unchanged: tenant access still uses the active term.
-- Only the signing/checklist screen prioritizes the upcoming renewal draft.
create or replace function public.get_my_contract_for_signing()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_result jsonb;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'tenant' then
    raise exception 'Tenant access required';
  end if;
  select to_jsonb(c) || jsonb_build_object('profiles',jsonb_build_object('full_name',p.full_name))
  into v_result from public.tenant_contracts c join public.profiles p on p.id=c.tenant_id
  where c.tenant_id=auth.uid() and c.status in ('draft','active')
  order by case when c.status='draft' and c.previous_contract_id is not null then 0
    when c.status='active' then 1 else 2 end, c.starts_on desc limit 1;
  return v_result;
end;
$$;
revoke all on function public.get_my_contract_for_signing() from public,anon;
grant execute on function public.get_my_contract_for_signing() to authenticated;

comment on column public.tenant_contracts.previous_contract_id is
  'Previous signed term. Renewal rent applies only to this new term; activation expires the previous term atomically.';
comment on column public.security_deposit_receipts.transferred_to_contract_id is
  'Held deposit was carried to this contract, with events preserving the original receipt history.';
notify pgrst, 'reload schema';
commit;

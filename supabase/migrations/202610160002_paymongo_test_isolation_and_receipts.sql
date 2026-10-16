begin;

-- Fail closed: test keys alone must never authorize credits to production bills.
-- Only a disposable local/staging database may opt in, using explicit sample bills.
create table public.paymongo_test_configuration (
  id boolean primary key default true check (id),
  deployment_environment text not null default 'production'
    check (deployment_environment in ('production','staging','local'))
);
insert into public.paymongo_test_configuration(id) values(true);
create table public.paymongo_test_bills (
  charge_id uuid primary key references public.billing_charges(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.paymongo_test_configuration enable row level security;
alter table public.paymongo_test_bills enable row level security;
revoke all on public.paymongo_test_configuration, public.paymongo_test_bills from public, anon, authenticated;
grant all on public.paymongo_test_configuration, public.paymongo_test_bills to service_role;
alter table public.payment_collection_settings alter column demo_test_credits set default false;

create function public.assert_paymongo_environment(p_environment text,p_charge_ids uuid[])
returns void language plpgsql security definer set search_path='' as $$
declare v_deployment text;
begin
  select deployment_environment into strict v_deployment from public.paymongo_test_configuration where id;
  if p_environment = 'live' then
    if v_deployment <> 'production' then raise exception 'Live payments are disabled in this testing database'; end if;
  elsif p_environment = 'test' then
    if v_deployment not in ('local','staging') then raise exception 'Test payments require a disposable local or staging database'; end if;
    if not coalesce((select demo_test_credits from public.payment_collection_settings where id),false) then
      raise exception 'Test ledger credits must be explicitly enabled in the disposable database';
    end if;
    if p_charge_ids is null or cardinality(p_charge_ids)=0 or exists (
      select 1 from unnest(p_charge_ids) x where x is null or not exists(
        select 1 from public.paymongo_test_bills b where b.charge_id=x)
    ) then raise exception 'Test payments are restricted to registered sample bills'; end if;
  else raise exception 'Invalid payment environment';
  end if;
end $$;
revoke all on function public.assert_paymongo_environment(text,uuid[]) from public,anon,authenticated;
grant execute on function public.assert_paymongo_environment(text,uuid[]) to service_role;

-- A session cannot be relabelled from test to live (or moved to another owner).
create or replace function public.guard_paymongo_breakdown() returns trigger language plpgsql set search_path='' as $$
begin
  if old.bill_breakdown is distinct from new.bill_breakdown or old.amount_centavos<>new.amount_centavos
    or old.charge_id<>new.charge_id or old.tenant_id<>new.tenant_id
    or old.environment is distinct from new.environment or old.enabled_by is distinct from new.enabled_by then
    raise exception 'Payment bill breakdown and environment are immutable';
  end if;
  return new;
end $$;

-- Retain the established billing/locking implementation behind a guarded entry.
alter function public.begin_paymongo_advance_payment(uuid[]) rename to begin_paymongo_advance_payment_core;
revoke all on function public.begin_paymongo_advance_payment_core(uuid[]) from public,anon,authenticated,service_role;
create function public.begin_paymongo_advance_payment(p_charge_ids uuid[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_environment text;
begin
  if auth.uid() is null or coalesce(public.current_user_role()::text,'') <> 'tenant' then
    raise exception 'Tenant access required';
  end if;
  select environment into strict v_environment from public.payment_collection_settings where id for share;
  perform public.assert_paymongo_environment(v_environment,p_charge_ids);
  return public.begin_paymongo_advance_payment_core(p_charge_ids);
end $$;
revoke all on function public.begin_paymongo_advance_payment(uuid[]) from public,anon;
grant execute on function public.begin_paymongo_advance_payment(uuid[]) to authenticated;
-- Rebind the SQL delegate; its old dependency otherwise targets the renamed core.
create or replace function public.begin_paymongo_payment(p_charge_id uuid) returns jsonb
language sql security definer set search_path='' as $$
  select public.begin_paymongo_advance_payment(array[p_charge_id]);
$$;

alter table public.paymongo_payment_sessions add column notification_pending boolean not null default false;
create function public.notify_verified_paymongo_payment(p_session_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare p public.paymongo_payment_sessions; v_title text; v_body text;
begin
  select * into p from public.paymongo_payment_sessions where id=p_session_id;
  if not found or p.status<>'succeeded' or not p.notification_pending then return; end if;
  v_title := case when p.environment='test' then 'Test payment confirmed' else 'Payment confirmed' end;
  v_body := case when p.environment='test' then 'TEST TRANSACTION - no real money received. Your sample bill payment was verified.'
    else 'Your payment was automatically confirmed through PayMongo QR Ph.' end;
  begin
    perform public.emit_tenant_circle_notification(p.tenant_id,true,true,'payment',v_title,v_body,'payment',p.charge_id,
      jsonb_build_object('payment_session_id',p.id,'bill_breakdown',p.bill_breakdown,'environment',p.environment),
      'paymongo-paid:'||p.id::text,0);
    perform public.emit_staff_notification('payment',v_title,v_body,'payment',p.charge_id,
      jsonb_build_object('payment_session_id',p.id,'tenant_id',p.tenant_id,'environment',p.environment),
      'paymongo-paid:'||p.id::text,0);
    update public.paymongo_payment_sessions set notification_pending=false where id=p.id;
  exception when others then
    -- Retry on the next status check, webhook, or existing reconciliation job.
    -- Notification delivery is never allowed to roll back a verified payment.
    null;
  end;
end $$;
revoke all on function public.notify_verified_paymongo_payment(uuid) from public,anon,authenticated;
grant execute on function public.notify_verified_paymongo_payment(uuid) to service_role;

create or replace function public.settle_paymongo_payment(
  p_session_id uuid,p_intent_id text,p_payment_id text,p_amount_centavos bigint,
  p_currency text,p_environment text,p_paid_at timestamptz
) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.paymongo_payment_sessions; c public.billing_charges; item jsonb;
  v_balance numeric; v_status text; v_transaction uuid; v_first uuid; v_credit boolean;
begin
  select * into p from public.paymongo_payment_sessions where id=p_session_id;
  if not found then raise exception 'Payment session not found'; end if;
  perform public.assert_paymongo_environment(p.environment, array(
    select (x->>'charge_id')::uuid from jsonb_array_elements(p.bill_breakdown) x));
  perform 1 from public.billing_charges where id in (
    select (x->>'charge_id')::uuid from jsonb_array_elements(p.bill_breakdown) x) order by id for update;
  select * into p from public.paymongo_payment_sessions where id=p_session_id for update;
  if p.provider_intent_id is distinct from p_intent_id or p.amount_centavos is distinct from p_amount_centavos
    or p.environment is distinct from p_environment or p_currency is distinct from 'PHP'
    or p_payment_id is null or p_payment_id not like 'pay_%' or p_paid_at is null then
    raise exception 'Provider payment does not match this bill'; end if;
  v_credit := p.environment='live' or (select demo_test_credits from public.payment_collection_settings where id);
  if p.status='succeeded' then
    if p.provider_payment_id is distinct from p_payment_id then raise exception 'Payment confirmation conflict'; end if;
    if p.credited_transaction_id is not null or not v_credit then
      perform public.notify_verified_paymongo_payment(p.id);
      return to_jsonb(p);
    end if;
  end if;
  if v_credit then
    -- Validate all allocations before crediting any month.
    for item in select * from jsonb_array_elements(p.bill_breakdown) loop
      select remaining_balance,status into v_balance,v_status from public.billing_charge_summaries where id=(item->>'charge_id')::uuid;
      if not found or not exists(select 1 from public.billing_charges b where b.id=(item->>'charge_id')::uuid and b.tenant_id=p.tenant_id) or v_status='voided' or round(v_balance*100)::bigint<>(item->>'amount_centavos')::bigint
        or exists(select 1 from public.payment_transactions where charge_id=(item->>'charge_id')::uuid and status='pending_verification') then
        update public.paymongo_payment_sessions set status='needs_review',provider_payment_id=p_payment_id,
          issue='Payment received but a selected bill changed. Staff reconciliation required.',last_checked_at=now()
          where id=p.id returning * into p;
        perform public.emit_staff_notification('payment','Payment needs reconciliation',p.issue,
          'payment',p.charge_id,jsonb_build_object('payment_session_id',p.id),'paymongo-review:'||p.id::text,0);
        return to_jsonb(p);
      end if;
    end loop;
    for item in select * from jsonb_array_elements(p.bill_breakdown) loop
      select * into strict c from public.billing_charges where id=(item->>'charge_id')::uuid;
      insert into public.payment_transactions(charge_id,contract_id,tenant_id,amount,status,payment_method,
        reference_number,submitted_by,submitted_at,reviewed_by,reviewed_at,review_notes,gateway_session_id)
      values(c.id,c.contract_id,c.tenant_id,(item->>'amount_centavos')::numeric/100,'verified','PayMongo QR Ph',
        p_payment_id,p.tenant_id,p_paid_at,p.enabled_by,now(),
        case when p.environment='test' then 'DEMO TEST PAYMENT - no real money received. ' else '' end ||
        'Automatically confirmed by PayMongo; owner enabled the gateway. Session '||p.id::text||
        '. Month: '||(item->>'title'),p.id) returning id into v_transaction;
      v_first := coalesce(v_first,v_transaction);
    end loop;
  end if;
  update public.paymongo_payment_sessions set status='succeeded',provider_payment_id=p_payment_id,
    credited_transaction_id=v_first,settled_at=p_paid_at,last_checked_at=now(),issue=null,notification_pending=v_credit where id=p.id returning * into p;
  if v_credit then perform public.notify_verified_paymongo_payment(p.id); end if;
  return to_jsonb(p);
end $$;

create or replace function public.guard_gateway_payment_ledger() returns trigger
language plpgsql set search_path='' as $$
declare p public.paymongo_payment_sessions;
begin
  perform 1 from public.billing_charges where id=new.charge_id for update;
  if tg_op='UPDATE' and old.gateway_session_id is distinct from new.gateway_session_id then raise exception 'Gateway payment provenance is immutable'; end if;
  if new.gateway_session_id is not null then
    if coalesce(auth.role(),'')<>'service_role' then raise exception 'Gateway verification requires backend access'; end if;
    select * into p from public.paymongo_payment_sessions where id=new.gateway_session_id;
    if not found then raise exception 'Gateway transaction mismatch'; end if;
    perform public.assert_paymongo_environment(p.environment,array[new.charge_id]);
    if (p.environment<>'live' and not (select demo_test_credits from public.payment_collection_settings where id))
      or p.tenant_id<>new.tenant_id or not exists(select 1 from jsonb_array_elements(p.bill_breakdown) item
        where (item->>'charge_id')::uuid=new.charge_id and (item->>'amount_centavos')::numeric/100=new.amount)
      then raise exception 'Gateway transaction mismatch'; end if;
  elsif tg_op='INSERT' then
    if new.reference_number is not null and exists(select 1 from public.paymongo_payment_sessions where provider_payment_id=new.reference_number) then
      raise exception 'Gateway payments cannot be recorded as manual receipts';
    end if;
    if public.current_user_role()::text='tenant' and (select mode from public.payment_collection_settings where id)<>'manual' then
      raise exception 'Receipt submission is disabled. Use the automatic payment option.'; end if;
    if exists(select 1 from public.paymongo_payment_sessions where
      bill_breakdown @> jsonb_build_array(jsonb_build_object('charge_id',new.charge_id))
      and (environment='live' or (select demo_test_credits from public.payment_collection_settings where id))
      and status in ('creating','pending','needs_review')) then
      raise exception 'An automatic payment is still active. Cancel or reconcile it before recording another receipt.'; end if;
  end if;
  return new;
end $$;

create or replace function public.claim_paymongo_reconciliation() returns setof public.paymongo_payment_sessions
language sql security definer set search_path = '' as $$
  with candidates as (
    select id from public.paymongo_payment_sessions
    where (status in ('creating','pending','needs_review') or (status='succeeded' and notification_pending))
      and coalesce(last_checked_at,created_at)<now()-interval '5 minutes'
      and environment=(select environment from public.payment_collection_settings where id)
    order by coalesce(last_checked_at,created_at) limit 6 for update skip locked
  ) update public.paymongo_payment_sessions set last_checked_at=now()
    where id in (select id from candidates) returning *;
$$;

-- One immutable receipt snapshot per verified ledger transaction, across both
-- gateway and manual verification. PDF rendering can retry without another payment.
create table public.payment_receipts (
  id uuid primary key references public.payment_transactions(id) on delete restrict,
  receipt_number text not null unique,
  tenant_id uuid not null references public.profiles(id),
  charge_id uuid not null references public.billing_charges(id),
  tenant_name text not null, bill_title text not null,
  amount numeric(12,2) not null check(amount>0),
  reference_number text not null, payment_method text not null,
  verified_at timestamptz not null, received_at timestamptz not null,
  environment text not null check(environment in ('manual','test','live')),
  balance_after numeric(12,2) not null,
  created_at timestamptz not null default now()
);
alter table public.payment_receipts enable row level security;
revoke all on public.payment_receipts from public,anon,authenticated;
grant select on public.payment_receipts to authenticated;
grant select,insert on public.payment_receipts to service_role;
create policy payment_receipt_read on public.payment_receipts for select to authenticated
using (public.is_staff() or (tenant_id=auth.uid() and public.current_user_role()::text='tenant'));

create function public.create_payment_receipt_snapshot(p_transaction_id uuid)
returns public.payment_receipts language plpgsql security definer set search_path='' as $$
declare r public.payment_receipts;
begin
  insert into public.payment_receipts(id,receipt_number,tenant_id,charge_id,tenant_name,bill_title,
    amount,reference_number,payment_method,verified_at,received_at,environment,balance_after)
  select t.id,'PAY-'||upper(t.id::text),t.tenant_id,t.charge_id,coalesce(nullif(btrim(p.full_name),''),t.tenant_id::text),c.title,t.amount,
    coalesce(nullif(btrim(t.reference_number),''),t.id::text),coalesce(t.payment_method,'Manual payment'),
    coalesce(t.reviewed_at,t.submitted_at),coalesce(t.received_on::timestamptz,t.submitted_at),coalesce(s.environment,'manual'),
    greatest(coalesce(b.remaining_balance,0),0)
  from public.payment_transactions t
  join public.billing_charges c on c.id=t.charge_id
  join public.profiles p on p.id=t.tenant_id
  join public.billing_charge_summaries b on b.id=t.charge_id
  left join public.paymongo_payment_sessions s on s.id=t.gateway_session_id
  where t.id=p_transaction_id and t.status='verified'
  on conflict(id) do nothing;
  select * into r from public.payment_receipts where id=p_transaction_id;
  if not found then raise exception 'A verified payment is required for a receipt'; end if;
  return r;
end $$;
revoke all on function public.create_payment_receipt_snapshot(uuid) from public,anon,authenticated,service_role;

create function public.try_create_payment_receipt() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if new.status='verified' then
    -- A receipt issue must never reverse valid financial settlement. Authorized
    -- receipt reads below retry using the same transaction ID and receipt number.
    begin
      perform public.create_payment_receipt_snapshot(new.id);
    exception when others then
      null;
    end;
  end if;
  return new;
end $$;
create trigger create_verified_payment_receipt after insert or update of status
on public.payment_transactions for each row execute function public.try_create_payment_receipt();

create function public.get_payment_receipt(p_transaction_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare t public.payment_transactions; r public.payment_receipts;
begin
  select * into t from public.payment_transactions where id=p_transaction_id;
  if not found or not (coalesce(auth.role(),'')='service_role' or
    (auth.uid() is not null and (coalesce(public.is_staff(),false) or
      (t.tenant_id=auth.uid() and public.current_user_role()::text='tenant')))) then
    raise exception 'Payment receipt not available';
  end if;
  r := public.create_payment_receipt_snapshot(t.id);
  return to_jsonb(r);
end $$;
revoke all on function public.get_payment_receipt(uuid) from public,anon;
grant execute on function public.get_payment_receipt(uuid) to authenticated,service_role;

create function public.get_paymongo_receipts(p_session_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p public.paymongo_payment_sessions; t record; r jsonb; result jsonb:='[]';
begin
  select * into p from public.paymongo_payment_sessions where id=p_session_id;
  if not found or not (coalesce(auth.role(),'')='service_role' or
    (auth.uid() is not null and (coalesce(public.is_staff(),false) or
      (p.tenant_id=auth.uid() and public.current_user_role()::text='tenant')))) then
    raise exception 'Payment receipt not available';
  end if;
  for t in select id from public.payment_transactions
    where gateway_session_id=p.id and status='verified' order by id loop
    r := public.get_payment_receipt(t.id);
    result := result || jsonb_build_array(r);
  end loop;
  return result;
end $$;
revoke all on function public.get_paymongo_receipts(uuid) from public,anon;
grant execute on function public.get_paymongo_receipts(uuid) to authenticated,service_role;

do $patch$
declare definition text;
begin
  if to_regprocedure('private.dispatch_paymongo_reconciliation()') is not null then
    select pg_get_functiondef(to_regprocedure('private.dispatch_paymongo_reconciliation()')) into definition;
    definition := replace(definition, 'where status in (''creating'',''pending'',''needs_review'')',
      'where (status in (''creating'',''pending'',''needs_review'') or (status=''succeeded'' and notification_pending))');
    execute definition;
  end if;
end $patch$;

notify pgrst,'reload schema';
commit;

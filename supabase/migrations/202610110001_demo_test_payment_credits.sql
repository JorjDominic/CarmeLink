-- Temporary demo behavior: provider-confirmed sandbox payments credit the shared ledger.
-- Disable before real billing: update public.payment_collection_settings set demo_test_credits=false where id;
begin;
alter table public.payment_collection_settings
  add column demo_test_credits boolean not null default true;
create or replace function public.settle_paymongo_payment(
  p_session_id uuid,p_intent_id text,p_payment_id text,p_amount_centavos bigint,
  p_currency text,p_environment text,p_paid_at timestamptz
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare p public.paymongo_payment_sessions; c public.billing_charges;
  v_balance numeric; v_status text; v_transaction uuid;
begin
  select charge_id into p.charge_id from public.paymongo_payment_sessions where id=p_session_id;
  if not found then raise exception 'Payment session not found'; end if;
  select * into c from public.billing_charges where id=p.charge_id for update;
  select * into p from public.paymongo_payment_sessions where id=p_session_id for update;
  if p.provider_intent_id is distinct from p_intent_id or p.amount_centavos is distinct from p_amount_centavos
    or p.environment is distinct from p_environment or p_currency is distinct from 'PHP'
    or p_payment_id is null or p_payment_id not like 'pay_%' or p_paid_at is null then
    raise exception 'Provider payment does not match this bill'; end if;
  if p.status='succeeded' then
    if p.provider_payment_id is distinct from p_payment_id then raise exception 'Payment confirmation conflict'; end if;
    if p.credited_transaction_id is not null or
      (p.environment='test' and not (select demo_test_credits from public.payment_collection_settings where id)) then
      return to_jsonb(p);
    end if;
  end if;
  if p.environment='live' or (select demo_test_credits from public.payment_collection_settings where id) then
    select remaining_balance,status into v_balance,v_status from public.billing_charge_summaries where id=c.id;
    if v_status='voided' or v_balance < p.amount_centavos::numeric/100
      or exists(select 1 from public.payment_transactions where charge_id=c.id and status='pending_verification') then
      update public.paymongo_payment_sessions set status='needs_review',provider_payment_id=p_payment_id,
        issue='Payment received but the bill balance changed. Staff reconciliation required.',last_checked_at=now()
        where id=p.id returning * into p;
      perform public.emit_staff_notification('payment','Payment needs reconciliation',p.issue,
        'payment',c.id,jsonb_build_object('payment_session_id',p.id),'paymongo-review:'||p.id::text,0);
      return to_jsonb(p);
    end if;
    insert into public.payment_transactions(charge_id,contract_id,tenant_id,amount,status,payment_method,
      reference_number,submitted_by,submitted_at,reviewed_by,reviewed_at,review_notes,gateway_session_id)
    values(c.id,c.contract_id,c.tenant_id,p.amount_centavos::numeric/100,'verified','PayMongo QR Ph',
      p_payment_id,p.tenant_id,p_paid_at,p.enabled_by,now(),
      case when p.environment='test' then 'DEMO TEST PAYMENT - no real money received. ' else '' end ||
      'Automatically confirmed by PayMongo; owner enabled the gateway. Session '||p.id::text,p.id)
      returning id into v_transaction;
  end if;
  update public.paymongo_payment_sessions set status='succeeded',provider_payment_id=p_payment_id,
    credited_transaction_id=v_transaction,settled_at=p_paid_at,last_checked_at=now(),issue=null
    where id=p.id returning * into p;
  if p.environment='live' or (select demo_test_credits from public.payment_collection_settings where id) then
    perform public.emit_tenant_circle_notification(c.tenant_id,true,true,'payment','Payment confirmed',
      'Your payment was automatically confirmed through PayMongo QR Ph.','payment',c.id,
      jsonb_build_object('payment_session_id',p.id),'paymongo-paid:'||p.id::text,0);
  end if;
  return to_jsonb(p);
end $$;
revoke all on function public.settle_paymongo_payment(uuid,text,text,bigint,text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.settle_paymongo_payment(uuid,text,text,bigint,text,text,timestamptz) to service_role;

create or replace function public.guard_gateway_payment_ledger() returns trigger
language plpgsql set search_path = '' as $$
declare p public.paymongo_payment_sessions;
begin
  -- Preserve the lock order shared with staff receipts, reviews and settlement.
  perform 1 from public.billing_charges where id=new.charge_id for update;
  if tg_op='UPDATE' and old.gateway_session_id is distinct from new.gateway_session_id then
    raise exception 'Gateway payment provenance is immutable'; end if;
  if new.gateway_session_id is not null then
    if coalesce(auth.role(),'')<>'service_role' then raise exception 'Gateway verification requires backend access'; end if;
    select * into p from public.paymongo_payment_sessions where id=new.gateway_session_id;
    if not found or (p.environment<>'live' and not (select demo_test_credits from public.payment_collection_settings where id)) or p.charge_id<>new.charge_id or p.tenant_id<>new.tenant_id
      or p.amount_centavos::numeric/100<>new.amount then raise exception 'Gateway transaction mismatch'; end if;
  elsif tg_op='INSERT' then
    if public.current_user_role()::text='tenant' and
      (select mode from public.payment_collection_settings where id) <> 'manual' then
      raise exception 'Receipt submission is disabled. Use the automatic payment option.'; end if;
    if exists(select 1 from public.paymongo_payment_sessions where charge_id=new.charge_id
      and (environment='live' or (select demo_test_credits from public.payment_collection_settings where id)) and status in ('creating','pending','needs_review')) then
      raise exception 'An automatic payment is still active. Cancel or reconcile it before recording another receipt.'; end if;
  end if;
  return new;
end $$;

create or replace function public.validate_configured_payment_method()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.payment_method is null then return new; end if;
  if tg_table_name='payment_transactions' and to_jsonb(new)->>'gateway_session_id' is not null then
    select case when environment='test' then 'PayMongo QR Ph (Demo Test)' else 'PayMongo QR Ph' end
      into new.payment_method from public.paymongo_payment_sessions where id=new.gateway_session_id;
    return new;
  end if;
  if tg_op='UPDATE' and new.payment_method is not distinct from old.payment_method then return new; end if;
  select label into new.payment_method from public.dormitory_options
    where group_key='payment_method' and is_active
      and (code=new.payment_method or lower(btrim(label))=lower(btrim(new.payment_method)))
    order by (code=new.payment_method) desc limit 1;
  if not found then raise exception 'Choose an active payment method'; end if;
  return new;
end $$;

commit;

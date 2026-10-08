begin;

-- Replace the unconfigured Maya placeholder with PayMongo. No keys or live
-- processing are enabled by this migration.
do $$ declare c record; begin
  for c in select conname from pg_constraint
    where conrelid='public.payment_collection_settings'::regclass and contype='c'
      and pg_get_constraintdef(oid) like '%maya%'
  loop execute format('alter table public.payment_collection_settings drop constraint %I',c.conname); end loop;
end $$;
update public.payment_collection_settings set mode='manual' where mode='maya';
alter table public.payment_collection_settings
  add column paymongo_ready boolean not null default false,
  add column environment text not null default 'test' check(environment in ('test','live')),
  add constraint collection_mode_valid check(mode in ('manual','paymongo')),
  add constraint collection_gateway_ready check(mode<>'paymongo' or paymongo_ready);

create or replace function public.set_payment_collection_mode(p_mode text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare s public.payment_collection_settings;
begin
  if auth.uid() is null or coalesce(public.current_user_role()::text,'')<>'owner' then
    raise exception 'Only the owner can change payment collection mode';
  end if;
  if p_mode is null or p_mode not in ('manual','paymongo') then raise exception 'Choose manual or PayMongo'; end if;
  select * into strict s from public.payment_collection_settings where id for update;
  if p_mode='paymongo' and not s.paymongo_ready then raise exception 'PayMongo is not connected yet'; end if;
  if s.mode<>p_mode then
    insert into public.payment_collection_settings_history(previous_mode,new_mode,changed_by)
      values(s.mode,p_mode,auth.uid());
    update public.payment_collection_settings set mode=p_mode,updated_by=auth.uid(),updated_at=now()
      where id returning * into s;
  end if;
  return to_jsonb(s);
end $$;

create table public.paymongo_payment_sessions (
  id uuid primary key default gen_random_uuid(),
  charge_id uuid not null references public.billing_charges(id) on delete restrict,
  tenant_id uuid not null references public.profiles(id) on delete restrict,
  enabled_by uuid not null references public.profiles(id) on delete restrict,
  environment text not null check(environment in ('test','live')),
  amount_centavos bigint not null check(amount_centavos>=100),
  status text not null default 'creating'
    check(status in ('creating','pending','succeeded','failed','expired','cancelled','needs_review')),
  provider_intent_id text unique,
  provider_payment_id text unique,
  provider_method_id text,
  qr_image text,
  test_url text,
  expires_at timestamptz,
  issue text,
  created_at timestamptz not null default now(),
  last_checked_at timestamptz,
  settled_at timestamptz,
  credited_transaction_id uuid unique references public.payment_transactions(id)
);
create unique index paymongo_active_bill on public.paymongo_payment_sessions(charge_id,environment)
  where status in ('creating','pending','needs_review');
create index paymongo_reconciliation on public.paymongo_payment_sessions(last_checked_at,created_at)
  where status in ('creating','pending','needs_review');
alter table public.paymongo_payment_sessions enable row level security;
revoke all on public.paymongo_payment_sessions from anon,authenticated;
grant select on public.paymongo_payment_sessions to authenticated;
grant all on public.paymongo_payment_sessions to service_role;
create policy paymongo_session_read on public.paymongo_payment_sessions for select to authenticated
  using(public.is_staff() or (tenant_id=auth.uid() and public.current_user_role()::text='tenant'));
alter table public.payment_transactions
  add column gateway_session_id uuid unique references public.paymongo_payment_sessions(id);

create function public.begin_paymongo_payment(p_charge_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.billing_charges; s public.payment_collection_settings;
  p public.paymongo_payment_sessions; v_balance numeric; v_status text; v_owner uuid;
begin
  if auth.uid() is null or coalesce(public.current_user_role()::text,'')<>'tenant' then
    raise exception 'Tenant access required'; end if;
  select * into strict s from public.payment_collection_settings where id for share;
  if s.mode<>'paymongo' or not s.paymongo_ready then raise exception 'Automatic payments are unavailable. Refresh your payment options.'; end if;
  select * into c from public.billing_charges where id=p_charge_id for update;
  if not found or c.tenant_id<>auth.uid() then raise exception 'Bill not found'; end if;
  if c.category='deposit' then raise exception 'Security deposits are managed separately'; end if;
  select * into p from public.paymongo_payment_sessions where charge_id=c.id and environment=s.environment
    and status in ('creating','pending','needs_review') limit 1;
  if found then return jsonb_build_object('session',to_jsonb(p),'is_new',false); end if;
  select remaining_balance,status into v_balance,v_status from public.billing_charge_summaries where id=c.id;
  if v_status='voided' or v_balance<1 then raise exception 'Bill is paid, voided, or below the PHP 1.00 minimum'; end if;
  if exists(select 1 from public.payment_transactions where charge_id=c.id and status='pending_verification') then
    raise exception 'Review the pending receipt before starting another payment'; end if;
  select id into v_owner from public.profiles where id=s.updated_by and role::text='owner';
  if v_owner is null then raise exception 'An owner must enable automatic payments first'; end if;
  insert into public.paymongo_payment_sessions(charge_id,tenant_id,enabled_by,environment,amount_centavos)
    values(c.id,c.tenant_id,v_owner,s.environment,round(v_balance*100)::bigint) returning * into p;
  return jsonb_build_object('session',to_jsonb(p),'is_new',true);
end $$;
revoke all on function public.begin_paymongo_payment(uuid) from public,anon;
grant execute on function public.begin_paymongo_payment(uuid) to authenticated;

-- A timed-out request may resume after its lease, always using the same
-- provider idempotency keys. Never retry creation beyond their 24h lifetime.
create function public.claim_paymongo_creation(p_session_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p public.paymongo_payment_sessions;
begin
  update public.paymongo_payment_sessions set last_checked_at=now()
    where id=p_session_id and status='creating'
      and created_at>now()-interval '23 hours'
      and coalesce(last_checked_at,created_at)<now()-interval '90 seconds'
    returning * into p;
  if found then return to_jsonb(p); end if;
  return null;
end $$;
revoke all on function public.claim_paymongo_creation(uuid) from public,anon,authenticated;
grant execute on function public.claim_paymongo_creation(uuid) to service_role;

create function public.claim_paymongo_reconciliation() returns setof public.paymongo_payment_sessions
language sql security definer set search_path = '' as $$
  with candidates as (
    select id from public.paymongo_payment_sessions
    where status in ('creating','pending','needs_review')
      and coalesce(last_checked_at,created_at)<now()-interval '5 minutes'
      and environment=(select environment from public.payment_collection_settings where id)
    order by coalesce(last_checked_at,created_at) limit 6 for update skip locked
  ) update public.paymongo_payment_sessions set last_checked_at=now()
    where id in (select id from candidates) returning *;
$$;
revoke all on function public.claim_paymongo_reconciliation() from public,anon,authenticated;
grant execute on function public.claim_paymongo_reconciliation() to service_role;

-- Only the authenticated backend may confirm a provider payment. Test mode
-- confirmations never insert payment_transactions or reduce real balances.
create function public.settle_paymongo_payment(
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
    return to_jsonb(p);
  end if;
  if p.environment='live' then
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
      'Automatically confirmed by PayMongo; owner enabled the gateway. Session '||p.id::text,p.id)
      returning id into v_transaction;
  end if;
  update public.paymongo_payment_sessions set status='succeeded',provider_payment_id=p_payment_id,
    credited_transaction_id=v_transaction,settled_at=p_paid_at,last_checked_at=now(),issue=null
    where id=p.id returning * into p;
  if p.environment='live' then
    perform public.emit_tenant_circle_notification(c.tenant_id,true,true,'payment','Payment confirmed',
      'Your payment was automatically confirmed through PayMongo QR Ph.','payment',c.id,
      jsonb_build_object('payment_session_id',p.id),'paymongo-paid:'||p.id::text,0);
  end if;
  return to_jsonb(p);
end $$;
revoke all on function public.settle_paymongo_payment(uuid,text,text,bigint,text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.settle_paymongo_payment(uuid,text,text,bigint,text,text,timestamptz) to service_role;

create function public.guard_gateway_payment_ledger() returns trigger
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
    if not found or p.environment<>'live' or p.charge_id<>new.charge_id or p.tenant_id<>new.tenant_id
      or p.amount_centavos::numeric/100<>new.amount then raise exception 'Gateway transaction mismatch'; end if;
  elsif tg_op='INSERT' then
    if public.current_user_role()::text='tenant' and
      (select mode from public.payment_collection_settings where id) <> 'manual' then
      raise exception 'Receipt submission is disabled. Use the automatic payment option.'; end if;
    if exists(select 1 from public.paymongo_payment_sessions where charge_id=new.charge_id
      and environment='live' and status in ('creating','pending','needs_review')) then
      raise exception 'An automatic payment is still active. Cancel or reconcile it before recording another receipt.'; end if;
  end if;
  return new;
end $$;
create trigger a_guard_gateway_payment_ledger before insert or update on public.payment_transactions
for each row execute function public.guard_gateway_payment_ledger();

-- Provider method is a fixed ledger description, independent of editable
-- manual payment methods. Manual methods retain their existing validation.
create or replace function public.validate_configured_payment_method()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.payment_method is null then return new; end if;
  if tg_table_name='payment_transactions' and to_jsonb(new)->>'gateway_session_id' is not null then
    new.payment_method := 'PayMongo QR Ph'; return new; end if;
  if tg_op='UPDATE' and new.payment_method is not distinct from old.payment_method then return new; end if;
  select label into new.payment_method from public.dormitory_options
    where group_key='payment_method' and is_active
      and (code=new.payment_method or lower(btrim(label))=lower(btrim(new.payment_method)))
    order by (code=new.payment_method) desc limit 1;
  if not found then raise exception 'Choose an active payment method'; end if;
  return new;
end $$;

commit;

-- One provider payment, immutable bill breakdown, one ledger entry per bill.
begin;
alter table public.paymongo_payment_sessions add column bill_breakdown jsonb not null default '[]';
update public.paymongo_payment_sessions p set bill_breakdown=jsonb_build_array(jsonb_build_object(
  'charge_id',c.id,'title',c.title,'period_start',c.period_start,'period_end',c.period_end,
  'due_date',c.due_date,'amount_centavos',p.amount_centavos))
from public.billing_charges c where c.id=p.charge_id;
alter table public.payment_transactions drop constraint payment_transactions_gateway_session_id_key;
create unique index payment_transactions_gateway_bill on public.payment_transactions(gateway_session_id,charge_id);
create index paymongo_bill_breakdown on public.paymongo_payment_sessions using gin(bill_breakdown);

create function public.guard_paymongo_breakdown() returns trigger language plpgsql set search_path='' as $$
begin
  if old.bill_breakdown is distinct from new.bill_breakdown or old.amount_centavos<>new.amount_centavos
    or old.charge_id<>new.charge_id or old.tenant_id<>new.tenant_id then
    raise exception 'Payment bill breakdown is immutable';
  end if;
  return new;
end $$;
create trigger guard_paymongo_breakdown before update on public.paymongo_payment_sessions
for each row execute function public.guard_paymongo_breakdown();

create function public.begin_paymongo_advance_payment(p_charge_ids uuid[]) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c public.billing_charges; s public.payment_collection_settings; p public.paymongo_payment_sessions;
  v_ids uuid[]; v_balance numeric; v_status text; v_owner uuid; v_items jsonb := '[]'; v_total bigint := 0;
begin
  if auth.uid() is null or coalesce(public.current_user_role()::text,'')<>'tenant' then raise exception 'Tenant access required'; end if;
  if p_charge_ids is null or cardinality(p_charge_ids) not between 1 and 60
    or array_position(p_charge_ids,null) is not null then raise exception 'Choose between 1 and 60 bills'; end if;
  select array_agg(distinct x order by x) into v_ids from unnest(p_charge_ids) x;
  if cardinality(v_ids)<>cardinality(p_charge_ids) then raise exception 'Choose each bill only once'; end if;
  select * into strict s from public.payment_collection_settings where id for share;
  if s.mode<>'paymongo' or not s.paymongo_ready then raise exception 'Automatic payments are unavailable. Refresh your payment options.'; end if;
  -- Lock every selected bill in stable order before checking overlaps or balances.
  perform 1 from public.billing_charges where id=any(v_ids) order by id for update;
  if (select count(*) from public.billing_charges where id=any(v_ids) and tenant_id=auth.uid())<>cardinality(v_ids) then raise exception 'Bill not found'; end if;
  for p in select * from public.paymongo_payment_sessions ps where ps.environment=s.environment
    and ps.status in ('creating','pending','needs_review') and exists(
      select 1 from jsonb_array_elements(ps.bill_breakdown) item where (item->>'charge_id')::uuid=any(v_ids))
  loop
    if (select array_agg((item->>'charge_id')::uuid order by (item->>'charge_id')::uuid)
      from jsonb_array_elements(p.bill_breakdown) item)=v_ids then
      return jsonb_build_object('session',to_jsonb(p),'is_new',false);
    end if;
    raise exception 'A selected month has an active payment. Open or cancel that request first.';
  end loop;
  for c in select * from public.billing_charges where id=any(v_ids) order by coalesce(period_start,due_date),id loop
    if c.category='deposit' then raise exception 'Security deposits are managed separately'; end if;
    if cardinality(v_ids)>1 and c.category<>'rent' then raise exception 'Only rent bills can be combined'; end if;
    select remaining_balance,status into v_balance,v_status from public.billing_charge_summaries where id=c.id;
    if v_status='voided' or v_balance<=0 then raise exception 'A selected bill is paid or voided. Refresh your bills.'; end if;
    if exists(select 1 from public.payment_transactions where charge_id=c.id and status='pending_verification') then
      raise exception 'Review the pending receipt before starting another payment'; end if;
    v_items := v_items || jsonb_build_array(jsonb_build_object('charge_id',c.id,'title',c.title,
      'period_start',c.period_start,'period_end',c.period_end,'due_date',c.due_date,'amount_centavos',round(v_balance*100)::bigint));
    v_total := v_total + round(v_balance*100)::bigint;
  end loop;
  if v_total<100 then raise exception 'Payment is below the PHP 1.00 minimum'; end if;
  select id into v_owner from public.profiles where id=s.updated_by and role::text='owner';
  if v_owner is null then raise exception 'An owner must enable automatic payments first'; end if;
  insert into public.paymongo_payment_sessions(charge_id,tenant_id,enabled_by,environment,amount_centavos,bill_breakdown)
    values((v_items->0->>'charge_id')::uuid,auth.uid(),v_owner,s.environment,v_total,v_items) returning * into p;
  return jsonb_build_object('session',to_jsonb(p),'is_new',true);
end $$;
revoke all on function public.begin_paymongo_advance_payment(uuid[]) from public,anon;
grant execute on function public.begin_paymongo_advance_payment(uuid[]) to authenticated;
create or replace function public.begin_paymongo_payment(p_charge_id uuid) returns jsonb
language sql security definer set search_path='' as $$ select public.begin_paymongo_advance_payment(array[p_charge_id]) $$;

create or replace function public.settle_paymongo_payment(
  p_session_id uuid,p_intent_id text,p_payment_id text,p_amount_centavos bigint,
  p_currency text,p_environment text,p_paid_at timestamptz
) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.paymongo_payment_sessions; c public.billing_charges; item jsonb;
  v_balance numeric; v_status text; v_transaction uuid; v_first uuid; v_credit boolean;
begin
  select * into p from public.paymongo_payment_sessions where id=p_session_id;
  if not found then raise exception 'Payment session not found'; end if;
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
    if p.credited_transaction_id is not null or not v_credit then return to_jsonb(p); end if;
  end if;
  if v_credit then
    -- Validate all allocations before crediting any month.
    for item in select * from jsonb_array_elements(p.bill_breakdown) loop
      select remaining_balance,status into v_balance,v_status from public.billing_charge_summaries where id=(item->>'charge_id')::uuid;
      if not found or v_status='voided' or round(v_balance*100)::bigint<>(item->>'amount_centavos')::bigint
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
    credited_transaction_id=v_first,settled_at=p_paid_at,last_checked_at=now(),issue=null where id=p.id returning * into p;
  if v_credit then
    perform public.emit_tenant_circle_notification(p.tenant_id,true,true,'payment','Payment confirmed',
      'Your payment was automatically confirmed through PayMongo QR Ph.','payment',p.charge_id,
      jsonb_build_object('payment_session_id',p.id,'bill_breakdown',p.bill_breakdown),'paymongo-paid:'||p.id::text,0);
  end if;
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
    if not found or (p.environment<>'live' and not (select demo_test_credits from public.payment_collection_settings where id))
      or p.tenant_id<>new.tenant_id or not exists(select 1 from jsonb_array_elements(p.bill_breakdown) item
        where (item->>'charge_id')::uuid=new.charge_id and (item->>'amount_centavos')::numeric/100=new.amount)
      then raise exception 'Gateway transaction mismatch'; end if;
  elsif tg_op='INSERT' then
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
commit;

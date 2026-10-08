-- Staff receipts are verified ledger entries, not new bills.
begin;
alter table public.payment_transactions
  add column staff_request_id uuid unique,
  add column received_on date,
  add column staff_method_code text;

create or replace function public.record_staff_payment(
  p_request_id uuid, p_charge_id uuid, p_amount numeric, p_method text,
  p_received_on date, p_reference_number text, p_receipt_path text,
  p_notes text default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c public.billing_charges;
  t public.payment_transactions;
  v_balance numeric;
  v_status text;
  v_method text;
  v_summary jsonb;
  v_new boolean := false;
begin
  if auth.uid() is null or coalesce(public.current_user_role()::text, '') not in ('owner','caretaker') then
    raise exception 'Owner or caretaker access required';
  end if;
  if p_request_id is null then raise exception 'Receipt request ID required'; end if;
  -- Serialise retries, then serialize receipts against the same bill.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_request_id::text, 0));
  select * into t from public.payment_transactions where staff_request_id=p_request_id;
  if found then
    if t.submitted_by <> auth.uid() or t.charge_id <> p_charge_id
      or t.amount is distinct from p_amount or t.received_on is distinct from p_received_on
      or t.reference_number is distinct from nullif(btrim(p_reference_number),'')
      or t.staff_method_code is distinct from p_method
      or t.review_notes is distinct from ('Staff received payment on ' || p_received_on::text ||
        coalesce(': ' || nullif(btrim(p_notes),''),'')) then
      raise exception 'Receipt request already used with different details';
    end if;
  else
    select * into c from public.billing_charges where id=p_charge_id for update;
    if not found then raise exception 'Bill not found'; end if;
    if c.category='deposit' then raise exception 'Record security deposits separately'; end if;
    if p_received_on is null or p_received_on > (now() at time zone 'Asia/Manila')::date then
      raise exception 'Payment date cannot be in the future';
    end if;
    select remaining_balance,status into v_balance,v_status
      from public.billing_charge_summaries where id=c.id;
    if v_status='voided' or v_balance <= 0 then raise exception 'Bill is voided or already paid'; end if;
    if exists(select 1 from public.payment_transactions where charge_id=c.id and status='pending_verification') then
      raise exception 'Review the pending payment proof before recording another receipt';
    end if;
    if p_amount is null or p_amount::text in ('NaN','Infinity','-Infinity')
      or p_amount <= 0 or p_amount > v_balance or p_amount <> round(p_amount,2) then
      raise exception 'Enter a positive amount within the outstanding balance, with at most two decimals';
    end if;
    select label into v_method from public.dormitory_options
      where group_key='payment_method' and is_active
      and (code=p_method or lower(btrim(label))=lower(btrim(p_method))) limit 1;
    if not found then raise exception 'Choose an active payment method'; end if;
    if p_receipt_path is null or p_receipt_path not like
      ('cloudinary://authenticated/' || auth.uid()::text || '/payment/' || c.id::text || '/%') then
      raise exception 'Attach a receipt photo uploaded for this bill';
    end if;
    insert into public.payment_transactions(
      charge_id,contract_id,tenant_id,amount,status,payment_method,
      reference_number,receipt_path,submitted_by,reviewed_by,reviewed_at,
      review_notes,staff_request_id,received_on,staff_method_code
    ) values(
      c.id,c.contract_id,c.tenant_id,p_amount,'verified',v_method,
      nullif(btrim(p_reference_number),''),p_receipt_path,auth.uid(),auth.uid(),now(),
      'Staff received payment on ' || p_received_on::text ||
        coalesce(': ' || nullif(btrim(p_notes),''),''),p_request_id,p_received_on,p_method
    ) returning * into t;
    v_new := true;
  end if;
  select to_jsonb(s) into v_summary from public.billing_charge_summaries s where id=t.charge_id;
  return jsonb_build_object('payment',v_summary,'receipt_path',t.receipt_path,'is_new',v_new);
end;
$$;
revoke all on function public.record_staff_payment(uuid,uuid,numeric,text,date,text,text,text) from public,anon;
grant execute on function public.record_staff_payment(uuid,uuid,numeric,text,date,text,text,text) to authenticated;
-- Existing submission and review paths share the bill lock so concurrent
-- staff receipts and tenant proof approvals cannot overpay a bill.
create or replace function public.submit_payment_transaction(
  p_charge_id uuid, p_method text, p_reference_number text,
  p_receipt_path text default null, p_amount numeric default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.billing_charges; v_balance numeric(12,2); v_amount numeric(12,2); v_row jsonb;
begin
  select * into c from public.billing_charges where id = p_charge_id for update;
  if not found then raise exception 'Bill not found'; end if;
  if c.tenant_id <> auth.uid() or public.current_user_role() <> 'tenant' then
    raise exception 'Tenant may submit only against their own charge';
  end if;
  if c.category = 'deposit' then raise exception 'Security deposits are recorded by management, not paid through Payments'; end if;
  select remaining_balance into v_balance
    from public.billing_charge_summaries where id = p_charge_id;
  if v_balance <= 0 then raise exception 'Billing charge is already paid'; end if;
  v_amount := coalesce(p_amount, v_balance);
  if v_amount <= 0 or v_amount > v_balance then
    raise exception 'Payment amount must be positive and cannot exceed the remaining balance';
  end if;
  if exists (select 1 from public.payment_transactions
             where charge_id = p_charge_id and status = 'pending_verification') then
    raise exception 'A payment submission is already awaiting verification';
  end if;
  insert into public.payment_transactions (
    charge_id, contract_id, tenant_id, amount, payment_method,
    reference_number, receipt_path, submitted_by
  ) values (
    c.id, c.contract_id, c.tenant_id, v_amount, p_method,
    nullif(trim(p_reference_number), ''), p_receipt_path, auth.uid()
  );
  select to_jsonb(s) into v_row from public.billing_charge_summaries s where s.id = c.id;
  return v_row;
end; $$;

create or replace function public.review_payment_transaction(
  p_charge_id uuid, p_approve boolean, p_review_notes text default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_transaction uuid; v_row jsonb;
begin
  if not public.is_staff() then raise exception 'Staff access required'; end if;
  perform 1 from public.billing_charges where id=p_charge_id for update;
  select id into v_transaction from public.payment_transactions
  where charge_id = p_charge_id and status = 'pending_verification'
  order by submitted_at desc limit 1 for update;
  if v_transaction is null then raise exception 'No pending transaction found'; end if;
  if p_approve and (select amount from public.payment_transactions where id=v_transaction) >
    (select remaining_balance from public.billing_charge_summaries where id=p_charge_id) then
    raise exception 'Payment exceeds the current outstanding balance';
  end if;
  update public.payment_transactions set
    status = case when p_approve then 'verified' else 'rejected' end,
    reviewed_by = auth.uid(), reviewed_at = now(),
    review_notes = nullif(trim(p_review_notes), '')
  where id = v_transaction;
  select to_jsonb(s) into v_row from public.billing_charge_summaries s where s.id = p_charge_id;
  return v_row;
end; $$;
commit;

begin;

insert into public.dormitory_options(group_key, code, label, is_system)
values ('payment_method', 'f2f', 'Face-to-face receipt', true)
on conflict (group_key, code) do nothing;

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
  p_method := 'f2f';
  p_reference_number := 'F2F-' || upper(p_request_id::text);
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
    v_method := 'Face-to-face receipt';
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

-- Contract creation is the source of rent and deposit amounts. Existing financial
-- history is preserved; changing prices requires a new contract.
create or replace function public.guard_contract_price_terms()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.monthly_rent is distinct from old.monthly_rent
     or new.security_deposit is distinct from old.security_deposit then
    raise exception 'Create a new contract to change rent or security deposit';
  end if;
  return new;
end;
$$;
create trigger guard_contract_price_terms before update of monthly_rent, security_deposit
on public.tenant_contracts for each row execute function public.guard_contract_price_terms();
revoke all on function public.guard_contract_price_terms() from public, anon, authenticated;

create or replace function public.apply_owner_rent_rate_override(
  p_tenant_id uuid, p_new_monthly_rent numeric, p_effective_date date, p_reason text
) returns jsonb language plpgsql set search_path = '' as $$
begin
  raise exception 'Create a new contract to change rent or security deposit';
end;
$$;
revoke all on function public.apply_owner_rent_rate_override(uuid,numeric,date,text)
  from public, anon, authenticated;
revoke all on function public.apply_rent_rate_override(uuid,numeric,date,text)
  from public, anon, authenticated;
commit;

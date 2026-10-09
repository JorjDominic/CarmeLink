-- Apply approved move-out deductions to bills exactly once, using audited
-- credits. Deposits remain receipts, rather than fabricated cash payments.
begin;
alter table public.move_out_deductions
  add column billing_charge_id uuid references public.billing_charges(id) on delete restrict,
  add column deposit_applied_amount numeric(12,2) not null default 0 check(deposit_applied_amount >= 0);
create unique index move_out_deduction_case_charge on public.move_out_deductions(case_id,billing_charge_id)
  where billing_charge_id is not null and status <> 'rejected';
alter table public.billing_charge_actions add column deposit_deduction_id uuid unique
  references public.move_out_deductions(id) on delete restrict;
alter table public.billing_charge_actions add constraint deposit_action_is_credit
  check(deposit_deduction_id is null or action_type='credit');

create or replace function public.propose_move_out_charge_deduction(
  p_case_id uuid,p_category text,p_label text,p_amount numeric,p_evidence_note text,
  p_charge_id uuid default null
) returns uuid language plpgsql security definer set search_path = '' as $$
declare c public.move_out_cases; b public.billing_charges; v_balance numeric; v_id uuid;
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then raise exception 'Staff access required'; end if;
  select * into c from public.move_out_cases where id=p_case_id for update;
  if not found then raise exception 'Move-out case not found'; end if;
  if c.status in ('cancelled','settlement_completed','ready_for_closure') or exists(
    select 1 from public.move_out_settlements where case_id=c.id and refund_status<>'pending') then
    raise exception 'Finalized settlement cannot receive deductions';
  end if;
  if p_category is null or p_category not in ('damage','cleaning','replacement','utility','other') then
    raise exception 'Invalid deduction category'; end if;
  if p_amount is null or p_amount::text in ('NaN','Infinity','-Infinity') or p_amount<=0
    or p_amount>9999999999.99 or p_amount<>round(p_amount,2) then raise exception 'Enter a positive amount with at most two decimals'; end if;
  if char_length(btrim(coalesce(p_label,''))) not between 2 and 160
    or char_length(btrim(coalesce(p_evidence_note,''))) not between 3 and 1500 then
    raise exception 'A label and documented evidence note are required'; end if;
  if p_charge_id is not null then
    select * into b from public.billing_charges where id=p_charge_id for update;
    if not found or b.tenant_id<>c.tenant_id or b.category<>p_category
      or (b.contract_id is not null and b.contract_id is distinct from c.contract_id) then
      raise exception 'Bill must match this tenant, contract and deduction category'; end if;
    select remaining_balance into v_balance from public.billing_charge_summaries where id=b.id;
    if v_balance<=0 or p_amount<>v_balance then raise exception 'Use the current outstanding bill amount'; end if;
    if exists(select 1 from public.move_out_deductions d join public.move_out_cases m on m.id=d.case_id
      where d.billing_charge_id=b.id and d.status<>'rejected' and m.status<>'cancelled') then
      raise exception 'This bill already has a deposit deduction'; end if;
  end if;
  insert into public.move_out_deductions(case_id,category,label,amount,evidence_note,created_by,billing_charge_id)
  values(c.id,p_category,btrim(p_label),p_amount,btrim(p_evidence_note),auth.uid(),p_charge_id) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.propose_move_out_charge_deduction(uuid,text,text,numeric,text,uuid) from public,anon;
grant execute on function public.propose_move_out_charge_deduction(uuid,text,text,numeric,text,uuid) to authenticated;

create or replace function public.list_move_out_deductible_charges(p_case_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.move_out_cases; v_result jsonb;
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then raise exception 'Staff access required'; end if;
  select * into c from public.move_out_cases where id=p_case_id;
  if not found then raise exception 'Move-out case not found'; end if;
  select coalesce(jsonb_agg(to_jsonb(b) order by b.created_at,b.id),'[]'::jsonb) into v_result
  from public.billing_charge_summaries b where b.tenant_id=c.tenant_id
    and b.category in ('damage','cleaning','replacement','utility','other')
    and b.remaining_balance>0 and (b.contract_id is null or b.contract_id=c.contract_id)
    and not exists(select 1 from public.move_out_deductions d join public.move_out_cases m on m.id=d.case_id
      where d.billing_charge_id=b.id and d.status<>'rejected' and m.status<>'cancelled');
  return v_result;
end;
$$;
revoke all on function public.list_move_out_deductible_charges(uuid) from public,anon;
grant execute on function public.list_move_out_deductible_charges(uuid) to authenticated;

create or replace function public.refresh_move_out_settlement(p_case_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_deposit numeric; v_deductions numeric; v_status text;
begin
  select deposit_received_amount,refund_status into v_deposit,v_status
    from public.move_out_settlements where case_id=p_case_id for update;
  if not found then raise exception 'Move-out settlement not found'; end if;
  if v_status<>'pending' then raise exception 'Finalized settlement cannot be recalculated'; end if;
  select coalesce(sum(case when d.billing_charge_id is null then d.amount
    else least(d.amount,coalesce(b.remaining_balance,0)) end),0) into v_deductions
  from public.move_out_deductions d left join public.billing_charge_summaries b on b.id=d.billing_charge_id
  where d.case_id=p_case_id and d.status='approved';
  update public.move_out_settlements set approved_deductions=v_deductions,
    refundable_amount=greatest(v_deposit-v_deductions,0),shortfall_amount=greatest(v_deductions-v_deposit,0),
    updated_by=auth.uid() where case_id=p_case_id;
end;
$$;

create or replace function public.get_move_out_charge_preview(p_case_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.move_out_cases; s public.move_out_settlements; v_total numeric; v_ordinary numeric; v_rows jsonb;
begin
  select * into c from public.move_out_cases where id=p_case_id;
  if not found then raise exception 'Move-out case not found'; end if;
  if auth.uid() is null or not(coalesce(public.is_staff(),false) or c.tenant_id=auth.uid()) then
    raise exception 'Move-out access denied'; end if;
  select * into s from public.move_out_settlements where case_id=c.id;
  select coalesce(sum(case when d.billing_charge_id is null then d.amount
    else least(d.amount,coalesce(b.remaining_balance,0)) end),0) into v_total
  from public.move_out_deductions d left join public.billing_charge_summaries b on b.id=d.billing_charge_id
  where d.case_id=c.id and d.status='approved';
  select coalesce(jsonb_agg(to_jsonb(d)||jsonb_build_object('outstanding_amount',
    case when d.billing_charge_id is null then d.amount else coalesce(b.remaining_balance,0) end,
    'billing_title',b.title) order by d.created_at,d.id),'[]'::jsonb) into v_rows
  from public.move_out_deductions d left join public.billing_charge_summaries b on b.id=d.billing_charge_id where d.case_id=c.id;
  select coalesce(sum(b.remaining_balance),0) into v_ordinary from public.billing_charge_summaries b
  where b.tenant_id=c.tenant_id and b.category<>'deposit' and b.status not in ('verified','voided','upcoming')
    and (s.refund_status<>'pending' or not exists(select 1 from public.move_out_deductions d
      where d.case_id=c.id and d.status='approved' and d.billing_charge_id=b.id));
  if s.refund_status='pending' then
    s.approved_deductions:=v_total; s.refundable_amount:=greatest(s.deposit_received_amount-v_total,0);
    s.shortfall_amount:=greatest(v_total-s.deposit_received_amount,0);
  end if;
  return jsonb_build_object('deductions',v_rows,'settlement',to_jsonb(s),'ordinary_balance',v_ordinary);
end;
$$;
revoke all on function public.get_move_out_charge_preview(uuid) from public,anon;
grant execute on function public.get_move_out_charge_preview(uuid) to authenticated;

create or replace function public.apply_move_out_deposit_to_charges(p_case_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare c public.move_out_cases; s public.move_out_settlements; d public.move_out_deductions;
  v_available numeric; v_credit numeric; v_balance numeric; v_bill uuid;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then raise exception 'Owner access required'; end if;
  select * into c from public.move_out_cases where id=p_case_id for update;
  select * into s from public.move_out_settlements where case_id=p_case_id for update;
  if s.refund_status<>'pending' then raise exception 'Settlement already finalized'; end if;
  v_available:=s.deposit_received_amount;
  for d in select * from public.move_out_deductions where case_id=c.id and status='approved' order by created_at,id for update loop
    v_bill:=d.billing_charge_id;
    if v_bill is null then
      insert into public.billing_charges(contract_id,tenant_id,title,category,original_amount,due_date,source,terms_snapshot,notes,created_by)
      values(c.contract_id,c.tenant_id,left(d.label,150),d.category,d.amount,
        (now() at time zone 'Asia/Manila')::date,'staff_entry',
        jsonb_build_object('move_out_deduction_id',d.id,'approved_by',d.reviewed_by,'approved_at',d.reviewed_at),d.evidence_note,auth.uid())
      returning id into v_bill;
      update public.move_out_deductions set billing_charge_id=v_bill where id=d.id;
    end if;
    perform 1 from public.billing_charges where id=v_bill for update;
    if exists(select 1 from public.payment_transactions where charge_id=v_bill and status='pending_verification')
      or exists(select 1 from public.paymongo_payment_sessions where charge_id=v_bill
        and status in ('creating','pending','needs_review')) then
      raise exception 'Review pending payments or payment sessions before applying the deposit'; end if;
    select remaining_balance into v_balance from public.billing_charge_summaries where id=v_bill;
    if v_balance>d.amount then raise exception 'Bill balance increased after approval; review the bill before settlement'; end if;
    v_credit:=least(v_available,v_balance);
    if v_credit>0 then
      insert into public.billing_charge_actions(charge_id,action_type,amount_delta,reason,created_by,deposit_deduction_id)
      values(v_bill,'credit',-v_credit,'Security deposit applied at move-out settlement '||c.id::text,auth.uid(),d.id);
    end if;
    update public.move_out_deductions set deposit_applied_amount=v_credit where id=d.id;
    v_available:=v_available-v_credit;
  end loop;
end;
$$;
revoke all on function public.apply_move_out_deposit_to_charges(uuid) from public,anon,authenticated;

-- Receipt deductions reflect money actually consumed from the held deposit,
-- rather than including the separate tenant-payable shortfall.
create or replace function public.sync_finalized_deposit_receipt()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.refund_status in ('refunded','settled_zero','shortfall_pending') then
    update public.security_deposit_receipts r set
      refunded_amount=case when new.refund_status='refunded' then new.refundable_amount else 0 end,
      approved_deductions=least(new.approved_deductions,new.deposit_received_amount),
      settled_at=coalesce(new.refunded_at,now()),updated_at=now()
    from public.move_out_cases m where m.id=new.case_id and r.contract_id=m.contract_id;
  end if;
  return new;
end;
$$;

create or replace function public.record_move_out_settlement_with_charges(
  p_case_id uuid,p_expected_refund numeric,p_expected_deductions numeric,
  p_refund_method text default null,p_refund_reference text default null,
  p_refund_proof_path text default null,p_shortfall_note text default null
) returns void language plpgsql security definer set search_path = '' as $$
declare s public.move_out_settlements;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then raise exception 'Owner access required'; end if;
  perform 1 from public.move_out_cases where id=p_case_id for update;
  perform 1 from public.billing_charges where id in(
    select billing_charge_id from public.move_out_deductions where case_id=p_case_id and status='approved') order by id for update;
  perform public.refresh_move_out_settlement(p_case_id);
  select * into s from public.move_out_settlements where case_id=p_case_id;
  if p_expected_refund is distinct from s.refundable_amount or p_expected_deductions is distinct from s.approved_deductions then
    raise exception 'Balances changed. Refresh and review the settlement before confirming'; end if;
  perform public.record_move_out_settlement_outcome(p_case_id,p_refund_method,p_refund_reference,p_refund_proof_path,p_shortfall_note);
end;
$$;
revoke all on function public.record_move_out_settlement_with_charges(uuid,numeric,numeric,text,text,text,text) from public,anon;
grant execute on function public.record_move_out_settlement_with_charges(uuid,numeric,numeric,text,text,text,text) to authenticated;

-- Billing view and existing finalization function are extended below.

create or replace view public.billing_charge_summaries
with (security_invoker = true) as
select
  c.id, c.contract_id, c.tenant_id, c.title, c.category,
  (c.original_amount + coalesce(r.adjustment_total, 0) + coalesce(a.amount_delta, 0))::numeric(12,2) as amount,
  coalesce(a.effective_due_date, c.due_date) as due_date,
  c.period_start, c.period_end, c.source, c.terms_snapshot,
  c.created_at, coalesce(a.last_action_at, c.created_at) as updated_at,
  case when a.is_voided then 0 else greatest(c.original_amount + coalesce(r.adjustment_total, 0)
    + coalesce(a.amount_delta, 0) - coalesce(v.verified_total, 0), 0) end::numeric(12,2) as remaining_balance,
  case
    when a.is_voided then 'voided'
    when coalesce(v.verified_total, 0) >= c.original_amount + coalesce(r.adjustment_total, 0) + coalesce(a.amount_delta, 0) then 'verified'
    when coalesce(v.verified_total, 0) > 0 then 'partially_paid'
    when latest.status = 'pending_verification' then 'pending_verification'
    when latest.status = 'rejected' then 'rejected'
    when coalesce(a.effective_due_date, c.due_date) > current_date then 'upcoming'
    else 'due'
  end as status,
  latest.id as latest_transaction_id, latest.payment_method, latest.reference_number,
  latest.receipt_path, latest.submitted_at as paid_at, latest.reviewed_by,
  latest.reviewed_at, latest.review_notes, profile.full_name as tenant_name,
  latest.amount as submitted_amount, c.notes, c.created_by,
  c.original_amount as contract_amount,
  coalesce(r.adjustment_total, 0)::numeric(12,2) as rent_adjustment,
  coalesce(a.deposit_applied_amount,0)::numeric(12,2) as deposit_applied_amount
from public.billing_charges c
join public.profiles profile on profile.id = c.tenant_id
left join lateral (select coalesce(sum(t.amount),0) verified_total from public.payment_transactions t
  where t.charge_id=c.id and t.status='verified') v on true
left join lateral (select coalesce(sum(x.amount_delta),0) adjustment_total from public.rent_charge_adjustments x
  where x.charge_id=c.id) r on true
left join lateral (
  select coalesce(sum(x.amount_delta),0) amount_delta,
    coalesce(sum(-x.amount_delta) filter(where x.deposit_deduction_id is not null),0) deposit_applied_amount,
    max(x.new_due_date) filter (where x.action_type='due_date_extension') effective_due_date,
    bool_or(x.action_type='void') is_voided, max(x.created_at) last_action_at
  from public.billing_charge_actions x where x.charge_id=c.id
) a on true
left join lateral (select t.* from public.payment_transactions t
  where t.charge_id=c.id and t.status <> 'reversed'
  order by t.submitted_at desc, t.created_at desc limit 1) latest on true;


create or replace function public.record_move_out_settlement_outcome(
  p_case_id uuid,p_refund_method text default null,p_refund_reference text default null,
  p_refund_proof_path text default null,p_shortfall_note text default null
) returns void language plpgsql security definer set search_path = '' as $$
declare
  v_case public.move_out_cases;
  v_settlement public.move_out_settlements;
  v_inspection_status text;
  v_outstanding numeric(12,2);
begin
  if public.current_user_role() is distinct from 'owner'::public.app_role then raise exception 'Owner access required'; end if;
  select * into v_case from public.move_out_cases where id=p_case_id for update;
  if not found then raise exception 'Move-out case not found'; end if;
  if v_case.status in ('cancelled','settlement_completed','ready_for_closure') then
    raise exception 'This move-out case no longer accepts settlement changes';
  end if;
  if v_case.final_inspection_id is null then raise exception 'Final move-out inspection is required before settlement'; end if;
  select status into v_inspection_status from public.room_inspections where id=v_case.final_inspection_id;
  if v_inspection_status<>'completed' then raise exception 'Final move-out inspection must be completed before settlement'; end if;
  if exists(select 1 from public.move_out_clearance_items where case_id=p_case_id and status not in ('cleared','not_applicable')) then
    raise exception 'Every required clearance item must be resolved before settlement';
  end if;
  if exists(select 1 from public.move_out_deductions where case_id=p_case_id and status='proposed') then
    raise exception 'Every proposed deduction must be reviewed before settlement';
  end if;
  select coalesce(sum(remaining_balance),0) into v_outstanding
  from public.billing_charge_summaries
  where tenant_id=v_case.tenant_id and category<>'deposit' and status not in ('verified','voided','upcoming')
    and not exists(select 1 from public.move_out_deductions d where d.case_id=p_case_id
      and d.status='approved' and d.billing_charge_id=billing_charge_summaries.id);
  if v_outstanding>0 then raise exception 'Outstanding tenant-payable charges must be cleared before settlement'; end if;

  perform 1 from public.billing_charges where id in(select billing_charge_id from public.move_out_deductions
    where case_id=p_case_id and status='approved') order by id for update;
  perform public.refresh_move_out_settlement(p_case_id);
  select * into v_settlement from public.move_out_settlements where case_id=p_case_id for update;
  perform public.apply_move_out_deposit_to_charges(p_case_id);
  if v_settlement.refundable_amount>0 then
    if trim(coalesce(p_refund_method,''))='' or trim(coalesce(p_refund_reference,''))='' or trim(coalesce(p_refund_proof_path,''))='' then
      raise exception 'Refund method, reference, and proof are required';
    end if;
    if split_part(p_refund_proof_path,'/',1)<>p_case_id::text
       or not exists(
         select 1 from storage.objects
         where bucket_id='move_out_refund_proofs' and name=p_refund_proof_path
       ) then
      raise exception 'Refund proof must belong to this move-out case';
    end if;
    update public.move_out_settlements set refund_status='refunded',refund_method=trim(p_refund_method),
      refund_reference=trim(p_refund_reference),refund_proof_path=p_refund_proof_path,refunded_at=now(),
      shortfall_note='',updated_by=auth.uid() where case_id=p_case_id;
  elsif v_settlement.shortfall_amount>0 then
    if char_length(trim(coalesce(p_shortfall_note,'')))<3 then raise exception 'Shortfall handoff note is required'; end if;
    update public.move_out_settlements set refund_status='shortfall_pending',shortfall_note=trim(p_shortfall_note),
      refund_method=null,refund_reference=null,refund_proof_path=null,refunded_at=null,updated_by=auth.uid()
    where case_id=p_case_id;
  else
    update public.move_out_settlements set refund_status='settled_zero',shortfall_note='',updated_by=auth.uid()
    where case_id=p_case_id;
  end if;
  update public.move_out_cases set status='settlement_completed' where id=p_case_id;
end $$;

notify pgrst, 'reload schema';
commit;

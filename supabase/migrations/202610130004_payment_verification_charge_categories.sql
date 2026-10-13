-- Read-only summary metadata and guarded existing financial RPCs. No historical amounts or allocations are modified.
begin;
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
    when latest.status = 'pending_verification' then 'pending_verification'
    when coalesce(v.verified_total, 0) > 0 then 'partially_paid'
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
  coalesce(a.deposit_applied_amount,0)::numeric(12,2) as deposit_applied_amount,
  coalesce(v.verified_total,0)::numeric(12,2) as verified_amount,
  c.terms_snapshot->>'specific_category' as specific_category,
  latest.status as latest_transaction_status
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

create or replace function public.review_payment_transaction(
  p_charge_id uuid, p_approve boolean, p_review_notes text default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_transaction uuid; v_row jsonb;
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then raise exception 'Staff access required'; end if;
  if p_approve is null then raise exception 'An approval decision is required'; end if;
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

create function public.create_additional_charge(
  p_tenant_id uuid,p_title text,p_category text,p_amount numeric,p_due_date date,
  p_notes text,p_reason text,p_specific_category text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_category text:=lower(trim(p_category)); v_specific text:=nullif(btrim(p_specific_category),'');
  v_charge_id uuid; v_row jsonb;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then raise exception 'Owner access required'; end if;
  if v_category is null or v_category not in ('damage','fine','late_fee','cleaning','replacement','other') then raise exception 'Unsupported additional-charge category'; end if;
  if v_category='other' and char_length(coalesce(v_specific,'')) not between 2 and 120 then raise exception 'Specify Category must contain 2 to 120 characters'; end if;
  if v_category<>'other' and v_specific is not null then raise exception 'Specify Category only applies to Other'; end if;
  if p_amount is null or p_amount::text in ('NaN','Infinity','-Infinity') or p_amount<=0 or p_amount>9999999999.99 or p_amount<>round(p_amount,2) then raise exception 'Enter a positive amount with at most two decimal places'; end if;
  if p_due_date is null then raise exception 'A due date is required'; end if;
  if char_length(trim(coalesce(p_title,''))) not between 2 and 150 then raise exception 'Title must contain 2 to 150 characters'; end if;
  if char_length(trim(coalesce(p_reason,''))) not between 3 and 500 then raise exception 'An approval reason between 3 and 500 characters is required'; end if;
  if not exists(select 1 from public.profiles where id=p_tenant_id and role::text='tenant') then raise exception 'A valid tenant is required'; end if;
  insert into public.billing_charges(tenant_id,title,category,original_amount,due_date,source,terms_snapshot,notes,created_by)
    values(p_tenant_id,trim(p_title),v_category,p_amount,p_due_date,'staff_entry',
      jsonb_strip_nulls(jsonb_build_object('manual_approval_reason',trim(p_reason),
        'approved_by',auth.uid(),'approved_at',now(),'specific_category',v_specific)),
      nullif(trim(coalesce(p_notes,'')),''),auth.uid()) returning id into v_charge_id;
  select to_jsonb(s) into v_row from public.billing_charge_summaries s where s.id=v_charge_id;
  return v_row;
end $$;
-- Retain the existing seven-parameter API; fixed categories still work.
-- Legacy Other requests cannot bypass the now-required specification.
create or replace function public.create_additional_charge(
  p_tenant_id uuid,p_title text,p_category text,p_amount numeric,p_due_date date,p_notes text,p_reason text
) returns jsonb language sql security definer set search_path='' as $$
  select public.create_additional_charge(p_tenant_id,p_title,p_category,p_amount,p_due_date,p_notes,p_reason,null);
$$;
revoke all on function public.create_additional_charge(uuid,text,text,numeric,date,text,text,text),
  public.create_additional_charge(uuid,text,text,numeric,date,text,text) from public,anon;
grant execute on function public.create_additional_charge(uuid,text,text,numeric,date,text,text,text),
  public.create_additional_charge(uuid,text,text,numeric,date,text,text) to authenticated;

-- Bind a review to the proof shown to staff. Preserve the legacy review API.
create function public.review_payment_transaction(
  p_charge_id uuid,p_approve boolean,p_review_notes text,p_expected_transaction_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_transaction uuid;
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then raise exception 'Staff access required'; end if;
  perform 1 from public.billing_charges where id=p_charge_id for update;
  select id into v_transaction from public.payment_transactions where charge_id=p_charge_id and status='pending_verification'
    order by submitted_at desc limit 1 for update;
  if p_expected_transaction_id is null or v_transaction is distinct from p_expected_transaction_id then
    raise exception 'Payment submission changed. Refresh and review the current proof.';
  end if;
  return public.review_payment_transaction(p_charge_id,p_approve,p_review_notes);
end $$;
revoke all on function public.review_payment_transaction(uuid,boolean,text),
  public.review_payment_transaction(uuid,boolean,text,uuid) from public,anon;
grant execute on function public.review_payment_transaction(uuid,boolean,text),
  public.review_payment_transaction(uuid,boolean,text,uuid) to authenticated;

notify pgrst,'reload schema';
commit;

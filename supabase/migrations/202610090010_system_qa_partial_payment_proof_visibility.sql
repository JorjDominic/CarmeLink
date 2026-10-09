-- A pending proof must remain reviewable after an earlier partial payment.
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
  coalesce(v.verified_total,0)::numeric(12,2) as verified_amount
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
notify pgrst,'reload schema';
commit;

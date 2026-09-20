-- Expose the exact submitted transaction amount separately from the charge total.
create or replace view public.billing_charge_summaries
with (security_invoker = true) as
select
  c.id, c.contract_id, c.tenant_id, c.title, c.category,
  c.original_amount as amount, c.due_date, c.period_start, c.period_end,
  c.source, c.terms_snapshot, c.created_at, c.created_at as updated_at,
  greatest(c.original_amount - coalesce(v.verified_total, 0), 0)::numeric(12,2)
    as remaining_balance,
  case
    when coalesce(v.verified_total, 0) >= c.original_amount then 'verified'
    when coalesce(v.verified_total, 0) > 0 then 'partially_paid'
    when latest.status = 'pending_verification' then 'pending_verification'
    when latest.status = 'rejected' then 'rejected'
    else 'due'
  end as status,
  latest.id as latest_transaction_id,
  latest.payment_method, latest.reference_number, latest.receipt_path,
  latest.submitted_at as paid_at, latest.reviewed_by, latest.reviewed_at,
  latest.review_notes,
  profile.full_name as tenant_name,
  latest.amount as submitted_amount
from public.billing_charges c
join public.profiles profile on profile.id = c.tenant_id
left join lateral (
  select coalesce(sum(t.amount), 0) as verified_total
  from public.payment_transactions t
  where t.charge_id = c.id and t.status = 'verified'
) v on true
left join lateral (
  select t.* from public.payment_transactions t
  where t.charge_id = c.id and t.status <> 'reversed'
  order by t.submitted_at desc, t.created_at desc limit 1
) latest on true;

grant select on public.billing_charge_summaries to authenticated;
revoke all on public.billing_charge_summaries from anon;

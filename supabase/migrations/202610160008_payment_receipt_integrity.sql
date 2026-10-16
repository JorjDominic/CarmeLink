-- Review/deploy separately. Preserve all existing payments, snapshots and numbering.
begin;
alter table public.payment_transactions add column receipt_context jsonb;
alter table public.payment_receipts add column snapshot_source text not null default 'legacy'
  check(snapshot_source in ('legacy','verification','recovery'));

-- Capture display facts alongside verification, before a recoverable receipt-table
-- failure can lose the original name/title/balance. Never backfill historical facts.
create function public.capture_payment_receipt_context() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if tg_op='UPDATE' and old.receipt_context is distinct from new.receipt_context then
    raise exception 'Payment receipt context is immutable'; end if;
  if new.status<>'verified' or (tg_op='UPDATE' and (old.status in ('verified','reversed') or old.receipt_context is not null)) then
    if tg_op='INSERT' then new.receipt_context:=null; end if;
    return new;
  end if;
  new.receipt_context:=null;
  begin
    select jsonb_build_object(
      'tenant_name',coalesce(nullif(btrim(p.full_name),''),new.tenant_id::text),
      'bill_title',c.title,'balance_after',greatest(b.remaining_balance-new.amount,0),
      'verified_at',coalesce(new.reviewed_at,new.submitted_at),
      'received_at',coalesce(new.received_on::timestamptz,new.submitted_at),
      'reference_number',coalesce(nullif(btrim(new.reference_number),''),new.id::text),
      'payment_method',coalesce(new.payment_method,'Manual payment'),
      'environment',coalesce(s.environment,'manual'),
      'captured_at',clock_timestamp()) into new.receipt_context
    from public.billing_charges c join public.profiles p on p.id=c.tenant_id
      join public.billing_charge_summaries b on b.id=c.id
      left join public.paymongo_payment_sessions s on s.id=new.gateway_session_id where c.id=new.charge_id;
  exception when others then
    -- Receipt availability must not reverse legitimate financial verification.
    new.receipt_context:=null;
  end;
  return new;
end $$;
revoke all on function public.capture_payment_receipt_context() from public,anon,authenticated,service_role;
-- Existing gateway guard serializes allocations on the bill before this trigger.
create trigger zz_capture_payment_receipt_context before insert or update on public.payment_transactions
  for each row execute function public.capture_payment_receipt_context();

create or replace function public.create_payment_receipt_snapshot(p_transaction_id uuid)
returns public.payment_receipts language plpgsql security definer set search_path='' as $$
declare r public.payment_receipts;
begin
  select * into r from public.payment_receipts where id=p_transaction_id;
  if found then return r; end if;
  insert into public.payment_receipts(id,receipt_number,tenant_id,charge_id,tenant_name,bill_title,
    amount,reference_number,payment_method,verified_at,received_at,environment,balance_after,snapshot_source)
  select t.id,'PAY-'||upper(t.id::text),t.tenant_id,t.charge_id,
    coalesce(t.receipt_context->>'tenant_name',nullif(btrim(p.full_name),''),t.tenant_id::text),
    coalesce(t.receipt_context->>'bill_title',c.title),t.amount,
    coalesce(t.receipt_context->>'reference_number',nullif(btrim(t.reference_number),''),t.id::text),
    coalesce(t.receipt_context->>'payment_method',t.payment_method,'Manual payment'),
    coalesce((t.receipt_context->>'verified_at')::timestamptz,t.reviewed_at,t.submitted_at),
    coalesce((t.receipt_context->>'received_at')::timestamptz,t.received_on::timestamptz,t.submitted_at),
    coalesce(t.receipt_context->>'environment',s.environment,'manual'),
    greatest(coalesce((t.receipt_context->>'balance_after')::numeric,b.remaining_balance,0),0),
    case when t.receipt_context is not null then 'verification' else 'recovery' end
  from public.payment_transactions t join public.billing_charges c on c.id=t.charge_id
    join public.profiles p on p.id=t.tenant_id join public.billing_charge_summaries b on b.id=t.charge_id
    left join public.paymongo_payment_sessions s on s.id=t.gateway_session_id
  where t.id=p_transaction_id and t.status='verified' on conflict(id) do nothing;
  select * into r from public.payment_receipts where id=p_transaction_id;
  if not found then raise exception 'A verified payment is required for a receipt'; end if;
  return r;
end $$;

create function public.protect_payment_receipt_snapshot() returns trigger
language plpgsql set search_path='' as $$
begin raise exception 'Payment receipt snapshots are immutable'; end $$;
revoke all on function public.protect_payment_receipt_snapshot() from public,anon,authenticated,service_role;
create trigger payment_receipt_snapshot_immutable before update or delete on public.payment_receipts
  for each row execute function public.protect_payment_receipt_snapshot();
-- Classify existing ledger credits under the same staff/tenant/linked-guardian
-- scope as the billing summary. Guardian session rows themselves remain private.
create function public.billing_test_verified_amount(p_charge_id uuid) returns numeric
language sql stable security definer set search_path='' as $$
  select coalesce(sum(t.amount),0) from public.payment_transactions t
  join public.paymongo_payment_sessions s on s.id=t.gateway_session_id
  join public.billing_charges c on c.id=t.charge_id
  where c.id=p_charge_id and t.status='verified' and s.environment='test'
    and (coalesce(auth.role(),'')='service_role' or (auth.uid() is not null and
      (coalesce(public.is_staff(),false) or
      (public.current_user_role()::text='tenant' and c.tenant_id=auth.uid()) or
      (public.current_user_role()::text='guardian' and exists(select 1 from public.guardian_tenant_links g
        where g.guardian_id=auth.uid() and g.tenant_id=c.tenant_id)))));
$$;
revoke all on function public.billing_test_verified_amount(uuid) from public,anon;
grant execute on function public.billing_test_verified_amount(uuid) to authenticated,service_role;

-- Keep bill balances and all allocations unchanged. Expose test cash separately
-- so reporting can exclude simulations without changing sandbox bill settlement.
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
  latest.status as latest_transaction_status,
  public.billing_test_verified_amount(c.id)::numeric(12,2) as test_verified_amount,
  latest.gateway_session_id as latest_gateway_session_id
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

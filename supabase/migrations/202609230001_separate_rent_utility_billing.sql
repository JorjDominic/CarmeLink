-- Step 1: keep rent contract-derived and create variable utility charges
-- through a dedicated, audited staff operation with independent due dates.

alter table public.billing_charges
  drop constraint if exists billing_charges_category_check;

alter table public.billing_charges
  add constraint billing_charges_category_check check (
    category in (
      'rent', 'electricity', 'water', 'internet', 'utility',
      'deposit', 'penalty', 'discount', 'other'
    )
  );

alter table public.billing_charges
  drop constraint if exists billing_charges_source_check;

alter table public.billing_charges
  add constraint billing_charges_source_check check (
    source in ('contract', 'staff_entry', 'manual', 'migration')
  );

alter table public.billing_charges
  add column if not exists notes text;

-- Charges are now created only through narrowly scoped functions. Contract
-- activation creates rent/deposit; create_utility_charge creates utilities.
revoke insert, update, delete on public.billing_charges from authenticated;
grant select on public.billing_charges to authenticated;

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
    when c.due_date > current_date then 'upcoming'
    else 'due'
  end as status,
  latest.id as latest_transaction_id,
  latest.payment_method, latest.reference_number, latest.receipt_path,
  latest.submitted_at as paid_at, latest.reviewed_by, latest.reviewed_at,
  latest.review_notes,
  profile.full_name as tenant_name,
  latest.amount as submitted_amount,
  c.notes, c.created_by
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

create or replace function public.create_utility_charge(
  p_tenant_id uuid,
  p_title text,
  p_category text,
  p_amount numeric,
  p_due_date date,
  p_period_start date,
  p_period_end date,
  p_notes text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_category text := lower(trim(p_category));
  v_charge_id uuid;
  v_row jsonb;
begin
  if not public.is_staff() then
    raise exception 'Owner or caretaker access required';
  end if;
  if v_category not in ('electricity', 'water', 'internet', 'utility') then
    raise exception 'Only utility charges can be created through this workflow';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Utility amount must be greater than zero';
  end if;
  if char_length(trim(p_title)) not between 2 and 150 then
    raise exception 'Utility title must contain 2 to 150 characters';
  end if;
  if p_period_start is null or p_period_end is null
     or p_period_end < p_period_start then
    raise exception 'A valid utility billing period is required';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = p_tenant_id and role = 'tenant'
  ) then
    raise exception 'A valid tenant is required';
  end if;

  insert into public.billing_charges (
    tenant_id, title, category, original_amount, due_date,
    period_start, period_end, source, terms_snapshot, notes, created_by
  ) values (
    p_tenant_id, trim(p_title), v_category, p_amount, p_due_date,
    p_period_start, p_period_end, 'staff_entry',
    jsonb_build_object(
      'entered_amount', p_amount,
      'entered_due_date', p_due_date,
      'entered_by', auth.uid(),
      'entered_at', now()
    ),
    nullif(trim(p_notes), ''), auth.uid()
  ) returning id into v_charge_id;

  select to_jsonb(s) into v_row
  from public.billing_charge_summaries s
  where s.id = v_charge_id;
  return v_row;
end;
$$;

revoke all on function public.create_utility_charge(
  uuid, text, text, numeric, date, date, date, text
) from public, anon;
grant execute on function public.create_utility_charge(
  uuid, text, text, numeric, date, date, date, text
) to authenticated;

comment on function public.create_utility_charge(
  uuid, text, text, numeric, date, date, date, text
) is 'Creates an immutable variable utility charge; it cannot create rent.';

create or replace function public.protect_financial_ledger_facts()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_table_name = 'billing_charges' then
    if tg_op = 'DELETE' then
      raise exception 'Issued billing charges are immutable; create a correction entry';
    end if;
    if tg_op = 'UPDATE' and (
      old.contract_id is distinct from new.contract_id
      or old.tenant_id is distinct from new.tenant_id
      or old.title is distinct from new.title
      or old.category is distinct from new.category
      or old.original_amount is distinct from new.original_amount
      or old.due_date is distinct from new.due_date
      or old.period_start is distinct from new.period_start
      or old.period_end is distinct from new.period_end
      or old.source is distinct from new.source
      or old.terms_snapshot is distinct from new.terms_snapshot
      or old.notes is distinct from new.notes
      or old.created_by is distinct from new.created_by
      or old.created_at is distinct from new.created_at
    ) then
      raise exception 'Billing charge facts are immutable; create a correction entry';
    end if;
  elsif tg_table_name = 'payment_transactions' and tg_op = 'UPDATE' and (
    old.charge_id is distinct from new.charge_id
    or old.contract_id is distinct from new.contract_id
    or old.tenant_id is distinct from new.tenant_id
    or old.amount is distinct from new.amount
    or old.payment_method is distinct from new.payment_method
    or old.reference_number is distinct from new.reference_number
    or old.receipt_path is distinct from new.receipt_path
    or old.submitted_by is distinct from new.submitted_by
    or old.submitted_at is distinct from new.submitted_at
    or old.created_at is distinct from new.created_at
  ) then
    raise exception 'Payment amount and submission facts are immutable';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

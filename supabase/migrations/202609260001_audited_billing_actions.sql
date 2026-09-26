-- Audited staff billing operations. Conduct cases and inspection records are
-- deliberately not referenced: an additional charge is always issued manually.

alter table public.billing_charges
  drop constraint if exists billing_charges_category_check;
alter table public.billing_charges
  add constraint billing_charges_category_check check (category in (
    'rent', 'electricity', 'water', 'internet', 'utility', 'deposit',
    'damage', 'fine', 'late_fee', 'cleaning', 'replacement',
    'penalty', 'discount', 'other'
  ));

create table public.billing_charge_actions (
  id uuid primary key default gen_random_uuid(),
  charge_id uuid not null references public.billing_charges(id) on delete restrict,
  action_type text not null check (action_type in (
    'void', 'due_date_extension', 'credit', 'debit'
  )),
  amount_delta numeric(12,2),
  new_due_date date,
  reason text not null check (char_length(trim(reason)) between 3 and 500),
  created_by uuid not null references public.profiles(id) on delete restrict default auth.uid(),
  created_at timestamptz not null default now(),
  check (
    (action_type = 'void' and amount_delta is null and new_due_date is null)
    or (action_type = 'due_date_extension' and amount_delta is null and new_due_date is not null)
    or (action_type = 'credit' and amount_delta < 0 and new_due_date is null)
    or (action_type = 'debit' and amount_delta > 0 and new_due_date is null)
  )
);

create unique index billing_charge_one_void_idx
  on public.billing_charge_actions(charge_id) where action_type = 'void';
create index billing_charge_actions_charge_idx
  on public.billing_charge_actions(charge_id, created_at desc);

alter table public.billing_charge_actions enable row level security;
create policy billing_charge_actions_staff_select on public.billing_charge_actions
for select to authenticated using ((select public.is_staff()));
create policy billing_charge_actions_visible_charge_select on public.billing_charge_actions
for select to authenticated using (exists (
  select 1 from public.billing_charges charge
  where charge.id = billing_charge_actions.charge_id
    and (charge.tenant_id = (select auth.uid()) or exists (
      select 1 from public.guardian_tenant_links link
      where link.guardian_id = (select auth.uid())
        and link.tenant_id = charge.tenant_id
    ))
));
grant select on public.billing_charge_actions to authenticated;
revoke insert, update, delete on public.billing_charge_actions from authenticated;
revoke all on public.billing_charge_actions from anon;

create or replace function public.create_additional_charge(
  p_tenant_id uuid,
  p_title text,
  p_category text,
  p_amount numeric,
  p_due_date date,
  p_notes text,
  p_reason text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_category text := lower(trim(p_category));
  v_charge_id uuid;
  v_row jsonb;
begin
  if public.current_user_role() <> 'owner' then raise exception 'Owner access required'; end if;
  if v_category not in ('damage', 'fine', 'late_fee', 'cleaning', 'replacement', 'other') then
    raise exception 'Unsupported additional-charge category';
  end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Amount must be greater than zero'; end if;
  if p_due_date is null then raise exception 'A due date is required'; end if;
  if char_length(trim(coalesce(p_title, ''))) not between 2 and 150 then
    raise exception 'Title must contain 2 to 150 characters';
  end if;
  if char_length(trim(coalesce(p_reason, ''))) not between 3 and 500 then
    raise exception 'An approval reason between 3 and 500 characters is required';
  end if;
  if not exists (select 1 from public.profiles where id = p_tenant_id and role = 'tenant') then
    raise exception 'A valid tenant is required';
  end if;

  insert into public.billing_charges (
    tenant_id, title, category, original_amount, due_date, source,
    terms_snapshot, notes, created_by
  ) values (
    p_tenant_id, trim(p_title), v_category, p_amount, p_due_date, 'staff_entry',
    jsonb_build_object('manual_approval_reason', trim(p_reason),
      'approved_by', auth.uid(), 'approved_at', now()),
    nullif(trim(coalesce(p_notes, '')), ''), auth.uid()
  ) returning id into v_charge_id;

  select to_jsonb(s) into v_row from public.billing_charge_summaries s where s.id = v_charge_id;
  return v_row;
end $$;

revoke all on function public.create_additional_charge(uuid,text,text,numeric,date,text,text)
  from public, anon;
grant execute on function public.create_additional_charge(uuid,text,text,numeric,date,text,text)
  to authenticated;

create or replace function public.apply_billing_charge_action(
  p_charge_id uuid,
  p_action_type text,
  p_reason text,
  p_amount numeric default null,
  p_new_due_date date default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_charge public.billing_charges;
  v_action text := lower(trim(p_action_type));
  v_verified numeric(12,2);
  v_current_amount numeric(12,2);
  v_delta numeric(12,2);
  v_row jsonb;
begin
  if public.current_user_role() <> 'owner' then raise exception 'Owner access required'; end if;
  if v_action not in ('void', 'due_date_extension', 'credit', 'debit') then
    raise exception 'Unsupported billing action';
  end if;
  if char_length(trim(coalesce(p_reason, ''))) not between 3 and 500 then
    raise exception 'A reason between 3 and 500 characters is required';
  end if;
  select * into v_charge from public.billing_charges where id = p_charge_id for update;
  if v_charge.id is null then raise exception 'Billing charge not found'; end if;
  if exists (select 1 from public.billing_charge_actions where charge_id = p_charge_id and action_type = 'void') then
    raise exception 'A voided charge cannot be changed';
  end if;
  select coalesce(sum(amount), 0) into v_verified from public.payment_transactions
    where charge_id = p_charge_id and status = 'verified';
  if exists (select 1 from public.payment_transactions
    where charge_id = p_charge_id and status = 'pending_verification') then
    raise exception 'Review the pending payment submission before changing this charge';
  end if;
  select amount into v_current_amount from public.billing_charge_summaries where id = p_charge_id;

  if v_action = 'void' then
    if v_verified > 0 then raise exception 'A charge with verified payment cannot be voided; issue a credit instead'; end if;
    insert into public.billing_charge_actions(charge_id, action_type, reason)
      values (p_charge_id, v_action, trim(p_reason));
  elsif v_action = 'due_date_extension' then
    if v_verified >= v_current_amount then raise exception 'A fully paid charge cannot be rescheduled'; end if;
    if p_new_due_date is null or p_new_due_date <= v_charge.due_date then
      raise exception 'The new due date must be later than the original due date';
    end if;
    insert into public.billing_charge_actions(charge_id, action_type, new_due_date, reason)
      values (p_charge_id, v_action, p_new_due_date, trim(p_reason));
  else
    if p_amount is null or p_amount <= 0 then raise exception 'Adjustment amount must be greater than zero'; end if;
    v_delta := case when v_action = 'credit' then -p_amount else p_amount end;
    if v_current_amount + v_delta < v_verified or v_current_amount + v_delta < 0 then
      raise exception 'A credit cannot reduce the charge below its verified payment total';
    end if;
    insert into public.billing_charge_actions(charge_id, action_type, amount_delta, reason)
      values (p_charge_id, v_action, v_delta, trim(p_reason));
  end if;

  select to_jsonb(s) into v_row from public.billing_charge_summaries s where s.id = p_charge_id;
  return v_row;
end $$;

revoke all on function public.apply_billing_charge_action(uuid,text,text,numeric,date)
  from public, anon;
grant execute on function public.apply_billing_charge_action(uuid,text,text,numeric,date)
  to authenticated;

-- Preserve original facts while projecting the effective amount and due date.
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
  coalesce(r.adjustment_total, 0)::numeric(12,2) as rent_adjustment
from public.billing_charges c
join public.profiles profile on profile.id = c.tenant_id
left join lateral (select coalesce(sum(t.amount),0) verified_total from public.payment_transactions t
  where t.charge_id=c.id and t.status='verified') v on true
left join lateral (select coalesce(sum(x.amount_delta),0) adjustment_total from public.rent_charge_adjustments x
  where x.charge_id=c.id) r on true
left join lateral (
  select coalesce(sum(x.amount_delta),0) amount_delta,
    max(x.new_due_date) filter (where x.action_type='due_date_extension') effective_due_date,
    bool_or(x.action_type='void') is_voided, max(x.created_at) last_action_at
  from public.billing_charge_actions x where x.charge_id=c.id
) a on true
left join lateral (select t.* from public.payment_transactions t
  where t.charge_id=c.id and t.status <> 'reversed'
  order by t.submitted_at desc, t.created_at desc limit 1) latest on true;

grant select on public.billing_charge_summaries to authenticated;
revoke all on public.billing_charge_summaries from anon;

comment on table public.billing_charge_actions is
  'Immutable audit trail for manual billing corrections; never created from conduct cases.';

-- Rent changes are contract decisions, so only owners use the public entry
-- point. The existing implementation remains the single ledger operation.
revoke execute on function public.apply_rent_rate_override(uuid,numeric,date,text)
  from authenticated;

create or replace function public.apply_owner_rent_rate_override(
  p_tenant_id uuid,
  p_new_monthly_rent numeric,
  p_effective_date date,
  p_reason text
) returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if public.current_user_role() <> 'owner' then
    raise exception 'Owner access required';
  end if;
  return public.apply_rent_rate_override(
    p_tenant_id, p_new_monthly_rent, p_effective_date, p_reason
  );
end $$;

revoke all on function public.apply_owner_rent_rate_override(uuid,numeric,date,text)
  from public, anon;
grant execute on function public.apply_owner_rent_rate_override(uuid,numeric,date,text)
  to authenticated;

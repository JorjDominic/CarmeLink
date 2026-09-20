-- Separate contract terms, immutable billing charges, and payment transactions.
-- Existing payment rows are preserved and migrated into the new ledger.

create table public.billing_charges (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid references public.tenant_contracts(id) on delete restrict,
  tenant_id uuid not null references public.profiles(id) on delete restrict,
  title text not null check (char_length(trim(title)) between 2 and 150),
  category text not null check (
    category in ('rent', 'utility', 'deposit', 'penalty', 'discount', 'other')
  ),
  original_amount numeric(12,2) not null check (original_amount >= 0),
  due_date date not null,
  period_start date,
  period_end date,
  source text not null default 'manual'
    check (source in ('contract', 'manual', 'migration')),
  terms_snapshot jsonb not null default '{}'::jsonb,
  created_by uuid references public.profiles(id) on delete restrict default auth.uid(),
  created_at timestamptz not null default now(),
  constraint billing_charge_period_valid check (
    (period_start is null and period_end is null)
    or (period_start is not null and period_end is not null and period_end >= period_start)
  ),
  constraint billing_charge_contract_source_valid check (
    source <> 'contract' or contract_id is not null
  )
);

create unique index billing_charges_contract_period_kind_uidx
  on public.billing_charges(contract_id, category, period_start)
  where contract_id is not null;
create index billing_charges_tenant_due_idx
  on public.billing_charges(tenant_id, due_date desc);
create index billing_charges_contract_idx
  on public.billing_charges(contract_id);

create table public.payment_transactions (
  id uuid primary key default gen_random_uuid(),
  charge_id uuid not null references public.billing_charges(id) on delete restrict,
  contract_id uuid references public.tenant_contracts(id) on delete restrict,
  tenant_id uuid not null references public.profiles(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  status text not null default 'pending_verification'
    check (status in ('pending_verification', 'verified', 'rejected', 'reversed')),
  payment_method text check (
    payment_method is null or payment_method in
      ('GCash', 'Maya', 'Bank transfer', 'Cash', 'Other')
  ),
  reference_number text,
  receipt_path text,
  submitted_by uuid not null references public.profiles(id) on delete restrict default auth.uid(),
  submitted_at timestamptz not null default now(),
  reviewed_by uuid references public.profiles(id) on delete restrict,
  reviewed_at timestamptz,
  review_notes text,
  reversal_of uuid references public.payment_transactions(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint payment_transaction_review_valid check (
    (status = 'pending_verification' and reviewed_by is null and reviewed_at is null)
    or (status <> 'pending_verification' and reviewed_by is not null and reviewed_at is not null)
  ),
  constraint payment_transaction_reversal_valid check (
    (status = 'reversed' and reversal_of is not null)
    or (status <> 'reversed' and reversal_of is null)
  )
);

create index payment_transactions_charge_idx
  on public.payment_transactions(charge_id, submitted_at desc);
create index payment_transactions_tenant_idx
  on public.payment_transactions(tenant_id, submitted_at desc);
create index payment_transactions_status_idx
  on public.payment_transactions(status);

alter table public.billing_charges enable row level security;
alter table public.payment_transactions enable row level security;

create policy billing_charges_staff_all on public.billing_charges
for all to authenticated using ((select public.is_staff()))
with check ((select public.is_staff()));
create policy billing_charges_tenant_select on public.billing_charges
for select to authenticated using (
  tenant_id = (select auth.uid())
  and (select public.current_user_role()) = 'tenant'
);
create policy billing_charges_guardian_select on public.billing_charges
for select to authenticated using (
  (select public.current_user_role()) = 'guardian'
  and exists (
    select 1 from public.guardian_tenant_links link
    where link.guardian_id = (select auth.uid())
      and link.tenant_id = billing_charges.tenant_id
  )
);

create policy payment_transactions_staff_all on public.payment_transactions
for all to authenticated using ((select public.is_staff()))
with check ((select public.is_staff()));
create policy payment_transactions_tenant_select on public.payment_transactions
for select to authenticated using (
  tenant_id = (select auth.uid())
  and (select public.current_user_role()) = 'tenant'
);
create policy payment_transactions_guardian_select on public.payment_transactions
for select to authenticated using (
  (select public.current_user_role()) = 'guardian'
  and exists (
    select 1 from public.guardian_tenant_links link
    where link.guardian_id = (select auth.uid())
      and link.tenant_id = payment_transactions.tenant_id
  )
);

grant select, insert, update, delete on public.billing_charges to authenticated;
grant select, insert, update on public.payment_transactions to authenticated;
revoke all on public.billing_charges, public.payment_transactions from anon;

-- Preserve every legacy invoice and its latest proof/review as ledger records.
insert into public.billing_charges (
  id, tenant_id, title, category, original_amount, due_date, source, created_at
)
select id, tenant_id, title, category, amount, due_date, 'migration', created_at
from public.payments
on conflict (id) do nothing;

insert into public.payment_transactions (
  charge_id, tenant_id, amount, status, payment_method, reference_number,
  receipt_path, submitted_by, submitted_at, reviewed_by, reviewed_at,
  review_notes, created_at
)
select p.id, p.tenant_id, p.amount,
  case when p.status = 'due' then 'pending_verification' else p.status end,
  p.payment_method, p.reference_number, p.receipt_path, p.tenant_id,
  coalesce(p.paid_at, p.created_at),
  case when p.status in ('due', 'pending_verification') then null else p.reviewed_by end,
  case when p.status in ('due', 'pending_verification') then null else p.reviewed_at end,
  p.review_notes, p.created_at
from public.payments p
where p.status <> 'due'
  and (p.status = 'pending_verification'
       or (p.reviewed_by is not null and p.reviewed_at is not null));

create or replace function public.validate_payment_transaction()
returns trigger language plpgsql set search_path = '' as $$
declare v_charge public.billing_charges;
begin
  select * into v_charge from public.billing_charges where id = new.charge_id;
  if v_charge.id is null then raise exception 'Billing charge does not exist'; end if;
  if new.tenant_id <> v_charge.tenant_id then
    raise exception 'Transaction tenant must match its billing charge';
  end if;
  if new.contract_id is distinct from v_charge.contract_id then
    raise exception 'Transaction contract must match its billing charge';
  end if;
  return new;
end; $$;
create trigger payment_transactions_validate
before insert or update on public.payment_transactions
for each row execute function public.validate_payment_transaction();

create or replace function public.protect_financial_ledger_facts()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_table_name = 'billing_charges' then
    if tg_op = 'DELETE' and old.source in ('contract', 'migration') then
      raise exception 'Generated and migrated billing charges are immutable';
    end if;
    if tg_op = 'UPDATE' and (
      old.contract_id is distinct from new.contract_id
      or old.tenant_id is distinct from new.tenant_id
      or old.category is distinct from new.category
      or old.original_amount is distinct from new.original_amount
      or old.due_date is distinct from new.due_date
      or old.period_start is distinct from new.period_start
      or old.period_end is distinct from new.period_end
      or old.source is distinct from new.source
      or old.terms_snapshot is distinct from new.terms_snapshot
      or old.created_at is distinct from new.created_at
    ) then
      raise exception 'Billing charge financial facts are immutable; create an adjustment charge';
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
end; $$;

create trigger billing_charges_protect_facts
before update or delete on public.billing_charges
for each row execute function public.protect_financial_ledger_facts();
create trigger payment_transactions_protect_facts
before update on public.payment_transactions
for each row execute function public.protect_financial_ledger_facts();

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
  profile.full_name as tenant_name
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

create or replace function public.generate_contract_billing_charges(p_contract_id uuid)
returns integer language plpgsql security definer set search_path = '' as $$
declare c public.tenant_contracts; v_period date; v_next date; v_count integer := 0;
begin
  if auth.uid() is not null and public.current_user_role() <> 'owner' then
    raise exception 'Owner access required';
  end if;
  select * into c from public.tenant_contracts where id = p_contract_id;
  if c.id is null then raise exception 'Contract not found'; end if;
  if c.status <> 'active' then raise exception 'Only active contracts generate charges'; end if;

  if c.security_deposit > 0 then
    insert into public.billing_charges (
      contract_id, tenant_id, title, category, original_amount, due_date,
      period_start, period_end, source, terms_snapshot, created_by
    ) values (
      c.id, c.tenant_id, 'Security deposit - ' || c.contract_number,
      'deposit', c.security_deposit, c.starts_on, c.starts_on, c.starts_on,
      'contract', jsonb_build_object('contract_number', c.contract_number,
        'security_deposit', c.security_deposit, 'generated_at', now()), auth.uid()
    ) on conflict (contract_id, category, period_start)
      where contract_id is not null do nothing;
    get diagnostics v_count = row_count;
  end if;

  v_period := c.starts_on;
  while v_period <= c.ends_on loop
    v_next := (v_period + interval '1 month')::date;
    insert into public.billing_charges (
      contract_id, tenant_id, title, category, original_amount, due_date,
      period_start, period_end, source, terms_snapshot, created_by
    ) values (
      c.id, c.tenant_id, to_char(v_period, 'FMMonth YYYY') || ' Rent',
      'rent', c.monthly_rent, v_period, v_period, least(v_next - 1, c.ends_on),
      'contract', jsonb_build_object('contract_number', c.contract_number,
        'monthly_rent', c.monthly_rent, 'starts_on', c.starts_on,
        'ends_on', c.ends_on, 'generated_at', now()), auth.uid()
    ) on conflict (contract_id, category, period_start)
      where contract_id is not null do nothing;
    if found then v_count := v_count + 1; end if;
    v_period := v_next;
  end loop;
  return v_count;
end; $$;

create or replace function public.sync_contract_billing_on_activation()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'active'
     and (tg_op = 'INSERT' or old.status is distinct from 'active') then
    perform public.generate_contract_billing_charges(new.id);
  end if;
  return new;
end; $$;
create trigger tenant_contracts_generate_billing
after insert or update of status on public.tenant_contracts
for each row execute function public.sync_contract_billing_on_activation();

create or replace function public.submit_payment_transaction(
  p_charge_id uuid, p_method text, p_reference_number text,
  p_receipt_path text default null, p_amount numeric default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare c public.billing_charges; v_balance numeric(12,2); v_amount numeric(12,2); v_row jsonb;
begin
  select * into c from public.billing_charges where id = p_charge_id;
  if c.tenant_id <> auth.uid() or public.current_user_role() <> 'tenant' then
    raise exception 'Tenant may submit only against their own charge';
  end if;
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
  select id into v_transaction from public.payment_transactions
  where charge_id = p_charge_id and status = 'pending_verification'
  order by submitted_at desc limit 1 for update;
  if v_transaction is null then raise exception 'No pending transaction found'; end if;
  update public.payment_transactions set
    status = case when p_approve then 'verified' else 'rejected' end,
    reviewed_by = auth.uid(), reviewed_at = now(),
    review_notes = nullif(trim(p_review_notes), '')
  where id = v_transaction;
  select to_jsonb(s) into v_row from public.billing_charge_summaries s where s.id = p_charge_id;
  return v_row;
end; $$;

revoke all on function public.generate_contract_billing_charges(uuid) from public, anon;
revoke all on function public.submit_payment_transaction(uuid, text, text, text, numeric) from public, anon;
revoke all on function public.review_payment_transaction(uuid, boolean, text) from public, anon;
grant execute on function public.generate_contract_billing_charges(uuid) to authenticated;
grant execute on function public.submit_payment_transaction(uuid, text, text, text, numeric) to authenticated;
grant execute on function public.review_payment_transaction(uuid, boolean, text) to authenticated;
revoke all on function public.validate_payment_transaction() from public, anon, authenticated;
revoke all on function public.sync_contract_billing_on_activation() from public, anon, authenticated;
revoke all on function public.protect_financial_ledger_facts() from public, anon, authenticated;

do $$ begin
  if not exists (
    select 1 from pg_publication_tables where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'billing_charges'
  ) then alter publication supabase_realtime add table public.billing_charges; end if;
  if not exists (
    select 1 from pg_publication_tables where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'payment_transactions'
  ) then alter publication supabase_realtime add table public.payment_transactions; end if;
end $$;

-- Generate charges for contracts that were already active before this migration.
do $$ declare c record; begin
  for c in select id from public.tenant_contracts where status = 'active' loop
    perform public.generate_contract_billing_charges(c.id);
  end loop;
end $$;

comment on table public.billing_charges is
  'Immutable amounts due generated from contract snapshots or entered manually.';
comment on table public.payment_transactions is
  'Append-only payment attempts; only verified rows reduce charge balances.';

-- Audited rent increases/decreases. The contract amount and issued charge stay
-- immutable; signed adjustment rows change only eligible future rent balances.

create table public.rent_rate_overrides (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.tenant_contracts(id) on delete restrict,
  tenant_id uuid not null references public.profiles(id) on delete restrict,
  previous_monthly_rent numeric(12,2) not null check (previous_monthly_rent > 0),
  new_monthly_rent numeric(12,2) not null check (new_monthly_rent > 0),
  effective_date date not null,
  reason text not null check (char_length(trim(reason)) between 3 and 500),
  created_by uuid not null references public.profiles(id) on delete restrict default auth.uid(),
  created_at timestamptz not null default now(),
  check (previous_monthly_rent <> new_monthly_rent)
);

create table public.rent_charge_adjustments (
  id uuid primary key default gen_random_uuid(),
  override_id uuid not null references public.rent_rate_overrides(id) on delete restrict,
  charge_id uuid not null references public.billing_charges(id) on delete restrict,
  amount_delta numeric(12,2) not null check (amount_delta <> 0),
  created_at timestamptz not null default now(),
  unique (override_id, charge_id)
);

create index rent_rate_overrides_tenant_effective_idx
  on public.rent_rate_overrides(tenant_id, effective_date desc);
create index rent_charge_adjustments_charge_idx
  on public.rent_charge_adjustments(charge_id);

alter table public.rent_rate_overrides enable row level security;
alter table public.rent_charge_adjustments enable row level security;

create policy rent_rate_overrides_staff_select on public.rent_rate_overrides
for select to authenticated using ((select public.is_staff()));
create policy rent_rate_overrides_tenant_select on public.rent_rate_overrides
for select to authenticated using (
  tenant_id = (select auth.uid())
  and (select public.current_user_role()) = 'tenant'
);
create policy rent_rate_overrides_guardian_select on public.rent_rate_overrides
for select to authenticated using (
  (select public.current_user_role()) = 'guardian'
  and exists (
    select 1 from public.guardian_tenant_links link
    where link.guardian_id = (select auth.uid())
      and link.tenant_id = rent_rate_overrides.tenant_id
  )
);
create policy rent_charge_adjustments_staff_select on public.rent_charge_adjustments
for select to authenticated using ((select public.is_staff()));
create policy rent_charge_adjustments_visible_charge_select
on public.rent_charge_adjustments for select to authenticated using (
  exists (
    select 1 from public.billing_charges charge
    where charge.id = rent_charge_adjustments.charge_id
      and (
        charge.tenant_id = (select auth.uid())
        or exists (
          select 1 from public.guardian_tenant_links link
          where link.guardian_id = (select auth.uid())
            and link.tenant_id = charge.tenant_id
        )
      )
  )
);

grant select on public.rent_rate_overrides, public.rent_charge_adjustments
  to authenticated;
revoke insert, update, delete on
  public.rent_rate_overrides, public.rent_charge_adjustments
  from authenticated;
revoke all on public.rent_rate_overrides, public.rent_charge_adjustments from anon;

create or replace view public.billing_charge_summaries
with (security_invoker = true) as
select
  c.id, c.contract_id, c.tenant_id, c.title, c.category,
  (c.original_amount + coalesce(a.adjustment_total, 0))::numeric(12,2) as amount,
  c.due_date, c.period_start, c.period_end,
  c.source, c.terms_snapshot, c.created_at, c.created_at as updated_at,
  greatest(c.original_amount + coalesce(a.adjustment_total, 0)
    - coalesce(v.verified_total, 0), 0)::numeric(12,2) as remaining_balance,
  case
    when coalesce(v.verified_total, 0) >=
         c.original_amount + coalesce(a.adjustment_total, 0) then 'verified'
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
  c.notes, c.created_by,
  c.original_amount as contract_amount,
  coalesce(a.adjustment_total, 0)::numeric(12,2) as rent_adjustment
from public.billing_charges c
join public.profiles profile on profile.id = c.tenant_id
left join lateral (
  select coalesce(sum(t.amount), 0) as verified_total
  from public.payment_transactions t
  where t.charge_id = c.id and t.status = 'verified'
) v on true
left join lateral (
  select coalesce(sum(adjustment.amount_delta), 0) as adjustment_total
  from public.rent_charge_adjustments adjustment
  where adjustment.charge_id = c.id
) a on true
left join lateral (
  select t.* from public.payment_transactions t
  where t.charge_id = c.id and t.status <> 'reversed'
  order by t.submitted_at desc, t.created_at desc limit 1
) latest on true;

grant select on public.billing_charge_summaries to authenticated;
revoke all on public.billing_charge_summaries from anon;

create or replace function public.apply_rent_rate_override(
  p_tenant_id uuid,
  p_new_monthly_rent numeric,
  p_effective_date date,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_contract public.tenant_contracts;
  v_previous_rate numeric(12,2);
  v_override_id uuid;
  v_count integer := 0;
  v_charge record;
  v_delta numeric(12,2);
begin
  if not public.is_staff() then
    raise exception 'Owner or caretaker access required';
  end if;
  if p_new_monthly_rent is null or p_new_monthly_rent <= 0 then
    raise exception 'New monthly rent must be greater than zero';
  end if;
  if p_effective_date is null or p_effective_date < current_date then
    raise exception 'Rent override must take effect today or later';
  end if;
  if char_length(trim(coalesce(p_reason, ''))) not between 3 and 500 then
    raise exception 'A reason between 3 and 500 characters is required';
  end if;

  select * into v_contract from public.tenant_contracts
  where tenant_id = p_tenant_id and status = 'active'
  order by starts_on desc limit 1 for update;
  if v_contract.id is null then
    raise exception 'Tenant has no active contract';
  end if;

  select coalesce((
    select override.new_monthly_rent
    from public.rent_rate_overrides override
    where override.contract_id = v_contract.id
      and override.effective_date <= p_effective_date
    order by override.effective_date desc, override.created_at desc limit 1
  ), v_contract.monthly_rent) into v_previous_rate;

  if v_previous_rate = p_new_monthly_rent then
    raise exception 'New monthly rent is unchanged';
  end if;

  insert into public.rent_rate_overrides (
    contract_id, tenant_id, previous_monthly_rent, new_monthly_rent,
    effective_date, reason, created_by
  ) values (
    v_contract.id, p_tenant_id, v_previous_rate, p_new_monthly_rent,
    p_effective_date, trim(p_reason), auth.uid()
  ) returning id into v_override_id;

  for v_charge in
    select s.id, s.amount
    from public.billing_charge_summaries s
    where s.contract_id = v_contract.id
      and s.category = 'rent'
      and s.due_date >= p_effective_date
      and s.status = 'upcoming'
    order by s.due_date
  loop
    v_delta := p_new_monthly_rent - v_charge.amount;
    if v_delta <> 0 then
      insert into public.rent_charge_adjustments (
        override_id, charge_id, amount_delta
      ) values (v_override_id, v_charge.id, v_delta);
      v_count := v_count + 1;
    end if;
  end loop;

  if v_count = 0 then
    raise exception 'No unpaid future rent charges are eligible for this effective date';
  end if;

  return jsonb_build_object(
    'override_id', v_override_id,
    'contract_id', v_contract.id,
    'previous_monthly_rent', v_previous_rate,
    'new_monthly_rent', p_new_monthly_rent,
    'effective_date', p_effective_date,
    'adjusted_charge_count', v_count
  );
end;
$$;

revoke all on function public.apply_rent_rate_override(uuid, numeric, date, text)
  from public, anon;
grant execute on function public.apply_rent_rate_override(uuid, numeric, date, text)
  to authenticated;

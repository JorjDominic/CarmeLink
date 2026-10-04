-- Deposits are receipts held for settlement, not tenant-payable bills.
-- Existing charge/transaction history is retained.
begin;

create table public.security_deposit_receipts (
  contract_id uuid primary key references public.tenant_contracts(id) on delete cascade,
  tenant_id uuid not null references public.profiles(id) on delete restrict,
  received_amount numeric(12,2) not null default 0 check (received_amount >= 0),
  received_on date,
  method text not null default '',
  reference text not null default '',
  refunded_amount numeric(12,2) not null default 0 check (refunded_amount >= 0),
  approved_deductions numeric(12,2) not null default 0 check (approved_deductions >= 0),
  settled_at timestamptz,
  updated_at timestamptz not null default now(),
  check (received_amount = 0 or received_on is not null)
);
alter table public.security_deposit_receipts enable row level security;
revoke all on public.security_deposit_receipts from anon, authenticated;
grant select on public.security_deposit_receipts to authenticated;
create policy security_deposit_receipts_read on public.security_deposit_receipts
for select to authenticated using (
  public.is_staff() or tenant_id = auth.uid() or public.is_guardian_of(tenant_id)
);

create table public.security_deposit_receipt_events (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.security_deposit_receipts(contract_id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete restrict,
  reason text not null,
  previous_amount numeric(12,2) not null,
  received_amount numeric(12,2) not null,
  received_on date,
  method text not null,
  reference text not null,
  created_at timestamptz not null default now()
);
alter table public.security_deposit_receipt_events enable row level security;
revoke all on public.security_deposit_receipt_events from anon, authenticated;
grant select on public.security_deposit_receipt_events to authenticated;
create policy security_deposit_receipt_events_read on public.security_deposit_receipt_events
for select to authenticated using (exists (
  select 1 from public.security_deposit_receipts r
  where r.contract_id = security_deposit_receipt_events.contract_id
));

-- Backfill only evidence of money received, never the contract's required amount.
insert into public.security_deposit_receipts (
  contract_id, tenant_id, received_amount, received_on, method, reference
)
select c.id, c.tenant_id, greatest(coalesce(p.received,0),coalesce(s.received,0)),
  case when greatest(coalesce(p.received,0),coalesce(s.received,0)) > 0
    then coalesce(p.received_on,s.received_on,current_date) end,
  case when greatest(coalesce(p.received,0),coalesce(s.received,0)) > 0 then 'Legacy receipt' else '' end,
  case when greatest(coalesce(p.received,0),coalesce(s.received,0)) > 0 then 'Preserved from verified deposit payment or confirmed settlement' else '' end
from public.tenant_contracts c
left join lateral (
  select sum(t.amount) received, max(t.reviewed_at)::date received_on
  from public.payment_transactions t join public.billing_charges b on b.id=t.charge_id
  where b.contract_id=c.id and b.category='deposit' and t.status='verified'
) p on true
left join lateral (
  select max(s.deposit_received_amount) received, max(s.updated_at)::date received_on
  from public.move_out_settlements s join public.move_out_cases m on m.id=s.case_id
  where m.contract_id=c.id and m.status <> 'cancelled'
) s on true;

-- Preserve finalized settlements exactly as recorded.
update public.security_deposit_receipts r set
  refunded_amount=s.refunded_amount, approved_deductions=s.approved_deductions, settled_at=s.settled_at
from (
  select distinct on (m.contract_id) m.contract_id,
    case when s.refund_status='refunded' then s.refundable_amount else 0 end refunded_amount,
    s.approved_deductions, coalesce(s.refunded_at,s.updated_at) settled_at
  from public.move_out_cases m join public.move_out_settlements s on s.case_id=m.id
  where s.refund_status in ('refunded','settled_zero','shortfall_pending')
  order by m.contract_id,s.updated_at desc
) s where r.contract_id=s.contract_id;

create or replace function public.record_security_deposit_receipt(
  p_contract_id uuid, p_amount numeric, p_received_on date,
  p_method text, p_reference text, p_reason text
) returns void language plpgsql security definer set search_path = '' as $$
declare c public.tenant_contracts; v_old numeric; v_settled timestamptz;
begin
  if public.current_user_role() is distinct from 'owner'::public.app_role then
    raise exception 'Owner access required';
  end if;
  if p_amount is null or p_amount < 0 or p_amount > 9999999999.99 then raise exception 'Invalid deposit amount'; end if;
  if p_amount > 0 and (p_received_on is null or p_received_on > (now() at time zone 'Asia/Manila')::date
    or length(trim(coalesce(p_method,'')))=0 or length(trim(coalesce(p_reference,'')))=0) then
    raise exception 'Receipt date, method, and reference are required for a received deposit';
  end if;
  if length(trim(coalesce(p_reason,''))) < 3 then raise exception 'A receipt or correction note is required'; end if;
  select * into c from public.tenant_contracts where id=p_contract_id for update;
  if not found then raise exception 'Contract not found'; end if;
  insert into public.security_deposit_receipts(contract_id,tenant_id) values(c.id,c.tenant_id)
    on conflict(contract_id) do nothing;
  select received_amount,settled_at into v_old,v_settled from public.security_deposit_receipts
    where contract_id=c.id for update;
  if v_settled is not null or exists (
    select 1 from public.move_out_cases m join public.move_out_settlements s on s.case_id=m.id
    where m.contract_id=c.id and (m.status in ('settlement_completed','ready_for_closure')
      or s.refund_status in ('refunded','settled_zero','shortfall_pending'))
  ) then raise exception 'Finalized deposit settlement cannot be changed'; end if;
  update public.security_deposit_receipts set received_amount=p_amount,
    received_on=case when p_amount>0 then p_received_on end,
    method=trim(coalesce(p_method,'')),reference=trim(coalesce(p_reference,'')),updated_at=now()
    where contract_id=c.id;
  insert into public.security_deposit_receipt_events(
    contract_id,actor_id,reason,previous_amount,received_amount,received_on,method,reference
  ) values(c.id,auth.uid(),trim(p_reason),v_old,p_amount,p_received_on,trim(coalesce(p_method,'')),trim(coalesce(p_reference,'')));
  update public.move_out_settlements s set deposit_received_amount=p_amount,updated_by=auth.uid()
    from public.move_out_cases m where m.id=s.case_id and m.contract_id=c.id
      and m.status <> 'cancelled';
  perform public.refresh_move_out_settlement(m.id) from public.move_out_cases m
    where m.contract_id=c.id and m.status <> 'cancelled';
end $$;
revoke all on function public.record_security_deposit_receipt(uuid,numeric,date,text,text,text) from public,anon;
grant execute on function public.record_security_deposit_receipt(uuid,numeric,date,text,text,text) to authenticated;

create or replace function public.guard_deposit_contract_tenant()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op='DELETE' then
    if exists(select 1 from public.security_deposit_receipts r where r.contract_id=old.id and r.received_amount>0)
       or exists(select 1 from public.security_deposit_receipt_events e where e.contract_id=old.id and (e.previous_amount>0 or e.received_amount>0)) then
      raise exception 'A contract with deposit receipt history cannot be deleted';
    end if;
    return old;
  end if;
  if new.tenant_id is distinct from old.tenant_id then
    if exists (select 1 from public.security_deposit_receipts r where r.contract_id=old.id and r.received_amount>0) then
      raise exception 'A contract with a confirmed deposit cannot be reassigned';
    end if;
    update public.security_deposit_receipts set tenant_id=new.tenant_id where contract_id=old.id;
  end if;
  return new;
end $$;
revoke all on function public.guard_deposit_contract_tenant() from public,anon,authenticated;
create trigger guard_deposit_contract_tenant before update of tenant_id or delete on public.tenant_contracts
for each row execute function public.guard_deposit_contract_tenant();

create table public.legacy_security_deposit_links (
  charge_id uuid primary key references public.billing_charges(id) on delete restrict,
  contract_id uuid not null references public.security_deposit_receipts(contract_id) on delete restrict,
  linked_by uuid not null references public.profiles(id) on delete restrict,
  linked_at timestamptz not null default now()
);
alter table public.legacy_security_deposit_links enable row level security;
revoke all on public.legacy_security_deposit_links from anon,authenticated;
grant select on public.legacy_security_deposit_links to authenticated;
create policy legacy_security_deposit_links_read on public.legacy_security_deposit_links
for select to authenticated using(exists(
  select 1 from public.security_deposit_receipts r where r.contract_id=legacy_security_deposit_links.contract_id
));

-- Historical deposits without a contract stay visible until the owner links
-- their evidence to the correct contract. No contract is guessed from dates.
create or replace function public.get_unassigned_security_deposits(p_tenant_id uuid)
returns table(charge_id uuid,received_amount numeric,received_on date,method text,reference text)
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not (public.is_staff() or auth.uid()=p_tenant_id or public.is_guardian_of(p_tenant_id)) then
    raise exception 'Deposit access denied';
  end if;
  return query select b.id,coalesce(sum(t.amount),0),max(t.reviewed_at)::date,
    coalesce(max(t.payment_method),'Legacy receipt'),coalesce(max(t.reference_number),b.id::text)
  from public.billing_charges b join public.payment_transactions t on t.charge_id=b.id and t.status='verified'
  where b.tenant_id=p_tenant_id and b.category='deposit' and b.contract_id is null
    and not exists(select 1 from public.legacy_security_deposit_links l where l.charge_id=b.id)
  group by b.id;
end $$;
revoke all on function public.get_unassigned_security_deposits(uuid) from public,anon;
grant execute on function public.get_unassigned_security_deposits(uuid) to authenticated;

create or replace function public.link_legacy_security_deposit(p_charge_id uuid,p_contract_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare b public.billing_charges; c public.tenant_contracts; r public.security_deposit_receipts;
        v_amount numeric; v_date date; v_method text; v_reference text;
begin
  if public.current_user_role() is distinct from 'owner'::public.app_role then raise exception 'Owner access required'; end if;
  select * into c from public.tenant_contracts where id=p_contract_id for update;
  if not found then raise exception 'Contract not found'; end if;
  select * into b from public.billing_charges where id=p_charge_id for update;
  if not found or b.category<>'deposit' or b.contract_id is not null or b.tenant_id<>c.tenant_id
    or exists(select 1 from public.legacy_security_deposit_links l where l.charge_id=b.id) then
    raise exception 'Only an unassigned deposit belonging to this tenant can be linked';
  end if;
  select * into r from public.security_deposit_receipts where contract_id=c.id for update;
  select coalesce(sum(t.amount),0),max(t.reviewed_at)::date,coalesce(max(t.payment_method),'Legacy receipt'),
    coalesce(max(t.reference_number),b.id::text) into v_amount,v_date,v_method,v_reference
    from public.payment_transactions t where t.charge_id=b.id and t.status='verified';
  if v_amount<=0 then raise exception 'No verified receipt is available to link'; end if;
  perform public.record_security_deposit_receipt(c.id,coalesce(r.received_amount,0)+v_amount,
    coalesce(r.received_on,v_date,(now() at time zone 'Asia/Manila')::date),
    coalesce(nullif(r.method,''),v_method),coalesce(nullif(r.reference,''),v_reference),
    'Linked legacy deposit receipt '||b.id::text);
  -- Associate immutable historical evidence without rewriting financial facts.
  insert into public.legacy_security_deposit_links(charge_id,contract_id,linked_by)
    values(b.id,c.id,auth.uid());
end $$;
revoke all on function public.link_legacy_security_deposit(uuid,uuid) from public,anon;
grant execute on function public.link_legacy_security_deposit(uuid,uuid) to authenticated;

-- New move-out cases read the confirmed receipt automatically.
create or replace function public.seed_move_out_deposit_receipt()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.security_deposit_receipts(contract_id,tenant_id)
    select m.contract_id,m.tenant_id from public.move_out_cases m where m.id=new.case_id
    on conflict(contract_id) do nothing;
  select coalesce(r.received_amount,0) into new.deposit_received_amount
    from public.move_out_cases m left join public.security_deposit_receipts r on r.contract_id=m.contract_id
    where m.id=new.case_id;
  new.deposit_received_amount:=coalesce(new.deposit_received_amount,0);
  new.refundable_amount:=greatest(new.deposit_received_amount-new.approved_deductions,0);
  new.shortfall_amount:=greatest(new.approved_deductions-new.deposit_received_amount,0);
  return new;
end $$;
revoke all on function public.seed_move_out_deposit_receipt() from public,anon,authenticated;
create trigger seed_move_out_deposit_receipt before insert on public.move_out_settlements
for each row execute function public.seed_move_out_deposit_receipt();

-- Existing open cases use the same receipt; finalized financial outcomes stay intact.
update public.move_out_settlements s set deposit_received_amount=r.received_amount,
  refundable_amount=greatest(r.received_amount-s.approved_deductions,0),
  shortfall_amount=greatest(s.approved_deductions-r.received_amount,0)
from public.move_out_cases m join public.security_deposit_receipts r on r.contract_id=m.contract_id
where s.case_id=m.id and m.status not in ('cancelled','settlement_completed','ready_for_closure')
  and s.refund_status='pending';

create or replace function public.sync_finalized_deposit_receipt()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.refund_status in ('refunded','settled_zero','shortfall_pending') then
    update public.security_deposit_receipts r set
      refunded_amount=case when new.refund_status='refunded' then new.refundable_amount else 0 end,
      approved_deductions=new.approved_deductions,settled_at=coalesce(new.refunded_at,now()),updated_at=now()
      from public.move_out_cases m where m.id=new.case_id and r.contract_id=m.contract_id;
  end if;
  return new;
end $$;
revoke all on function public.sync_finalized_deposit_receipt() from public,anon,authenticated;
create trigger sync_finalized_deposit_receipt after update of refund_status on public.move_out_settlements
for each row execute function public.sync_finalized_deposit_receipt();

-- The previous manual setter could create a second conflicting amount.
create or replace function public.set_move_out_deposit_received(p_case_id uuid,p_amount numeric)
returns void language plpgsql security definer set search_path = '' as $$
begin
  raise exception 'Record or correct the deposit receipt on the contract; move-out uses that confirmed amount automatically';
end $$;

-- Pending legacy deposits are archived with an explicit audit action, not deleted.
-- Paid/part-paid charges and all transaction history remain untouched.
insert into public.billing_charge_actions(charge_id,action_type,reason,created_by)
select b.id,'void','Deposit collection moved to separate receipt record',coalesce(b.created_by,c.created_by)
from public.billing_charges b join public.tenant_contracts c on c.id=b.contract_id
where b.category='deposit' and coalesce(b.created_by,c.created_by) is not null
  and not exists(select 1 from public.payment_transactions t where t.charge_id=b.id and t.status in ('verified','pending_verification'))
  and not exists(select 1 from public.billing_charge_actions a where a.charge_id=b.id and a.action_type='void');

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
  if c.category = 'deposit' then raise exception 'Security deposits are recorded by management, not paid through Payments'; end if;
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
  if tg_op='INSERT' and v_charge.category='deposit' then
    raise exception 'Record new deposit receipts outside the payment transaction ledger';
  end if;
  return new;
end; $$;

-- Existing pending deposit proofs may still be reviewed. Reflect verified changes
-- in the receipt and open settlement without deleting historical transactions.
create or replace function public.sync_legacy_deposit_payment_receipt()
returns trigger language plpgsql security definer set search_path = '' as $$
declare b public.billing_charges; v_delta numeric:=0; v_old numeric; v_settled timestamptz;
        v_actor uuid; v_date date;
begin
  select * into b from public.billing_charges where id=coalesce(new.charge_id,old.charge_id);
  if b.category <> 'deposit' then return new; end if;
  if b.contract_id is null then
    select l.contract_id into b.contract_id from public.legacy_security_deposit_links l where l.charge_id=b.id;
  end if;
  if b.contract_id is null then return new; end if;
  if tg_op <> 'INSERT' and old.status='verified' then v_delta:=v_delta-old.amount; end if;
  if tg_op <> 'DELETE' and new.status='verified' then v_delta:=v_delta+new.amount; end if;
  if v_delta=0 then return new; end if;
  v_actor:=coalesce(auth.uid(),new.reviewed_by,old.reviewed_by,b.created_by);
  v_date:=coalesce(new.reviewed_at,old.reviewed_at,now())::date;
  insert into public.security_deposit_receipts(contract_id,tenant_id) values(b.contract_id,b.tenant_id)
    on conflict(contract_id) do nothing;
  select received_amount,settled_at into v_old,v_settled from public.security_deposit_receipts
    where contract_id=b.contract_id for update;
  if v_settled is not null then raise exception 'Finalized deposit receipt cannot change through payment review'; end if;
  if v_old+v_delta<0 then raise exception 'Deposit receipt must be reconciled before reversing this payment'; end if;
  update public.security_deposit_receipts set received_amount=v_old+v_delta,
    received_on=case when v_old+v_delta=0 then null else coalesce(received_on,v_date) end,
    method=case when method='' then coalesce(new.payment_method,old.payment_method,'Legacy receipt') else method end,
    reference=case when reference='' then coalesce(new.reference_number,old.reference_number,'Legacy payment review') else reference end,
    updated_at=now() where contract_id=b.contract_id;
  insert into public.security_deposit_receipt_events(contract_id,actor_id,reason,previous_amount,received_amount,received_on,method,reference)
    select contract_id,v_actor,'Legacy deposit payment review',v_old,received_amount,received_on,method,reference
    from public.security_deposit_receipts where contract_id=b.contract_id;
  update public.move_out_settlements s set deposit_received_amount=v_old+v_delta,updated_by=v_actor
    from public.move_out_cases m where m.id=s.case_id and m.contract_id=b.contract_id and m.status <> 'cancelled';
  perform public.refresh_move_out_settlement(m.id) from public.move_out_cases m
    where m.contract_id=b.contract_id and m.status <> 'cancelled';
  return new;
end $$;
revoke all on function public.sync_legacy_deposit_payment_receipt() from public,anon,authenticated;
create trigger sync_legacy_deposit_payment_receipt after insert or update of status,amount or delete
on public.payment_transactions for each row execute function public.sync_legacy_deposit_payment_receipt();

-- Defence in depth: direct staff writes cannot create new payable deposits either.
create or replace function public.reject_new_deposit_bill()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.category='deposit' then raise exception 'Record security deposits separately from billing charges'; end if;
  return new;
end $$;
revoke all on function public.reject_new_deposit_bill() from public,anon,authenticated;
create trigger reject_new_deposit_bill before insert or update of category on public.billing_charges
for each row execute function public.reject_new_deposit_bill();
create index security_deposit_receipts_tenant_idx on public.security_deposit_receipts(tenant_id);
create index security_deposit_receipt_events_contract_idx on public.security_deposit_receipt_events(contract_id,created_at desc);

do $$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    alter publication supabase_realtime add table public.security_deposit_receipts;
    alter publication supabase_realtime add table public.legacy_security_deposit_links;
  end if;
end $$;
commit;

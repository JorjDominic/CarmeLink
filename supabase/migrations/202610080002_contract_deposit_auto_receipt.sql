-- Business rule: entering a deposit when creating a contract confirms receipt.
-- Existing evidence and finalized settlements always take precedence.
begin;

create or replace function public.initialize_contract_deposit_receipt(
  p_contract_id uuid, p_backfill boolean default false
) returns boolean language plpgsql security definer set search_path = '' as $$
declare
  c public.tenant_contracts;
  r public.security_deposit_receipts;
  v_date date;
  v_reason text;
begin
  select * into c from public.tenant_contracts where id=p_contract_id for update;
  if not found then raise exception 'Contract not found'; end if;
  -- Avoid double-counting legacy money waiting to be linked or reviewed.
  if p_backfill and exists (
    select 1 from public.payment_transactions t
    join public.billing_charges b on b.id=t.charge_id
    where b.category='deposit' and b.tenant_id=c.tenant_id
      and ((b.contract_id=c.id and t.status='pending_verification')
        or (b.contract_id is null and t.status in ('verified','pending_verification')
          and not exists(select 1 from public.legacy_security_deposit_links l where l.charge_id=b.id)))
  ) then return false; end if;
  if exists (
    select 1 from public.move_out_cases m join public.move_out_settlements s on s.case_id=m.id
    where m.contract_id=c.id and (m.status in ('settlement_completed','ready_for_closure')
      or s.refund_status in ('refunded','settled_zero','shortfall_pending'))
  ) then return false; end if;

  insert into public.security_deposit_receipts(contract_id,tenant_id)
    values(c.id,c.tenant_id) on conflict(contract_id) do nothing;
  select * into r from public.security_deposit_receipts where contract_id=c.id for update;
  if r.received_amount<>0 or r.received_on is not null or r.method<>'' or r.reference<>''
    or r.refunded_amount<>0 or r.approved_deductions<>0 or r.settled_at is not null
    or exists(select 1 from public.security_deposit_receipt_events where contract_id=c.id)
  then return false; end if;
  if c.security_deposit<=0 then return false; end if;

  v_date := least((c.created_at at time zone 'Asia/Manila')::date,
                  (now() at time zone 'Asia/Manila')::date);
  v_reason := case when p_backfill then
    'Existing contract deposit recognized as received under contract policy. Date based on contract creation; payment channel not recorded.'
    else 'Deposit received automatically when contract was created. Payment channel not recorded.' end;
  update public.security_deposit_receipts set
    received_amount=c.security_deposit,received_on=v_date,
    method='Recorded in contract',reference=c.contract_number,updated_at=now()
    where contract_id=c.id;
  insert into public.security_deposit_receipt_events(
    contract_id,actor_id,reason,previous_amount,received_amount,received_on,method,reference
  ) values(c.id,c.created_by,v_reason,0,c.security_deposit,v_date,'Recorded in contract',c.contract_number);
  update public.move_out_settlements s set deposit_received_amount=c.security_deposit,
    updated_by=c.created_by from public.move_out_cases m
    where m.id=s.case_id and m.contract_id=c.id and m.status<>'cancelled';
  perform public.refresh_move_out_settlement(m.id) from public.move_out_cases m
    where m.contract_id=c.id and m.status<>'cancelled';
  return true;
end;
$$;
revoke all on function public.initialize_contract_deposit_receipt(uuid,boolean) from public,anon,authenticated;

create or replace function public.receive_deposit_on_contract_creation()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.initialize_contract_deposit_receipt(new.id,false);
  return new;
end;
$$;
revoke all on function public.receive_deposit_on_contract_creation() from public,anon,authenticated;
create trigger receive_deposit_on_contract_creation after insert on public.tenant_contracts
for each row execute function public.receive_deposit_on_contract_creation();

do $$
declare c record; v_updated integer:=0; v_preserved integer:=0;
begin
  for c in select id from public.tenant_contracts where security_deposit>0 order by id loop
    if public.initialize_contract_deposit_receipt(c.id,true) then
      v_updated:=v_updated+1;
    else v_preserved:=v_preserved+1;
    end if;
  end loop;
  raise notice 'Contract deposits recognized as received: %. Existing evidence, legacy review/linking, or finalized settlements preserved: %.',v_updated,v_preserved;
end;
$$;
commit;

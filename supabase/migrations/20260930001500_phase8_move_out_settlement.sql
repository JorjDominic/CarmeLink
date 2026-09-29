begin;
-- Phase 8: Move-out & Settlement
--
-- This migration owns bounded move-out records, final-inspection coordination,
-- clearance, deposit settlement, refund tracking, and closure handoff.
-- It deliberately DOES NOT update tenant_contracts.status, end tenant_assignments,
-- release bed spaces, or create shortfall billing charges. Those contract/occupancy
-- state transitions remain a separate Jorj-reviewed integration boundary.

create table public.move_out_cases (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.profiles(id) on delete restrict,
  tenant_name_snapshot text not null,
  contract_id uuid references public.tenant_contracts(id) on delete restrict,
  contract_number_snapshot text,
  contract_ends_on_snapshot date,
  contract_deposit_amount numeric(12,2) not null default 0
    check (contract_deposit_amount >= 0),
  room_id uuid references public.rooms(id) on delete restrict,
  room_number_snapshot text,
  bed_label_snapshot text,
  notice_submitted_on date not null,
  planned_move_out_on date not null,
  reason text not null default '' check (char_length(reason) <= 1200),
  status text not null default 'notice_submitted' check (status in (
    'notice_submitted', 'inspection_scheduled', 'inspection_completed',
    'clearance_review', 'settlement_pending', 'settlement_completed',
    'ready_for_closure', 'cancelled'
  )),
  final_inspection_id uuid references public.room_inspections(id) on delete restrict,
  refund_due_on date not null,
  staff_notes text not null default '' check (char_length(staff_notes) <= 3000),
  closure_handoff_note text not null default ''
    check (char_length(closure_handoff_note) <= 3000),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancellation_reason text not null default ''
    check (char_length(cancellation_reason) <= 1200),
  check (planned_move_out_on >= notice_submitted_on + 30)
);
create unique index move_out_cases_one_active_per_tenant_idx
  on public.move_out_cases(tenant_id)
  where status <> 'cancelled';
create index move_out_cases_status_date_idx
  on public.move_out_cases(status, planned_move_out_on);
create trigger move_out_cases_set_updated_at
before update on public.move_out_cases
for each row execute function public.set_updated_at();
create table public.move_out_clearance_items (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.move_out_cases(id) on delete cascade,
  item_key text not null check (item_key in ('room_return','property_return','account_review')),
  label text not null,
  sort_order smallint not null,
  status text not null default 'pending'
    check (status in ('pending','cleared','blocked','not_applicable')),
  notes text not null default '' check (char_length(notes) <= 1200),
  reviewed_by uuid references public.profiles(id) on delete restrict,
  reviewed_at timestamptz,
  updated_at timestamptz not null default now(),
  unique(case_id, item_key)
);
create trigger move_out_clearance_items_set_updated_at
before update on public.move_out_clearance_items
for each row execute function public.set_updated_at();
create table public.move_out_deductions (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.move_out_cases(id) on delete cascade,
  category text not null check (category in ('damage','cleaning','replacement','utility','other')),
  label text not null check (char_length(trim(label)) between 2 and 160),
  amount numeric(12,2) not null check (amount > 0),
  evidence_note text not null check (char_length(trim(evidence_note)) between 3 and 1500),
  status text not null default 'proposed' check (status in ('proposed','approved','rejected')),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  reviewed_by uuid references public.profiles(id) on delete restrict,
  reviewed_at timestamptz,
  review_note text not null default '' check (char_length(review_note) <= 1500)
);
create index move_out_deductions_case_idx on public.move_out_deductions(case_id, created_at);
create table public.move_out_settlements (
  case_id uuid primary key references public.move_out_cases(id) on delete cascade,
  contract_deposit_amount numeric(12,2) not null default 0,
  deposit_received_amount numeric(12,2) not null default 0 check (deposit_received_amount >= 0),
  approved_deductions numeric(12,2) not null default 0 check (approved_deductions >= 0),
  refundable_amount numeric(12,2) not null default 0 check (refundable_amount >= 0),
  shortfall_amount numeric(12,2) not null default 0 check (shortfall_amount >= 0),
  refund_due_on date not null,
  refund_status text not null default 'pending' check (refund_status in (
    'pending','refunded','settled_zero','shortfall_pending'
  )),
  refund_method text,
  refund_reference text,
  refund_proof_path text,
  refunded_at timestamptz,
  shortfall_note text not null default '' check (char_length(shortfall_note) <= 2000),
  tenant_response text not null default '' check (char_length(tenant_response) <= 2000),
  tenant_acknowledged_at timestamptz,
  updated_by uuid references public.profiles(id) on delete restrict,
  updated_at timestamptz not null default now()
);
create trigger move_out_settlements_set_updated_at
before update on public.move_out_settlements
for each row execute function public.set_updated_at();
alter table public.move_out_cases enable row level security;
alter table public.move_out_clearance_items enable row level security;
alter table public.move_out_deductions enable row level security;
alter table public.move_out_settlements enable row level security;
revoke all on public.move_out_cases from anon, authenticated;
revoke all on public.move_out_clearance_items from anon, authenticated;
revoke all on public.move_out_deductions from anon, authenticated;
revoke all on public.move_out_settlements from anon, authenticated;
grant select on public.move_out_cases to authenticated;
grant select on public.move_out_clearance_items to authenticated;
grant select on public.move_out_deductions to authenticated;
grant select on public.move_out_settlements to authenticated;
create policy move_out_cases_authorized_select on public.move_out_cases
for select to authenticated using (
  tenant_id = auth.uid() or (select public.is_staff())
);
create policy move_out_clearance_authorized_select on public.move_out_clearance_items
for select to authenticated using (exists (
  select 1 from public.move_out_cases c
  where c.id = case_id and (c.tenant_id = auth.uid() or (select public.is_staff()))
));
create policy move_out_deductions_authorized_select on public.move_out_deductions
for select to authenticated using (exists (
  select 1 from public.move_out_cases c
  where c.id = case_id and (c.tenant_id = auth.uid() or (select public.is_staff()))
));
create policy move_out_settlements_authorized_select on public.move_out_settlements
for select to authenticated using (exists (
  select 1 from public.move_out_cases c
  where c.id = case_id and (c.tenant_id = auth.uid() or (select public.is_staff()))
));
create or replace function public.refresh_move_out_settlement(p_case_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_deposit numeric(12,2);
  v_deductions numeric(12,2);
  v_status text;
begin
  select deposit_received_amount, refund_status
    into v_deposit, v_status
  from public.move_out_settlements where case_id = p_case_id for update;
  if not found then raise exception 'Move-out settlement not found'; end if;
  if v_status in ('refunded','settled_zero','shortfall_pending') then
    raise exception 'Finalized settlement cannot be recalculated';
  end if;
  select coalesce(sum(amount),0) into v_deductions
  from public.move_out_deductions where case_id=p_case_id and status='approved';
  update public.move_out_settlements set
    approved_deductions=v_deductions,
    refundable_amount=greatest(v_deposit-v_deductions,0),
    shortfall_amount=greatest(v_deductions-v_deposit,0),
    refund_status='pending',
    updated_by=auth.uid()
  where case_id=p_case_id;
end $$;
revoke all on function public.refresh_move_out_settlement(uuid) from public, anon, authenticated;
create or replace function public.create_move_out_case(
  p_tenant_id uuid,
  p_notice_submitted_on date,
  p_planned_move_out_on date,
  p_reason text default ''
) returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_role public.app_role;
  v_contract public.tenant_contracts%rowtype;
  v_tenant_name text;
  v_room_id uuid;
  v_room_number text;
  v_bed_label text;
  v_case_id uuid;
  v_refund_due date;
  v_notice_date date := p_notice_submitted_on;
begin
  if v_actor is null then raise exception 'Authentication required'; end if;
  select role into v_role from public.profiles where id=v_actor;
  if v_role is null or v_role not in ('tenant','owner','caretaker') then raise exception 'Move-out access denied'; end if;
  if v_role='tenant' and p_tenant_id<>v_actor then raise exception 'Tenants may submit only their own notice'; end if;
  if v_role='tenant' then
    -- Tenant notices use the dormitory's local date rather than trusting a
    -- client-supplied date or the database server's UTC calendar date.
    v_notice_date := (now() at time zone 'Asia/Manila')::date;
  end if;
  if v_role in ('owner','caretaker') and not coalesce(public.is_staff(),false) then raise exception 'Staff access required'; end if;
  if not exists(select 1 from public.profiles where id=p_tenant_id and role='tenant') then
    raise exception 'Valid tenant required';
  end if;
  if v_notice_date is null or p_planned_move_out_on is null then raise exception 'Notice and move-out dates are required'; end if;
  if p_planned_move_out_on < v_notice_date + 30 then
    raise exception 'Move-out requires at least 30 days notice';
  end if;
  if exists(select 1 from public.move_out_cases where tenant_id=p_tenant_id and status<>'cancelled') then
    raise exception 'Tenant already has an active move-out case';
  end if;

  select full_name into v_tenant_name from public.profiles where id=p_tenant_id;
  select * into v_contract from public.tenant_contracts
   where tenant_id=p_tenant_id and status='active'
   order by starts_on desc limit 1;
  if not found then
    select * into v_contract from public.tenant_contracts
     where tenant_id=p_tenant_id order by starts_on desc limit 1;
  end if;

  select r.id, r.room_number, b.label
    into v_room_id, v_room_number, v_bed_label
  from public.tenant_assignments a
  join public.bed_spaces b on b.id=a.bed_space_id
  join public.rooms r on r.id=b.room_id
  where a.tenant_id=p_tenant_id and a.status='active'
  order by a.created_at desc limit 1;

  v_refund_due := coalesce(v_contract.ends_on, p_planned_move_out_on) + 30;
  insert into public.move_out_cases(
    tenant_id,tenant_name_snapshot,contract_id,contract_number_snapshot,
    contract_ends_on_snapshot,contract_deposit_amount,room_id,room_number_snapshot,
    bed_label_snapshot,notice_submitted_on,planned_move_out_on,reason,status,
    refund_due_on,created_by
  ) values (
    p_tenant_id,v_tenant_name,v_contract.id,v_contract.contract_number,
    v_contract.ends_on,coalesce(v_contract.security_deposit,0),v_room_id,v_room_number,
    v_bed_label,v_notice_date,p_planned_move_out_on,trim(coalesce(p_reason,'')),
    'notice_submitted',v_refund_due,v_actor
  ) returning id into v_case_id;

  insert into public.move_out_clearance_items(case_id,item_key,label,sort_order) values
    (v_case_id,'room_return','Room / key return',1),
    (v_case_id,'property_return','Dormitory property return',2),
    (v_case_id,'account_review','Account and document review',3);
  insert into public.move_out_settlements(
    case_id,contract_deposit_amount,refund_due_on,updated_by
  ) values (v_case_id,coalesce(v_contract.security_deposit,0),v_refund_due,v_actor);
  return v_case_id;
end $$;
revoke all on function public.create_move_out_case(uuid,date,date,text) from public, anon;
grant execute on function public.create_move_out_case(uuid,date,date,text) to authenticated;
create or replace function public.cancel_move_out_case(p_case_id uuid, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_case public.move_out_cases; v_actor uuid:=auth.uid();
begin
  select * into v_case from public.move_out_cases where id=p_case_id for update;
  if not found then raise exception 'Move-out case not found'; end if;
  if not (coalesce(public.is_staff(),false) or v_case.tenant_id=v_actor) then raise exception 'Move-out access denied'; end if;
  if v_case.final_inspection_id is not null then raise exception 'A scheduled final inspection must be reviewed by staff before cancellation'; end if;
  if char_length(trim(coalesce(p_reason,'')))<3 then raise exception 'Cancellation reason is required'; end if;
  update public.move_out_cases set status='cancelled',cancelled_at=now(),cancellation_reason=trim(p_reason)
  where id=p_case_id;
end $$;
revoke all on function public.cancel_move_out_case(uuid,text) from public, anon;
grant execute on function public.cancel_move_out_case(uuid,text) to authenticated;
create or replace function public.schedule_move_out_final_inspection(
  p_case_id uuid, p_scheduled_at timestamptz, p_notice_text text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_case public.move_out_cases; v_id uuid; v_actor uuid:=auth.uid(); v_notice text:=trim(coalesce(p_notice_text,''));
begin
  if not coalesce(public.is_staff(),false) then raise exception 'Only staff may schedule final inspections'; end if;
  select * into v_case from public.move_out_cases where id=p_case_id for update;
  if not found then raise exception 'Move-out case not found'; end if;
  if v_case.status in ('cancelled','settlement_completed','ready_for_closure') then
    raise exception 'This move-out case no longer accepts inspection changes';
  end if;
  if v_case.room_id is null then raise exception 'Tenant has no active room snapshot for final inspection'; end if;
  if v_case.final_inspection_id is not null then raise exception 'Final move-out inspection is already scheduled'; end if;
  if p_scheduled_at<=now() then raise exception 'Inspection must be scheduled in the future'; end if;
  if char_length(v_notice)<5 then raise exception 'Written inspection notice must contain at least 5 characters'; end if;
  insert into public.room_inspections(
    room_id,inspection_type,status,scheduled_at,notice_text,notice_published_at,created_by
  ) values (
    v_case.room_id,'move_out','scheduled',p_scheduled_at,v_notice,now(),v_actor
  ) returning id into v_id;
  update public.move_out_cases set final_inspection_id=v_id,status='inspection_scheduled' where id=p_case_id;
  return v_id;
end $$;
revoke all on function public.schedule_move_out_final_inspection(uuid,timestamptz,text) from public, anon;
grant execute on function public.schedule_move_out_final_inspection(uuid,timestamptz,text) to authenticated;
create or replace function public.sync_move_out_case_from_inspection()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.inspection_type <> 'move_out' then return new; end if;
  if new.status = 'completed' then
    update public.move_out_cases set status='inspection_completed'
    where final_inspection_id=new.id
      and status in ('notice_submitted','inspection_scheduled');
  elsif new.status = 'cancelled' then
    update public.move_out_cases set status='notice_submitted',final_inspection_id=null
    where final_inspection_id=new.id and status not in ('cancelled','ready_for_closure');
  end if;
  return new;
end $$;
revoke all on function public.sync_move_out_case_from_inspection() from public, anon, authenticated;
create trigger room_inspections_sync_move_out_case
after update of status on public.room_inspections
for each row execute function public.sync_move_out_case_from_inspection();
create or replace function public.set_move_out_clearance_item(
  p_case_id uuid,p_item_key text,p_status text,p_notes text default ''
) returns void language plpgsql security definer set search_path = '' as $$
declare v_case_status text; v_refund_status text;
begin
  if not coalesce(public.is_staff(),false) then raise exception 'Staff access required'; end if;
  select c.status,s.refund_status into v_case_status,v_refund_status
  from public.move_out_cases c join public.move_out_settlements s on s.case_id=c.id
  where c.id=p_case_id for update of c;
  if not found then raise exception 'Move-out case not found'; end if;
  if v_case_status in ('cancelled','settlement_completed','ready_for_closure')
     or v_refund_status in ('refunded','settled_zero','shortfall_pending') then
    raise exception 'Finalized move-out case cannot change clearance';
  end if;
  if p_status not in ('pending','cleared','blocked','not_applicable') then raise exception 'Invalid clearance status'; end if;
  update public.move_out_clearance_items set status=p_status,notes=trim(coalesce(p_notes,'')),
    reviewed_by=auth.uid(),reviewed_at=now()
  where case_id=p_case_id and item_key=p_item_key;
  if not found then raise exception 'Move-out clearance item not found'; end if;
  update public.move_out_cases set status='clearance_review' where id=p_case_id;
end $$;
revoke all on function public.set_move_out_clearance_item(uuid,text,text,text) from public, anon;
grant execute on function public.set_move_out_clearance_item(uuid,text,text,text) to authenticated;
create or replace function public.set_move_out_deposit_received(p_case_id uuid,p_amount numeric)
returns void language plpgsql security definer set search_path = '' as $$
declare v_case_status text; v_refund_status text;
begin
  if public.current_user_role() is distinct from 'owner'::public.app_role then raise exception 'Owner access required'; end if;
  if p_amount is null or p_amount<0 then raise exception 'Deposit received amount cannot be negative'; end if;
  select c.status,s.refund_status into v_case_status,v_refund_status
  from public.move_out_cases c join public.move_out_settlements s on s.case_id=c.id
  where c.id=p_case_id for update of c;
  if not found then raise exception 'Move-out settlement not found'; end if;
  if v_case_status in ('cancelled','settlement_completed','ready_for_closure')
     or v_refund_status in ('refunded','settled_zero','shortfall_pending') then
    raise exception 'Finalized move-out settlement cannot change deposit received';
  end if;
  update public.move_out_settlements set deposit_received_amount=p_amount,updated_by=auth.uid()
   where case_id=p_case_id;
  perform public.refresh_move_out_settlement(p_case_id);
end $$;
revoke all on function public.set_move_out_deposit_received(uuid,numeric) from public, anon;
grant execute on function public.set_move_out_deposit_received(uuid,numeric) to authenticated;
create or replace function public.add_move_out_deduction(
  p_case_id uuid,p_category text,p_label text,p_amount numeric,p_evidence_note text
) returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_status text; v_case_status text;
begin
  if public.current_user_role() is distinct from 'owner'::public.app_role then raise exception 'Owner access required'; end if;
  select c.status,s.refund_status into v_case_status,v_status
  from public.move_out_cases c join public.move_out_settlements s on s.case_id=c.id
  where c.id=p_case_id for update of c;
  if not found then raise exception 'Move-out settlement not found'; end if;
  if v_case_status in ('cancelled','settlement_completed','ready_for_closure')
     or v_status in ('refunded','settled_zero','shortfall_pending') then
    raise exception 'Finalized settlement cannot receive deductions';
  end if;
  if p_category not in ('damage','cleaning','replacement','utility','other') then raise exception 'Invalid deduction category'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'Deduction amount must be positive'; end if;
  if char_length(trim(coalesce(p_label,'')))<2 then raise exception 'Deduction label is required'; end if;
  if char_length(trim(coalesce(p_evidence_note,'')))<3 then raise exception 'Documented evidence note is required'; end if;
  insert into public.move_out_deductions(case_id,category,label,amount,evidence_note,created_by)
  values(p_case_id,p_category,trim(p_label),p_amount,trim(p_evidence_note),auth.uid()) returning id into v_id;
  return v_id;
end $$;
revoke all on function public.add_move_out_deduction(uuid,text,text,numeric,text) from public, anon;
grant execute on function public.add_move_out_deduction(uuid,text,text,numeric,text) to authenticated;
create or replace function public.review_move_out_deduction(
  p_deduction_id uuid,p_approve boolean,p_review_note text default ''
) returns void language plpgsql security definer set search_path = '' as $$
declare v_case_id uuid; v_existing text; v_case_status text; v_refund_status text;
begin
  if public.current_user_role() is distinct from 'owner'::public.app_role then raise exception 'Owner access required'; end if;
  select case_id,status into v_case_id,v_existing from public.move_out_deductions where id=p_deduction_id for update;
  if not found then raise exception 'Move-out deduction not found'; end if;
  select c.status,s.refund_status into v_case_status,v_refund_status
  from public.move_out_cases c join public.move_out_settlements s on s.case_id=c.id
  where c.id=v_case_id for update of c;
  if v_case_status in ('cancelled','settlement_completed','ready_for_closure')
     or v_refund_status in ('refunded','settled_zero','shortfall_pending') then
    raise exception 'Finalized settlement cannot review deductions';
  end if;
  if v_existing<>'proposed' then raise exception 'Deduction was already reviewed'; end if;
  update public.move_out_deductions set status=case when p_approve then 'approved' else 'rejected' end,
    reviewed_by=auth.uid(),reviewed_at=now(),review_note=trim(coalesce(p_review_note,''))
  where id=p_deduction_id;
  perform public.refresh_move_out_settlement(v_case_id);
  update public.move_out_cases set status='settlement_pending' where id=v_case_id;
end $$;
revoke all on function public.review_move_out_deduction(uuid,boolean,text) from public, anon;
grant execute on function public.review_move_out_deduction(uuid,boolean,text) to authenticated;
create or replace function public.record_move_out_settlement_outcome(
  p_case_id uuid,p_refund_method text default null,p_refund_reference text default null,
  p_refund_proof_path text default null,p_shortfall_note text default null
) returns void language plpgsql security definer set search_path = '' as $$
declare
  v_case public.move_out_cases;
  v_settlement public.move_out_settlements;
  v_inspection_status text;
  v_outstanding numeric(12,2);
begin
  if public.current_user_role() is distinct from 'owner'::public.app_role then raise exception 'Owner access required'; end if;
  select * into v_case from public.move_out_cases where id=p_case_id for update;
  if not found then raise exception 'Move-out case not found'; end if;
  if v_case.status in ('cancelled','settlement_completed','ready_for_closure') then
    raise exception 'This move-out case no longer accepts settlement changes';
  end if;
  if v_case.final_inspection_id is null then raise exception 'Final move-out inspection is required before settlement'; end if;
  select status into v_inspection_status from public.room_inspections where id=v_case.final_inspection_id;
  if v_inspection_status<>'completed' then raise exception 'Final move-out inspection must be completed before settlement'; end if;
  if exists(select 1 from public.move_out_clearance_items where case_id=p_case_id and status not in ('cleared','not_applicable')) then
    raise exception 'Every required clearance item must be resolved before settlement';
  end if;
  if exists(select 1 from public.move_out_deductions where case_id=p_case_id and status='proposed') then
    raise exception 'Every proposed deduction must be reviewed before settlement';
  end if;
  select coalesce(sum(remaining_balance),0) into v_outstanding
  from public.billing_charge_summaries
  where tenant_id=v_case.tenant_id and category<>'deposit' and status not in ('verified','voided','upcoming');
  if v_outstanding>0 then raise exception 'Outstanding tenant-payable charges must be cleared before settlement'; end if;

  perform public.refresh_move_out_settlement(p_case_id);
  select * into v_settlement from public.move_out_settlements where case_id=p_case_id for update;
  if v_settlement.refundable_amount>0 then
    if trim(coalesce(p_refund_method,''))='' or trim(coalesce(p_refund_reference,''))='' or trim(coalesce(p_refund_proof_path,''))='' then
      raise exception 'Refund method, reference, and proof are required';
    end if;
    if split_part(p_refund_proof_path,'/',1)<>p_case_id::text
       or not exists(
         select 1 from storage.objects
         where bucket_id='move_out_refund_proofs' and name=p_refund_proof_path
       ) then
      raise exception 'Refund proof must belong to this move-out case';
    end if;
    update public.move_out_settlements set refund_status='refunded',refund_method=trim(p_refund_method),
      refund_reference=trim(p_refund_reference),refund_proof_path=p_refund_proof_path,refunded_at=now(),
      shortfall_note='',updated_by=auth.uid() where case_id=p_case_id;
  elsif v_settlement.shortfall_amount>0 then
    if char_length(trim(coalesce(p_shortfall_note,'')))<3 then raise exception 'Shortfall handoff note is required'; end if;
    update public.move_out_settlements set refund_status='shortfall_pending',shortfall_note=trim(p_shortfall_note),
      refund_method=null,refund_reference=null,refund_proof_path=null,refunded_at=null,updated_by=auth.uid()
    where case_id=p_case_id;
  else
    update public.move_out_settlements set refund_status='settled_zero',shortfall_note='',updated_by=auth.uid()
    where case_id=p_case_id;
  end if;
  update public.move_out_cases set status='settlement_completed' where id=p_case_id;
end $$;
revoke all on function public.record_move_out_settlement_outcome(uuid,text,text,text,text) from public, anon;
grant execute on function public.record_move_out_settlement_outcome(uuid,text,text,text,text) to authenticated;
create or replace function public.acknowledge_move_out_settlement(
  p_case_id uuid,p_response text default ''
) returns void language plpgsql security definer set search_path = '' as $$
declare v_tenant uuid; v_status text;
begin
  select c.tenant_id,s.refund_status into v_tenant,v_status
  from public.move_out_cases c join public.move_out_settlements s on s.case_id=c.id
  where c.id=p_case_id;
  if not found then raise exception 'Move-out settlement not found'; end if;
  if auth.uid()<>v_tenant then raise exception 'Only the tenant may acknowledge this settlement'; end if;
  if v_status not in ('refunded','settled_zero','shortfall_pending') then
    raise exception 'Settlement outcome must be recorded before acknowledgment';
  end if;
  update public.move_out_settlements set tenant_response=trim(coalesce(p_response,'')),
    tenant_acknowledged_at=now(),updated_by=auth.uid() where case_id=p_case_id;
end $$;
revoke all on function public.acknowledge_move_out_settlement(uuid,text) from public, anon;
grant execute on function public.acknowledge_move_out_settlement(uuid,text) to authenticated;
create or replace function public.mark_move_out_ready_for_closure(p_case_id uuid,p_handoff_note text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_case public.move_out_cases; v_inspection_status text; v_outstanding numeric(12,2); v_refund_status text;
begin
  if public.current_user_role() is distinct from 'owner'::public.app_role then raise exception 'Owner access required'; end if;
  select * into v_case from public.move_out_cases where id=p_case_id for update;
  if not found then raise exception 'Move-out case not found'; end if;
  if v_case.status='cancelled' then raise exception 'Cancelled move-out case cannot be closed'; end if;
  if v_case.status='ready_for_closure' then raise exception 'Move-out case is already ready for closure'; end if;
  if v_case.status<>'settlement_completed' then raise exception 'Settlement must be finalized before closure handoff'; end if;
  if v_case.final_inspection_id is null then raise exception 'Final move-out inspection is required'; end if;
  select status into v_inspection_status from public.room_inspections where id=v_case.final_inspection_id;
  if v_inspection_status<>'completed' then raise exception 'Final move-out inspection must be completed'; end if;
  if exists(select 1 from public.move_out_clearance_items where case_id=p_case_id and status not in ('cleared','not_applicable')) then
    raise exception 'Every required clearance item must be resolved';
  end if;
  select coalesce(sum(remaining_balance),0) into v_outstanding
  from public.billing_charge_summaries
  where tenant_id=v_case.tenant_id and category<>'deposit' and status not in ('verified','voided','upcoming');
  if v_outstanding>0 then raise exception 'Outstanding tenant-payable charges must be cleared first'; end if;
  select refund_status into v_refund_status from public.move_out_settlements where case_id=p_case_id;
  if v_refund_status not in ('refunded','settled_zero','shortfall_pending') then raise exception 'Settlement outcome must be recorded'; end if;
  if char_length(trim(coalesce(p_handoff_note,'')))<3 then raise exception 'Closure handoff note is required'; end if;
  update public.move_out_cases set status='ready_for_closure',closure_handoff_note=trim(p_handoff_note)
  where id=p_case_id;
end $$;
revoke all on function public.mark_move_out_ready_for_closure(uuid,text) from public, anon;
grant execute on function public.mark_move_out_ready_for_closure(uuid,text) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('move_out_refund_proofs','move_out_refund_proofs',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create policy move_out_refund_proof_staff_insert on storage.objects
for insert to authenticated with check (
  bucket_id='move_out_refund_proofs' and (select public.current_user_role())='owner'
);
create policy move_out_refund_proof_authorized_select on storage.objects
for select to authenticated using (
  bucket_id='move_out_refund_proofs' and (
    (select public.is_staff()) or exists(
      select 1 from public.move_out_cases c
      where c.id::text=(storage.foldername(name))[1] and c.tenant_id=auth.uid()
    )
  )
);
create policy move_out_refund_proof_owner_delete on storage.objects
for delete to authenticated using (
  bucket_id='move_out_refund_proofs' and (select public.current_user_role())='owner'
);
-- Explicitly no contract / assignment mutation is performed anywhere above.
-- A ready_for_closure case is a handoff boundary for Jorj-reviewed closure integration.

do $$
declare v_table text;
begin
  foreach v_table in array array[
    'move_out_cases','move_out_clearance_items','move_out_deductions','move_out_settlements'
  ] loop
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=v_table) then
      execute format('alter publication supabase_realtime add table public.%I',v_table);
    end if;
  end loop;
end $$;
commit;

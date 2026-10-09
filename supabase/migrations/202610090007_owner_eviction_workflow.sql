-- Owner-issued notices and departure/settlement/closure coordination.
begin;
alter table public.move_out_cases add column case_type text not null default 'voluntary'
  check(case_type in ('voluntary','eviction'));
do $$declare v_constraint text; begin
  for v_constraint in select conname from pg_constraint where conrelid='public.move_out_cases'::regclass
    and contype='c' and pg_get_constraintdef(oid) like '%planned_move_out_on%notice_submitted_on%' loop
    execute format('alter table public.move_out_cases drop constraint %I',v_constraint);
  end loop;
end $$;
alter table public.move_out_cases add constraint move_out_notice_window check(
  (case_type='voluntary' and planned_move_out_on>=notice_submitted_on+30)
  or (case_type='eviction' and planned_move_out_on>=notice_submitted_on));
alter table public.move_out_cases drop constraint move_out_cases_status_check;
alter table public.move_out_cases add constraint move_out_cases_status_check check(status in(
  'notice_submitted','inspection_scheduled','inspection_completed','clearance_review',
  'settlement_pending','settlement_completed','ready_for_closure','closed','cancelled'));
drop index public.move_out_cases_one_active_per_tenant_idx;
create unique index move_out_cases_one_active_per_tenant_idx on public.move_out_cases(tenant_id)
  where status not in ('cancelled','closed');

create table public.eviction_cases (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.profiles(id) on delete restrict,
  contract_id uuid not null references public.tenant_contracts(id) on delete restrict,
  source_assignment_id uuid not null references public.tenant_assignments(id) on delete restrict,
  source_bed_id uuid not null references public.bed_spaces(id) on delete restrict,
  conduct_case_id uuid references public.conduct_cases(id) on delete restrict,
  move_out_case_id uuid unique references public.move_out_cases(id) on delete restrict deferrable initially deferred,
  tenant_name text not null, contract_number text not null, room_number text not null, bed_label text not null,
  owner_name text not null, decision_reason text not null check(char_length(decision_reason) between 10 and 2000),
  notice_on date not null, departure_deadline date not null check(departure_deadline>=notice_on),
  status text not null default 'decision_recorded' check(status in ('decision_recorded','notice_sent','departure_recorded','closed','cancelled')),
  notice_path text, notice_sha256 text check(notice_sha256 ~ '^[a-f0-9]{64}$'), notice_sent_at timestamptz,
  actual_departure_on date, departure_note text, departure_recorded_by uuid references public.profiles(id),
  tenant_response text not null default '' check(char_length(tenant_response)<=2000), tenant_responded_at timestamptz,
  closure_note text, closed_at timestamptz, cancelled_at timestamptz, cancellation_reason text,
  created_by uuid not null references public.profiles(id), created_at timestamptz not null default now()
);
create unique index eviction_one_pending_tenant on public.eviction_cases(tenant_id)
  where status not in ('closed','cancelled');
create table public.eviction_events (
  id uuid primary key default gen_random_uuid(),
  eviction_id uuid not null references public.eviction_cases(id) on delete restrict,
  actor_id uuid references public.profiles(id), snapshot jsonb not null,
  created_at timestamptz not null default now()
);
alter table public.eviction_cases enable row level security;
alter table public.eviction_events enable row level security;
revoke all on public.eviction_cases,public.eviction_events from anon,authenticated;
grant select on public.eviction_cases,public.eviction_events to authenticated;
create or replace function public.can_read_eviction(p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(select 1 from public.eviction_cases e where e.id=p_id
    and (public.is_staff() or (e.notice_path is not null and (e.tenant_id=auth.uid() or public.is_guardian_of(e.tenant_id)))))
$$;
revoke all on function public.can_read_eviction(uuid) from public,anon;
grant execute on function public.can_read_eviction(uuid) to authenticated;
create policy eviction_read on public.eviction_cases for select to authenticated using(public.can_read_eviction(id));
create policy eviction_event_read on public.eviction_events for select to authenticated using(public.can_read_eviction(eviction_id));
create or replace function public.audit_eviction_event()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into public.eviction_events(eviction_id,actor_id,snapshot) values(new.id,auth.uid(),to_jsonb(new));
  return new;
end $$;
create trigger audit_eviction_event after insert or update on public.eviction_cases for each row execute function public.audit_eviction_event();
revoke all on function public.audit_eviction_event() from public,anon,authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('eviction-notices','eviction-notices',false,10485760,array['application/pdf']) on conflict(id) do nothing;
create policy eviction_notice_read on storage.objects for select to authenticated using(
  bucket_id='eviction-notices' and exists(select 1 from public.eviction_cases e
    where e.id::text=(storage.foldername(name))[1] and public.can_read_eviction(e.id)));
create policy eviction_notice_owner_insert on storage.objects for insert to authenticated with check(
  bucket_id='eviction-notices' and public.current_user_role()::text='owner' and exists(select 1 from public.eviction_cases e
    where e.id::text=(storage.foldername(name))[1] and e.status='decision_recorded' and (storage.foldername(name))[2]='notices'));
create or replace function public.eviction_notice_is_registered(p_path text)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.eviction_cases where notice_path=p_path)
$$;
revoke all on function public.eviction_notice_is_registered(text) from public,anon;
grant execute on function public.eviction_notice_is_registered(text) to authenticated;
create policy eviction_notice_cleanup on storage.objects for delete to authenticated using(
  bucket_id='eviction-notices' and owner_id=auth.uid()::text and not public.eviction_notice_is_registered(name));

create or replace function public.check_eviction_conduct_source(p_case_id uuid,p_tenant_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  if p_case_id is null then return; end if;
  perform 1 from public.conduct_cases where id=p_case_id and tenant_id=p_tenant_id and status='termination_review_recommended' for update;
  if not found then raise exception 'Choose this tenant''s termination-review recommendation'; end if;
  if exists(select 1 from public.conduct_case_appeals where case_id=p_case_id and status in ('submitted','under_review','accepted')) then
    raise exception 'Resolve the conduct appeal before using this recommendation for eviction'; end if;
end $$;
revoke all on function public.check_eviction_conduct_source(uuid,uuid) from public,anon,authenticated;

create or replace function public.record_eviction_decision(p_tenant_id uuid,p_deadline date,p_reason text,p_conduct_case_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare c public.tenant_contracts; a public.tenant_assignments; v_id uuid; v_room text; v_bed text;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then raise exception 'Owner access required'; end if;
  select * into c from public.tenant_contracts where tenant_id=p_tenant_id and status='active' for update;
  if not found then raise exception 'An active contract is required'; end if;
  if p_deadline is null or p_deadline<(now() at time zone 'Asia/Manila')::date then raise exception 'Choose today or a later departure deadline'; end if;
  if char_length(btrim(coalesce(p_reason,''))) not between 10 and 2000 then raise exception 'Document the owner decision in 10 to 2000 characters'; end if;
  if exists(select 1 from public.eviction_cases where tenant_id=p_tenant_id and status not in ('closed','cancelled')) then raise exception 'An eviction case is already pending'; end if;
  if exists(select 1 from public.room_transfers where tenant_id=p_tenant_id and status in ('draft','awaiting_signatures'))
    or exists(select 1 from public.tenant_contracts where previous_contract_id=c.id and status='draft')
    or exists(select 1 from public.move_out_cases where tenant_id=p_tenant_id and status not in ('cancelled','closed')) then
    raise exception 'Resolve the pending room transfer, renewal or move-out first'; end if;
  perform public.check_eviction_conduct_source(p_conduct_case_id,p_tenant_id);
  select * into a from public.tenant_assignments where tenant_id=p_tenant_id and status='active' for update;
  if not found then raise exception 'An active room assignment is required'; end if;
  select r.room_number,b.label into v_room,v_bed from public.bed_spaces b join public.rooms r on r.id=b.room_id where b.id=a.bed_space_id;
  insert into public.eviction_cases(tenant_id,contract_id,source_assignment_id,source_bed_id,conduct_case_id,
    tenant_name,contract_number,room_number,bed_label,owner_name,decision_reason,notice_on,departure_deadline,created_by)
  values(p_tenant_id,c.id,a.id,a.bed_space_id,p_conduct_case_id,(select full_name from public.profiles where id=p_tenant_id),
    c.contract_number,v_room,v_bed,(select full_name from public.profiles where id=auth.uid()),btrim(p_reason),
    (now() at time zone 'Asia/Manila')::date,p_deadline,auth.uid()) returning id into v_id;
  return v_id;
end $$;

create or replace function public.publish_eviction_notice(p_id uuid,p_path text,p_sha256 text)
returns void language plpgsql security definer set search_path='' as $$
declare e public.eviction_cases; c public.tenant_contracts; a public.tenant_assignments;
  v_case uuid:=gen_random_uuid(); v_room_id uuid;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then raise exception 'Owner access required'; end if;
  select * into e from public.eviction_cases where id=p_id;
  select * into c from public.tenant_contracts where id=e.contract_id for update;
  select * into e from public.eviction_cases where id=p_id for update;
  if e.id is null then raise exception 'Eviction case not found'; end if;
  if e.status='notice_sent' and e.notice_path=p_path and e.notice_sha256=p_sha256 then return; end if;
  if e.status<>'decision_recorded' then raise exception 'This decision cannot receive a new notice'; end if;
  if c.status<>'active' then raise exception 'The contract is no longer active'; end if;
  if e.notice_on<>(now() at time zone 'Asia/Manila')::date then raise exception 'The draft notice date changed. Cancel and prepare a current notice'; end if;
  perform public.check_eviction_conduct_source(e.conduct_case_id,e.tenant_id);
  select * into a from public.tenant_assignments where id=e.source_assignment_id for update;
  if a.status<>'active' or a.bed_space_id<>e.source_bed_id then raise exception 'The room assignment changed'; end if;
  if p_path is null or p_path not like e.id::text||'/notices/%.pdf' or p_sha256 is null or p_sha256 !~ '^[a-f0-9]{64}$'
    or not exists(select 1 from storage.objects where bucket_id='eviction-notices' and name=p_path
      and metadata->>'mimetype'='application/pdf' and (metadata->>'size')::bigint between 1 and 10485760) then
    raise exception 'Upload the notice PDF first'; end if;
  select room_id into v_room_id from public.bed_spaces where id=e.source_bed_id;
  update public.eviction_cases set status='notice_sent',notice_path=p_path,notice_sha256=p_sha256,
    notice_sent_at=now(),move_out_case_id=v_case where id=e.id;
  insert into public.move_out_cases(id,tenant_id,tenant_name_snapshot,contract_id,contract_number_snapshot,
    contract_ends_on_snapshot,contract_deposit_amount,room_id,room_number_snapshot,bed_label_snapshot,
    notice_submitted_on,planned_move_out_on,reason,refund_due_on,created_by,case_type)
  values(v_case,e.tenant_id,e.tenant_name,c.id,c.contract_number,c.ends_on,c.security_deposit,v_room_id,
    e.room_number,e.bed_label,e.notice_on,e.departure_deadline,left(e.decision_reason,1200),e.departure_deadline+30,auth.uid(),'eviction');
  insert into public.move_out_clearance_items(case_id,item_key,label,sort_order) values
    (v_case,'room_return','Room / key return',1),(v_case,'property_return','Dormitory property return',2),
    (v_case,'account_review','Account and document review',3);
  insert into public.move_out_settlements(case_id,contract_deposit_amount,refund_due_on,updated_by)
    values(v_case,c.security_deposit,e.departure_deadline+30,auth.uid());
  update public.tenant_details set residency_status='moving_out' where profile_id=e.tenant_id;
  perform public.emit_tenant_circle_notification(e.tenant_id,true,true,'system','Owner-issued departure notice',
    'The owner issued a departure notice for Room '||e.room_number||'. Deadline: '||e.departure_deadline::text||
    '. Open the notice to read the reason and record your response.','eviction',e.id,
    jsonb_build_object('eviction_id',e.id),'eviction-notice:'||e.id::text,0);
end $$;

create or replace function public.respond_to_eviction_notice(p_id uuid,p_response text)
returns void language plpgsql security definer set search_path='' as $$
declare e public.eviction_cases;
begin
  select * into e from public.eviction_cases where id=p_id for update;
  if auth.uid() is null or e.tenant_id is distinct from auth.uid() or public.current_user_role()::text is distinct from 'tenant' then raise exception 'Tenant access required'; end if;
  if e.notice_path is null or e.status='cancelled' then raise exception 'No active issued notice is available'; end if;
  if char_length(btrim(coalesce(p_response,''))) not between 3 and 2000 then raise exception 'Enter a response in 3 to 2000 characters'; end if;
  if e.tenant_response=btrim(p_response) then return; end if;
  update public.eviction_cases set tenant_response=btrim(p_response),tenant_responded_at=now() where id=e.id;
  perform public.emit_staff_notification('system','Tenant responded to departure notice',e.tenant_name||' submitted a response.',
    'eviction',e.id,jsonb_build_object('eviction_id',e.id),'eviction-response:'||e.id::text||':'||md5(p_response),0);
end $$;

create or replace function public.record_eviction_departure(p_id uuid,p_departed_on date,p_note text)
returns void language plpgsql security definer set search_path='' as $$
declare e public.eviction_cases;
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then raise exception 'Staff access required'; end if;
  select * into e from public.eviction_cases where id=p_id for update;
  if e.id is null then raise exception 'Eviction case not found'; end if;
  if e.status='departure_recorded' and e.actual_departure_on=p_departed_on and e.departure_note=btrim(p_note) then return; end if;
  if e.status<>'notice_sent' then raise exception 'Publish the notice before recording departure'; end if;
  if p_departed_on is null or p_departed_on<e.notice_on or p_departed_on>(now() at time zone 'Asia/Manila')::date then
    raise exception 'Record the actual departure date, between notice and today'; end if;
  if exists(select 1 from public.tenant_assignments where id=e.source_assignment_id and starts_on>p_departed_on) then
    raise exception 'Departure cannot precede the room assignment'; end if;
  if char_length(btrim(coalesce(p_note,''))) not between 3 and 2000 then raise exception 'Document the departure and key handover'; end if;
  update public.eviction_cases set status='departure_recorded',actual_departure_on=p_departed_on,
    departure_note=btrim(p_note),departure_recorded_by=auth.uid() where id=e.id;
  perform public.emit_staff_notification('system','Eviction departure recorded',e.tenant_name||' departure is recorded; inspection and settlement still need review.',
    'eviction',e.id,jsonb_build_object('eviction_id',e.id),'eviction-departure:'||e.id::text,0);
end $$;

create or replace function public.cancel_eviction_case(p_id uuid,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare e public.eviction_cases;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then raise exception 'Owner access required'; end if;
  select * into e from public.eviction_cases where id=p_id for update;
  if e.id is null then raise exception 'Eviction case not found'; end if;
  if e.status='cancelled' then return; end if;
  if e.status not in ('decision_recorded','notice_sent') then raise exception 'A recorded departure or closed eviction cannot be rescinded'; end if;
  if e.move_out_case_id is not null and exists(select 1 from public.move_out_settlements where case_id=e.move_out_case_id and refund_status<>'pending') then
    raise exception 'A finalized settlement cannot be rescinded'; end if;
  if char_length(btrim(coalesce(p_reason,''))) not between 3 and 1200 then raise exception 'Enter a cancellation reason'; end if;
  update public.eviction_cases set status='cancelled',cancelled_at=now(),cancellation_reason=btrim(p_reason) where id=e.id;
  if e.move_out_case_id is not null then
    update public.move_out_cases set status='cancelled',cancelled_at=now(),cancellation_reason=btrim(p_reason) where id=e.move_out_case_id;
    update public.tenant_details set residency_status='active' where profile_id=e.tenant_id;
    perform public.emit_tenant_circle_notification(e.tenant_id,true,true,'system','Departure notice rescinded',left(btrim(p_reason),400),
      'eviction',e.id,jsonb_build_object('eviction_id',e.id),'eviction-cancel:'||e.id::text,0);
  end if;
end $$;

create or replace function public.close_eviction_case(p_id uuid,p_note text)
returns void language plpgsql security definer set search_path='' as $$
declare e public.eviction_cases; c public.tenant_contracts; a public.tenant_assignments; m public.move_out_cases;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then raise exception 'Owner access required'; end if;
  select * into e from public.eviction_cases where id=p_id;
  select * into c from public.tenant_contracts where id=e.contract_id for update;
  select * into e from public.eviction_cases where id=p_id for update;
  if e.id is null then raise exception 'Eviction case not found'; end if;
  if e.status='closed' then return; end if;
  if e.status<>'departure_recorded' or e.actual_departure_on is null then raise exception 'Record actual departure before closure'; end if;
  if char_length(btrim(coalesce(p_note,''))) not between 3 and 2000 then raise exception 'Enter the owner closure note'; end if;
  select * into m from public.move_out_cases where id=e.move_out_case_id for update;
  if m.id is null or m.status not in ('settlement_completed','ready_for_closure') then raise exception 'Complete inspection, clearance and deposit settlement first'; end if;
  -- Recheck existing financial and clearance gates without reopening history.
  perform public.check_eviction_settlement_ready(m.id);
  select * into a from public.tenant_assignments where id=e.source_assignment_id for update;
  if c.status<>'active' or a.status<>'active' or a.bed_space_id<>e.source_bed_id or a.tenant_id<>e.tenant_id then
    raise exception 'The contract or room assignment changed; review before closure'; end if;
  -- End the matching residence only. Original terms, invoices and evidence stay.
  update public.eviction_cases set status='closed',closed_at=now(),closure_note=btrim(p_note) where id=e.id;
  update public.move_out_cases set status='closed' where id=m.id;
  update public.tenant_contracts set status='terminated' where id=c.id;
  update public.tenant_assignments set status='ended',ends_on=e.actual_departure_on where id=a.id;
  update public.tenant_details set residency_status='inactive' where profile_id=e.tenant_id;
  perform public.emit_tenant_circle_notification(e.tenant_id,true,true,'system','Eviction case closed',
    'Departure, inspection and settlement are recorded. The owner has closed the tenancy and room assignment.',
    'eviction',e.id,jsonb_build_object('eviction_id',e.id),'eviction-closed:'||e.id::text,0);
end $$;

-- Prevent shortcuts through contract editing, room assignment or tenant notices.
create or replace function public.guard_eviction_contract()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from public.eviction_cases where tenant_id=new.tenant_id and status not in ('closed','cancelled')) then
    if tg_op='INSERT' or new.status is distinct from old.status or new.starts_on is distinct from old.starts_on
      or new.ends_on is distinct from old.ends_on or new.monthly_rent is distinct from old.monthly_rent
      or new.security_deposit is distinct from old.security_deposit then raise exception 'Resolve the eviction workflow before changing the contract'; end if;
  end if;
  return new;
end $$;
create trigger guard_eviction_contract before insert or update on public.tenant_contracts for each row execute function public.guard_eviction_contract();
create or replace function public.guard_eviction_assignment()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from public.eviction_cases where source_assignment_id=old.id and status not in ('closed','cancelled'))
    and (new.status is distinct from old.status or new.bed_space_id is distinct from old.bed_space_id or new.tenant_id is distinct from old.tenant_id) then
    raise exception 'Close or rescind the eviction workflow before ending or changing this assignment'; end if;
  return new;
end $$;
create trigger guard_eviction_assignment before update on public.tenant_assignments for each row execute function public.guard_eviction_assignment();
create or replace function public.guard_eviction_move_out()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='INSERT' then
    if new.case_type='eviction' then
      if not exists(select 1 from public.eviction_cases where move_out_case_id=new.id and tenant_id=new.tenant_id
        and contract_id=new.contract_id and status='notice_sent') then raise exception 'Create eviction settlement through the owner notice workflow'; end if;
    elsif exists(select 1 from public.eviction_cases where tenant_id=new.tenant_id
      and (status not in ('closed','cancelled') or (status='closed' and contract_id=new.contract_id))) then
      raise exception 'Use the existing eviction workflow for this tenancy';
    end if;
  else
    if old.status='closed' and to_jsonb(new)-'updated_at' is distinct from to_jsonb(old)-'updated_at' then raise exception 'Closed move-out history is immutable'; end if;
    if new.case_type is distinct from old.case_type then raise exception 'Move-out type cannot be changed'; end if;
    if new.status='cancelled' and old.case_type='eviction' and exists(select 1 from public.eviction_cases where move_out_case_id=old.id and status<>'cancelled') then
      raise exception 'Only the owner can rescind an eviction notice through its workflow'; end if;
  end if;
  return new;
end $$;
create trigger guard_eviction_move_out before insert or update on public.move_out_cases for each row execute function public.guard_eviction_move_out();
create or replace function public.guard_closed_move_out_child()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_case uuid;
begin
  v_case:=case when tg_op='DELETE' then old.case_id else new.case_id end;
  if exists(select 1 from public.move_out_cases where id=v_case and status='closed') then
    -- Late tenant acknowledgement is allowed; financial history stays fixed.
    if tg_table_name='move_out_settlements' and tg_op='UPDATE' and
      to_jsonb(new)-array['tenant_response','tenant_acknowledged_at','updated_at','updated_by']
      =to_jsonb(old)-array['tenant_response','tenant_acknowledged_at','updated_at','updated_by'] then return new; end if;
    raise exception 'Closed move-out settlement history is immutable';
  end if;
  return case when tg_op='DELETE' then old else new end;
end $$;
create trigger guard_closed_clearance before insert or update or delete on public.move_out_clearance_items for each row execute function public.guard_closed_move_out_child();
create trigger guard_closed_deduction before insert or update or delete on public.move_out_deductions for each row execute function public.guard_closed_move_out_child();
create trigger guard_closed_settlement before insert or update or delete on public.move_out_settlements for each row execute function public.guard_closed_move_out_child();
create or replace function public.guard_closed_eviction_inspection()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from public.move_out_cases where final_inspection_id=old.id and status='closed')
    and to_jsonb(new)-'updated_at' is distinct from to_jsonb(old)-'updated_at' then
    raise exception 'Closed eviction inspection history is immutable'; end if;
  return new;
end $$;
create trigger guard_closed_eviction_inspection before update on public.room_inspections for each row execute function public.guard_closed_eviction_inspection();
revoke all on function public.guard_closed_eviction_inspection() from public,anon,authenticated;
create or replace function public.guard_closed_eviction_refund_proof()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if old.bucket_id='move_out_refund_proofs' and exists(select 1 from public.move_out_settlements s
      join public.move_out_cases c on c.id=s.case_id where c.status='closed' and s.refund_proof_path=old.name) then
    raise exception 'Closed eviction refund evidence is immutable'; end if;
  return old;
end $$;
create trigger guard_closed_eviction_refund_proof before delete on storage.objects for each row execute function public.guard_closed_eviction_refund_proof();
revoke all on function public.guard_closed_eviction_refund_proof() from public,anon,authenticated;
create or replace function public.guard_eviction_room_transfer()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from public.eviction_cases where tenant_id=new.tenant_id and status not in ('closed','cancelled')) then raise exception 'Resolve the eviction workflow before proposing a room transfer'; end if;
  return new;
end $$;
create trigger guard_eviction_room_transfer before insert on public.room_transfers for each row execute function public.guard_eviction_room_transfer();

revoke all on function public.record_eviction_decision(uuid,date,text,uuid),public.publish_eviction_notice(uuid,text,text),
  public.respond_to_eviction_notice(uuid,text),public.record_eviction_departure(uuid,date,text),public.cancel_eviction_case(uuid,text),public.close_eviction_case(uuid,text) from public,anon;
grant execute on function public.record_eviction_decision(uuid,date,text,uuid),public.publish_eviction_notice(uuid,text,text),
  public.respond_to_eviction_notice(uuid,text),public.record_eviction_departure(uuid,date,text),public.cancel_eviction_case(uuid,text),public.close_eviction_case(uuid,text) to authenticated;
revoke all on function public.guard_eviction_contract(),public.guard_eviction_assignment(),public.guard_eviction_move_out(),
  public.guard_closed_move_out_child(),public.guard_eviction_room_transfer() from public,anon,authenticated;
do $$declare v_table text; begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    foreach v_table in array array['eviction_cases','eviction_events'] loop
      if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=v_table) then
        execute format('alter publication supabase_realtime add table public.%I',v_table);
      end if;
    end loop;
  end if;
end $$;
-- Existing voluntary creation is updated below to recognize closed history.

create or replace function public.check_eviction_settlement_ready(p_case_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_case public.move_out_cases; v_inspection_status text; v_outstanding numeric(12,2); v_refund_status text;
begin
  if public.current_user_role() is distinct from 'owner'::public.app_role then raise exception 'Owner access required'; end if;
  select * into v_case from public.move_out_cases where id=p_case_id for update;
  if not found then raise exception 'Move-out case not found'; end if;
  if v_case.status='cancelled' then raise exception 'Cancelled move-out case cannot be closed'; end if;
  if v_case.status not in ('settlement_completed','ready_for_closure') then raise exception 'Settlement must be finalized before closure handoff'; end if;
  if v_case.final_inspection_id is null then raise exception 'Final move-out inspection is required'; end if;
  select status into v_inspection_status from public.room_inspections where id=v_case.final_inspection_id for update;
  if v_inspection_status<>'completed' then raise exception 'Final move-out inspection must be completed'; end if;
  perform 1 from public.move_out_clearance_items where case_id=p_case_id order by id for update;
  if exists(select 1 from public.move_out_clearance_items where case_id=p_case_id and status not in ('cleared','not_applicable')) then
    raise exception 'Every required clearance item must be resolved';
  end if;
  perform 1 from public.billing_charges where tenant_id=v_case.tenant_id order by id for update;
  if exists(select 1 from public.payment_transactions p join public.billing_charges b on b.id=p.charge_id
      where b.tenant_id=v_case.tenant_id and p.status='pending_verification')
    or exists(select 1 from public.paymongo_payment_sessions p join public.billing_charges b on b.id=p.charge_id
      where b.tenant_id=v_case.tenant_id and p.status in ('creating','pending','needs_review')) then
    raise exception 'Resolve pending payment proofs and gateway requests before eviction closure'; end if;
  select coalesce(sum(remaining_balance),0) into v_outstanding
  from public.billing_charge_summaries
  where tenant_id=v_case.tenant_id and category<>'deposit' and status not in ('verified','voided')
    and (category<>'rent' or due_date<=(now() at time zone 'Asia/Manila')::date);
  if v_outstanding>0 then raise exception 'Outstanding tenant-payable charges must be cleared first'; end if;
  select refund_status into v_refund_status from public.move_out_settlements where case_id=p_case_id for update;
  if v_refund_status not in ('refunded','settled_zero','shortfall_pending') then raise exception 'Settlement outcome must be recorded'; end if;
end $$;
revoke all on function public.check_eviction_settlement_ready(uuid) from public,anon,authenticated;

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
  if exists(select 1 from public.move_out_cases where tenant_id=p_tenant_id and status not in ('cancelled','closed')) then
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
-- Closed eviction history does not block transfers in a later tenancy.
create or replace function public.propose_room_transfer(p_tenant_id uuid,p_bed_id uuid,p_effective_on date,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare c public.tenant_contracts; a public.tenant_assignments; b public.bed_spaces;
  r public.rooms; v_id uuid; v_source_room text; v_source_bed text; v_guardian uuid;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then raise exception 'Owner access required'; end if;
  select * into c from public.tenant_contracts where tenant_id=p_tenant_id and status='active' for update;
  if not found then raise exception 'An active signed contract is required for a room amendment'; end if;
  if c.signature_status<>'verified' then raise exception 'Verify the original contract signatures first'; end if;
  if p_effective_on is null or p_effective_on<(now() at time zone 'Asia/Manila')::date
    or p_effective_on not between c.starts_on and c.ends_on then raise exception 'Choose a date within the active contract, today or later'; end if;
  if char_length(btrim(coalesce(p_reason,''))) not between 3 and 1500 then raise exception 'Document the reason for the room transfer'; end if;
  if exists(select 1 from public.room_transfers where tenant_id=p_tenant_id and status in ('draft','awaiting_signatures')) then
    raise exception 'A room transfer is already pending. Review or cancel it first'; end if;
  if exists(select 1 from public.move_out_cases where tenant_id=p_tenant_id and status<>'cancelled'
      and (contract_id=c.id or status not in ('settlement_completed','ready_for_closure','closed')))
    or exists(select 1 from public.tenant_contracts where previous_contract_id=c.id and status='draft') then
    raise exception 'Resolve the move-out or pending renewal before proposing a room transfer'; end if;
  select * into a from public.tenant_assignments where tenant_id=p_tenant_id and status='active' for update;
  if not found then raise exception 'An active room assignment is required'; end if;
  if a.bed_space_id=p_bed_id then raise exception 'Choose a different bed'; end if;
  select * into b from public.bed_spaces where id=p_bed_id for update;
  if not found or b.status<>'available' or exists(select 1 from public.tenant_assignments where bed_space_id=p_bed_id and status='active') then
    raise exception 'The destination bed is unavailable'; end if;
  select * into r from public.rooms where id=b.room_id for update;
  if r.is_active is not true then raise exception 'Archived rooms cannot receive transfers'; end if;
  select rm.room_number,bs.label into v_source_room,v_source_bed from public.bed_spaces bs
    join public.rooms rm on rm.id=bs.room_id where bs.id=a.bed_space_id;
  update public.bed_spaces set status='reserved' where id=b.id;
  insert into public.room_transfers(contract_id,tenant_id,source_assignment_id,source_bed_id,destination_bed_id,
    source_room,source_bed,destination_room,destination_bed,tenant_name,contract_number,
    starts_on,ends_on,monthly_rent,security_deposit,effective_on,reason,created_by)
  values(c.id,p_tenant_id,a.id,a.bed_space_id,b.id,v_source_room,v_source_bed,r.room_number,b.label,
    (select full_name from public.profiles where id=p_tenant_id),c.contract_number,c.starts_on,c.ends_on,
    c.monthly_rent,c.security_deposit,p_effective_on,btrim(p_reason),auth.uid()) returning id into v_id;
  insert into public.room_transfer_signers(transfer_id,signer_role,signer_user_id)
    values(v_id,'tenant',p_tenant_id),(v_id,'lessor',auth.uid());
  select guardian_id into v_guardian from public.guardian_tenant_links where tenant_id=p_tenant_id
    order by is_primary desc,created_at,id limit 1;
  insert into public.room_transfer_signers(transfer_id,signer_role,signer_user_id)
    select v_id,signer_role,case when signer_role='guardian' then v_guardian else null end
    from public.contract_signers where contract_id=c.id and is_required and signer_role in ('guardian','witness');
  return v_id;
end $$;
notify pgrst,'reload schema';
commit;

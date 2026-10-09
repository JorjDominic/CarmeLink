-- Room amendments preserve the original lease, its price and deposit.
begin;
create table public.room_transfers (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.tenant_contracts(id) on delete restrict,
  tenant_id uuid not null references public.profiles(id) on delete restrict,
  source_assignment_id uuid not null references public.tenant_assignments(id) on delete restrict,
  source_bed_id uuid not null references public.bed_spaces(id) on delete restrict,
  destination_bed_id uuid not null references public.bed_spaces(id) on delete restrict,
  source_room text not null, source_bed text not null,
  destination_room text not null, destination_bed text not null,
  tenant_name text not null, contract_number text not null,
  starts_on date not null, ends_on date not null,
  monthly_rent numeric(12,2) not null, security_deposit numeric(12,2) not null,
  effective_on date not null, reason text not null check(char_length(reason) between 3 and 1500),
  status text not null default 'draft' check(status in ('draft','awaiting_signatures','completed','cancelled')),
  document_path text, document_sha256 text check(document_sha256 ~ '^[a-f0-9]{64}$'),
  resulting_assignment_id uuid unique,
  created_by uuid not null references public.profiles(id), created_at timestamptz not null default now(),
  completed_at timestamptz, cancelled_at timestamptz, cancellation_reason text,
  check(source_bed_id<>destination_bed_id), check(effective_on between starts_on and ends_on)
);
create unique index room_transfers_one_pending_tenant on public.room_transfers(tenant_id)
  where status in ('draft','awaiting_signatures');
create unique index room_transfers_one_reserved_bed on public.room_transfers(destination_bed_id)
  where status in ('draft','awaiting_signatures');
create table public.room_transfer_signers (
  id uuid primary key default gen_random_uuid(),
  transfer_id uuid not null references public.room_transfers(id) on delete restrict,
  signer_role text not null check(signer_role in ('lessor','tenant','guardian','witness')),
  signer_user_id uuid references public.profiles(id) on delete restrict,
  status text not null default 'pending' check(status in ('pending','signed','verified','rejected')),
  signer_name text, signature_path text, signature_sha256 text check(signature_sha256 ~ '^[a-f0-9]{64}$'),
  accepted_document_sha256 text, signed_at timestamptz, reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz, review_note text, unique(transfer_id,signer_role)
);
alter table public.room_transfers enable row level security;
alter table public.room_transfer_signers enable row level security;
create table public.room_transfer_signature_events (
  id uuid primary key default gen_random_uuid(),
  transfer_id uuid not null references public.room_transfers(id) on delete restrict,
  signer_id uuid not null references public.room_transfer_signers(id) on delete restrict,
  snapshot jsonb not null, created_at timestamptz not null default now()
);
alter table public.room_transfer_signature_events enable row level security;
revoke all on public.room_transfers,public.room_transfer_signers from anon,authenticated;
grant select on public.room_transfers,public.room_transfer_signers to authenticated;
revoke all on public.room_transfer_signature_events from anon,authenticated;
grant select on public.room_transfer_signature_events to authenticated;

create or replace function public.can_read_room_transfer(p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and exists(select 1 from public.room_transfers t where t.id=p_id
    and (public.is_staff() or t.tenant_id=auth.uid() or public.is_guardian_of(t.tenant_id)))
$$;
revoke all on function public.can_read_room_transfer(uuid) from public,anon;
grant execute on function public.can_read_room_transfer(uuid) to authenticated;
create policy room_transfer_read on public.room_transfers for select to authenticated
  using(public.can_read_room_transfer(id));
create policy room_transfer_signer_read on public.room_transfer_signers for select to authenticated
  using(public.can_read_room_transfer(transfer_id));
create policy room_transfer_signature_event_read on public.room_transfer_signature_events for select to authenticated
  using(public.can_read_room_transfer(transfer_id));
create or replace function public.audit_room_transfer_signature()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into public.room_transfer_signature_events(transfer_id,signer_id,snapshot)
    values(new.transfer_id,new.id,to_jsonb(new));
  return new;
end $$;
create trigger audit_room_transfer_signature after update of status on public.room_transfer_signers
  for each row execute function public.audit_room_transfer_signature();
revoke all on function public.audit_room_transfer_signature() from public,anon,authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('room-amendments','room-amendments',false,10485760,array['application/pdf','image/png','image/jpeg'])
on conflict(id) do nothing;
create policy room_amendment_read on storage.objects for select to authenticated using(
  bucket_id='room-amendments' and exists(select 1 from public.room_transfers t
    where t.id::text=(storage.foldername(name))[1] and public.can_read_room_transfer(t.id)));
create policy room_amendment_insert on storage.objects for insert to authenticated with check(
  bucket_id='room-amendments' and exists(select 1 from public.room_transfers t
    where t.id::text=(storage.foldername(name))[1] and (
      (public.current_user_role()::text='owner' and t.status='draft' and (storage.foldername(name))[2]='documents')
      or (t.status='awaiting_signatures' and (storage.foldername(name))[2]='signatures'
        and exists(select 1 from public.room_transfer_signers s where s.transfer_id=t.id
          and s.status in ('pending','rejected') and (storage.filename(name)) like s.signer_role||'-%'
          and (s.signer_user_id=auth.uid() or (public.current_user_role()::text='owner'
            and s.signer_role in ('lessor','guardian','witness'))))))));
-- Check evidence independently of participant RLS, including former guardians
-- who no longer have permission to read the amendment after unlinking.
create or replace function public.room_amendment_file_is_registered(p_path text)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.room_transfers where document_path=p_path)
    or exists(select 1 from public.room_transfer_signers where signature_path=p_path)
    or exists(select 1 from public.room_transfer_signature_events where snapshot->>'signature_path'=p_path)
$$;
revoke all on function public.room_amendment_file_is_registered(text) from public,anon;
grant execute on function public.room_amendment_file_is_registered(text) to authenticated;
create policy room_amendment_unregistered_cleanup on storage.objects for delete to authenticated using(
  bucket_id='room-amendments' and owner_id=auth.uid()::text
  and not public.room_amendment_file_is_registered(name));

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
      and (contract_id=c.id or status not in ('settlement_completed','ready_for_closure')))
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

create or replace function public.publish_room_transfer(p_id uuid,p_path text,p_sha256 text)
returns void language plpgsql security definer set search_path='' as $$
declare t public.room_transfers;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then raise exception 'Owner access required'; end if;
  select * into t from public.room_transfers where id=p_id for update;
  if not found then raise exception 'Room transfer not found'; end if;
  if t.status='awaiting_signatures' and t.document_path=p_path and t.document_sha256=p_sha256 then return; end if;
  if t.status<>'draft' then raise exception 'This amendment can no longer be changed'; end if;
  if p_path is null or p_path not like t.id::text||'/documents/%.pdf' or p_sha256 is null or p_sha256 !~ '^[a-f0-9]{64}$'
    or not exists(select 1 from storage.objects where bucket_id='room-amendments' and name=p_path
      and metadata->>'mimetype'='application/pdf' and (metadata->>'size')::bigint between 1 and 10485760) then
    raise exception 'Upload the amendment PDF before sending notice'; end if;
  update public.room_transfers set document_path=p_path,document_sha256=p_sha256,status='awaiting_signatures' where id=t.id;
  perform public.emit_tenant_circle_notification(t.tenant_id,true,true,'system','Room transfer proposed',
    'Proposed move from Room '||t.source_room||' to Room '||t.destination_room||' on '||t.effective_on::text||
    '. Review and sign the room amendment. Your current assignment stays active.',
    'room_transfer',t.id,jsonb_build_object('transfer_id',t.id),'room-transfer-notice:'||t.id::text,0);
end $$;

create or replace function public.sign_room_transfer(p_id uuid,p_role text,p_path text,p_sha256 text,p_document_sha256 text,p_signer_name text default null)
returns void language plpgsql security definer set search_path='' as $$
declare t public.room_transfers; s public.room_transfer_signers; v_owner boolean; v_name text;
begin
  v_owner:=public.current_user_role()::text='owner';
  select * into t from public.room_transfers where id=p_id for update;
  select * into s from public.room_transfer_signers where transfer_id=p_id and signer_role=p_role for update;
  if auth.uid() is null or s.id is null or not coalesce(s.signer_user_id=auth.uid()
      or (v_owner and p_role in ('lessor','guardian','witness')),false) then raise exception 'Signer access denied'; end if;
  if p_role='guardian' and not v_owner and not public.is_guardian_of(t.tenant_id) then raise exception 'Guardian link is no longer active'; end if;
  if t.status<>'awaiting_signatures' or s.status not in ('pending','rejected') then raise exception 'This signature is no longer editable'; end if;
  if p_document_sha256 is distinct from t.document_sha256 then raise exception 'Review the current amendment before signing'; end if;
  if p_path is null or p_path not like t.id::text||'/signatures/'||p_role||'-%' or p_sha256 is null or p_sha256 !~ '^[a-f0-9]{64}$'
    or not exists(select 1 from storage.objects where bucket_id='room-amendments' and name=p_path
      and metadata->>'mimetype' in ('image/png','image/jpeg') and (metadata->>'size')::bigint between 1 and 2097152) then
    raise exception 'Upload a signature image of at most 2 MB'; end if;
  v_name:=case when v_owner and p_role in ('guardian','witness') then btrim(p_signer_name)
    else (select full_name from public.profiles where id=auth.uid()) end;
  if v_name is null or char_length(v_name) not between 2 and 160 then raise exception 'Enter the actual signer name'; end if;
  update public.room_transfer_signers set status=case when v_owner then 'verified' else 'signed' end,
    signer_name=v_name,signature_path=p_path,signature_sha256=p_sha256,accepted_document_sha256=t.document_sha256,
    signed_at=now(),reviewed_by=case when v_owner then auth.uid() else null end,
    reviewed_at=case when v_owner then now() else null end,
    review_note=case when v_owner and p_role in ('guardian','witness') then 'Signed copy recorded and verified by owner' else null end
  where id=s.id;
  if not v_owner then perform public.emit_staff_notification('system','Room amendment signature submitted',
    t.tenant_name||' room amendment needs owner review.','room_transfer',t.id,
    jsonb_build_object('transfer_id',t.id),'room-transfer-signature:'||s.id::text||':'||p_sha256,0); end if;
end $$;

create or replace function public.review_room_transfer_signature(p_signer_id uuid,p_approve boolean,p_note text)
returns void language plpgsql security definer set search_path='' as $$
declare s public.room_transfer_signers; t public.room_transfers;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then raise exception 'Owner access required'; end if;
  select * into s from public.room_transfer_signers where id=p_signer_id;
  select * into t from public.room_transfers where id=s.transfer_id for update;
  select * into s from public.room_transfer_signers where id=p_signer_id for update;
  if t.id is null or t.status<>'awaiting_signatures' or s.status<>'signed' or p_approve is null then raise exception 'Signature is not pending review'; end if;
  if char_length(btrim(coalesce(p_note,''))) not between 3 and 1500 then raise exception 'Enter a signature review note'; end if;
  update public.room_transfer_signers set status=case when p_approve then 'verified' else 'rejected' end,
    reviewed_by=auth.uid(),reviewed_at=now(),review_note=btrim(p_note) where id=s.id;
  perform public.emit_tenant_circle_notification(t.tenant_id,true,true,'system','Room amendment signature reviewed',
    case when p_approve then 'Signature accepted. The move still needs owner confirmation on the agreed date.'
      else 'Signature rejected: '||left(btrim(p_note),350)||'. Please review and sign again.' end,
    'room_transfer',t.id,jsonb_build_object('transfer_id',t.id),'room-transfer-review:'||s.id::text||':'||s.signature_sha256,0);
end $$;

create or replace function public.cancel_room_transfer(p_id uuid,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare t public.room_transfers;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then raise exception 'Owner access required'; end if;
  select * into t from public.room_transfers where id=p_id for update;
  if not found then raise exception 'Room transfer not found'; end if;
  if t.status='cancelled' then return; end if;
  if t.status='completed' then raise exception 'Completed transfers cannot be cancelled'; end if;
  if char_length(btrim(coalesce(p_reason,''))) not between 3 and 1500 then raise exception 'Enter a cancellation reason'; end if;
  update public.room_transfers set status='cancelled',cancelled_at=now(),cancellation_reason=btrim(p_reason) where id=t.id;
  update public.bed_spaces set status='available' where id=t.destination_bed_id and status='reserved';
  if t.document_path is not null then perform public.emit_tenant_circle_notification(t.tenant_id,true,true,'system','Room transfer cancelled',
    left(btrim(p_reason),350)||'. Your current room remains unchanged.','room_transfer',t.id,
    jsonb_build_object('transfer_id',t.id),'room-transfer-cancel:'||t.id::text,0); end if;
end $$;

create or replace function public.complete_room_transfer(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare t public.room_transfers; c public.tenant_contracts; a public.tenant_assignments; b public.bed_spaces;
  v_assignment uuid:=gen_random_uuid(); v_room_active boolean;
begin
  if auth.uid() is null or public.current_user_role()::text is distinct from 'owner' then raise exception 'Owner access required'; end if;
  -- Contract then transfer matches proposal ordering and renewal's contract lock.
  select * into t from public.room_transfers where id=p_id;
  select * into c from public.tenant_contracts where id=t.contract_id for update;
  select * into t from public.room_transfers where id=p_id for update;
  if t.id is null then raise exception 'Room transfer not found'; end if;
  if t.status='completed' then return; end if;
  if t.status<>'awaiting_signatures' or t.document_path is null then raise exception 'Send the amendment notice and collect signatures first'; end if;
  if (now() at time zone 'Asia/Manila')::date<t.effective_on then raise exception 'The agreed transfer date has not arrived'; end if;
  if c.status<>'active' or c.signature_status<>'verified' or (now() at time zone 'Asia/Manila')::date>c.ends_on
    or c.starts_on<>t.starts_on or c.ends_on<>t.ends_on
    or c.monthly_rent<>t.monthly_rent or c.security_deposit<>t.security_deposit then raise exception 'The original contract changed or ended; cancel and review this proposal'; end if;
  if exists(select 1 from public.contract_signers s where s.contract_id=c.id and s.is_required
    and not exists(select 1 from public.room_transfer_signers amendment_signer where amendment_signer.transfer_id=t.id and amendment_signer.signer_role=s.signer_role)) then
    raise exception 'Required contract signers changed; cancel and prepare a new amendment'; end if;
  if exists(select 1 from public.room_transfer_signers where transfer_id=t.id
      and (status<>'verified' or accepted_document_sha256 is distinct from t.document_sha256)) then
    raise exception 'Every required amendment signature must be verified before the move'; end if;
  select * into a from public.tenant_assignments where id=t.source_assignment_id for update;
  if a.status<>'active' or a.tenant_id<>t.tenant_id or a.bed_space_id<>t.source_bed_id then raise exception 'The current assignment changed; cancel and review the transfer'; end if;
  select * into b from public.bed_spaces where id=t.destination_bed_id for update;
  select is_active into v_room_active from public.rooms where id=b.room_id for update;
  if b.status<>'reserved' or not v_room_active or exists(select 1 from public.tenant_assignments where bed_space_id=b.id and status='active') then
    raise exception 'The reserved destination is no longer available'; end if;
  update public.room_transfers set status='completed',completed_at=now(),resulting_assignment_id=v_assignment where id=t.id;
  update public.tenant_assignments set status='ended',ends_on=(now() at time zone 'Asia/Manila')::date where id=a.id;
  update public.bed_spaces set status='available' where id=b.id;
  insert into public.tenant_assignments(id,tenant_id,bed_space_id,starts_on) values(v_assignment,t.tenant_id,b.id,(now() at time zone 'Asia/Manila')::date);
  update public.tenant_details set residency_status='active' where profile_id=t.tenant_id;
  perform public.emit_tenant_circle_notification(t.tenant_id,true,true,'system','Room transfer completed',
    'Your assignment is now Room '||t.destination_room||' / '||t.destination_bed||'. Signed rent and deposit remain unchanged.',
    'room_transfer',t.id,jsonb_build_object('transfer_id',t.id),'room-transfer-complete:'||t.id::text,0);
end $$;

-- Enforce the signing requirement for legacy RPCs and direct staff writes too.
create or replace function public.guard_signed_room_assignment()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='DELETE' then
    if exists(select 1 from public.tenant_contracts where tenant_id=old.tenant_id and status='active') then
      raise exception 'Keep assignment history for the active contract'; end if;
    return old;
  end if;
  if tg_op='UPDATE' then
    if (new.bed_space_id is distinct from old.bed_space_id or new.tenant_id is distinct from old.tenant_id)
      and exists(select 1 from public.tenant_contracts where tenant_id in (old.tenant_id,new.tenant_id) and status='active') then
      raise exception 'Use a signed room amendment before changing the assignment'; end if;
    if old.status='active' and new.status<>'active' and exists(select 1 from public.room_transfers
      where source_assignment_id=old.id and status in ('draft','awaiting_signatures')) then
      raise exception 'Cancel or complete the pending room amendment first'; end if;
  end if;
  if new.status='active' and (tg_op='INSERT' or old.status<>'active') then
    perform 1 from public.bed_spaces where id=new.bed_space_id for update;
    if exists(select 1 from public.room_transfers where destination_bed_id=new.bed_space_id and status in ('draft','awaiting_signatures')) then
      raise exception 'This bed is reserved for a pending room amendment'; end if;
    if exists(select 1 from public.tenant_contracts where tenant_id=new.tenant_id and status='active')
      and exists(select 1 from public.tenant_assignments where tenant_id=new.tenant_id)
      and not exists(select 1 from public.room_transfers where status='completed' and resulting_assignment_id=new.id
        and tenant_id=new.tenant_id and destination_bed_id=new.bed_space_id) then
      raise exception 'Use a signed room amendment before changing the assignment'; end if;
  end if;
  return new;
end $$;
create trigger guard_signed_room_assignment before insert or update or delete on public.tenant_assignments
  for each row execute function public.guard_signed_room_assignment();

create or replace function public.guard_room_transfer_reservation()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from public.room_transfers where status in ('draft','awaiting_signatures')
      and old.id in (source_bed_id,destination_bed_id)) then
    raise exception 'Cancel or complete the room amendment before changing these bed details'; end if;
  return new;
end $$;
create trigger guard_room_transfer_reservation before update of status,label,room_id on public.bed_spaces
  for each row when(old.status is distinct from new.status or old.label is distinct from new.label or old.room_id is distinct from new.room_id)
  execute function public.guard_room_transfer_reservation();

create or replace function public.guard_room_transfer_room()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from public.room_transfers t join public.bed_spaces b
      on b.id in (t.source_bed_id,t.destination_bed_id)
      where b.room_id=old.id and t.status in ('draft','awaiting_signatures')) then
    raise exception 'Cancel or complete the room amendment before renaming or archiving this room'; end if;
  return new;
end $$;
create trigger guard_room_transfer_room before update of room_number,is_active on public.rooms
  for each row when(old.room_number is distinct from new.room_number or old.is_active is distinct from new.is_active)
  execute function public.guard_room_transfer_room();

create or replace function public.guard_room_transfer_contract()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from public.room_transfers where contract_id=old.id and status in ('draft','awaiting_signatures')) then
    raise exception 'Cancel or complete the pending room amendment before changing the contract'; end if;
  return new;
end $$;
create trigger guard_room_transfer_contract before update of status,starts_on,ends_on,monthly_rent,security_deposit on public.tenant_contracts
  for each row when(old.status is distinct from new.status or old.starts_on is distinct from new.starts_on or old.ends_on is distinct from new.ends_on
    or old.monthly_rent is distinct from new.monthly_rent or old.security_deposit is distinct from new.security_deposit)
  execute function public.guard_room_transfer_contract();

create or replace function public.guard_room_transfer_move_out()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from public.room_transfers where tenant_id=new.tenant_id and status in ('draft','awaiting_signatures')) then
    raise exception 'Cancel or complete the pending room amendment before starting move-out'; end if;
  return new;
end $$;
create trigger guard_room_transfer_move_out before insert on public.move_out_cases
  for each row execute function public.guard_room_transfer_move_out();

revoke all on function public.propose_room_transfer(uuid,uuid,date,text),public.publish_room_transfer(uuid,text,text),
  public.sign_room_transfer(uuid,text,text,text,text,text),public.review_room_transfer_signature(uuid,boolean,text),
  public.cancel_room_transfer(uuid,text),public.complete_room_transfer(uuid) from public,anon;
grant execute on function public.propose_room_transfer(uuid,uuid,date,text),public.publish_room_transfer(uuid,text,text),
  public.sign_room_transfer(uuid,text,text,text,text,text),public.review_room_transfer_signature(uuid,boolean,text),
  public.cancel_room_transfer(uuid,text),public.complete_room_transfer(uuid) to authenticated;
revoke all on function public.guard_signed_room_assignment(),public.guard_room_transfer_reservation(),
  public.guard_room_transfer_room(),public.guard_room_transfer_contract(),public.guard_room_transfer_move_out() from public,anon,authenticated;
do $$declare v_table text; begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    foreach v_table in array array['room_transfers','room_transfer_signers'] loop
      if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=v_table) then
        execute format('alter publication supabase_realtime add table public.%I',v_table);
      end if;
    end loop;
  end if;
end $$;
notify pgrst,'reload schema';
commit;

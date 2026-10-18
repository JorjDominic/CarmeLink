begin;
create policy payment_receipt_guardian_read on public.payment_receipts for select to authenticated
using (public.current_user_role()::text='guardian' and exists (
  select 1 from public.guardian_tenant_links g where g.guardian_id=auth.uid() and g.tenant_id=payment_receipts.tenant_id));
create or replace function public.get_payment_receipt(p_transaction_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare t public.payment_transactions; r public.payment_receipts;
begin
  select * into t from public.payment_transactions where id=p_transaction_id;
  if not found or not (coalesce(auth.role(),'')='service_role' or
    (auth.uid() is not null and (coalesce(public.is_staff(),false) or
      (t.tenant_id=auth.uid() and public.current_user_role()::text='tenant') or
      (public.current_user_role()::text='guardian' and exists(select 1 from public.guardian_tenant_links g
        where g.guardian_id=auth.uid() and g.tenant_id=t.tenant_id))))) then
    raise exception 'Payment receipt not available';
  end if;
  r:=public.create_payment_receipt_snapshot(t.id);
  return to_jsonb(r);
end $$;
-- Actual paper receipt numbers are separate from immutable PAY-* snapshots.
create table public.issued_payment_receipts (
  id uuid primary key,
  transaction_id uuid not null references public.payment_receipts(id),
  receipt_number text not null check (length(btrim(receipt_number)) between 1 and 80),
  number_key text generated always as (upper(regexp_replace(receipt_number,'\s','','g'))) stored,
  environment text not null check (environment in ('test','live')),
  issued_on date not null,
  issued_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  photo_path text,
  status text not null default 'issued' check (status in ('issued','voided')),
  void_reason text,
  voided_by uuid references public.profiles(id),
  voided_at timestamptz,
  replaces_id uuid references public.issued_payment_receipts(id),
  unique(environment,number_key),
  check ((status='issued' and void_reason is null and voided_by is null and voided_at is null)
    or (status='voided' and length(btrim(void_reason)) between 3 and 500 and voided_by is not null and voided_at is not null))
);
create unique index one_active_issued_receipt on public.issued_payment_receipts(transaction_id) where status='issued';
alter table public.issued_payment_receipts enable row level security;
create policy issued_receipt_read on public.issued_payment_receipts for select to authenticated
using (exists(select 1 from public.payment_receipts p where p.id=transaction_id));
revoke all on public.issued_payment_receipts from anon,authenticated,service_role;
grant select on public.issued_payment_receipts to authenticated,service_role;

create function public.protect_issued_payment_receipt() returns trigger
language plpgsql set search_path='' as $$
begin
  if tg_op='UPDATE' then
    if old.status='issued' and new.status='voided' and
      (to_jsonb(old)-array['status','void_reason','voided_by','voided_at','number_key']) =
      (to_jsonb(new)-array['status','void_reason','voided_by','voided_at','number_key']) then return new; end if;
  end if;
  raise exception 'Issued receipt history cannot be edited or deleted';
end $$;
create trigger issued_receipt_history before update or delete on public.issued_payment_receipts
for each row execute function public.protect_issued_payment_receipt();

create function public.record_issued_payment_receipt(p_id uuid,p_transaction_id uuid,
  p_number text,p_issued_on date,p_photo_path text default null)
returns public.issued_payment_receipts language plpgsql security definer set search_path='' as $$
declare r public.issued_payment_receipts; s public.payment_receipts; replacement uuid; env text;
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then raise exception 'Staff access required'; end if;
  perform 1 from public.payment_transactions where id=p_transaction_id and status='verified' for update;
  if not found then raise exception 'A verified payment is required'; end if;
  s:=public.create_payment_receipt_snapshot(p_transaction_id);
  env:=case when s.environment='test' then 'test' else 'live' end;
  select * into r from public.issued_payment_receipts where id=p_id;
  if found then
    if r.transaction_id=p_transaction_id and r.receipt_number=btrim(p_number)
      and r.issued_on=p_issued_on and r.photo_path is not distinct from p_photo_path
      and r.issued_by=auth.uid() then return r; end if;
    raise exception 'This request was already used for a different receipt';
  end if;
  if p_number is null or length(btrim(p_number)) not between 1 and 80 then raise exception 'Enter a receipt number (1–80 characters)'; end if;
  if p_issued_on is null or p_issued_on > (now() at time zone 'Asia/Manila')::date
    or p_issued_on < (s.received_at at time zone 'Asia/Manila')::date then
    raise exception 'Receipt date must be between payment received date and today'; end if;
  if p_photo_path is not null and (p_photo_path not like
    'cloudinary://authenticated/'||auth.uid()::text||'/payment/'||s.charge_id::text||'/%'
    or length(p_photo_path)>1024) then raise exception 'Invalid receipt attachment'; end if;
  select id into replacement from public.issued_payment_receipts where transaction_id=p_transaction_id
    and status='voided' order by voided_at desc,id limit 1;
  insert into public.issued_payment_receipts(id,transaction_id,receipt_number,environment,issued_on,issued_by,photo_path,replaces_id)
    values(p_id,p_transaction_id,btrim(p_number),env,p_issued_on,auth.uid(),p_photo_path,replacement) returning * into r;
  return r;
end $$;

create function public.void_issued_payment_receipt(p_id uuid,p_reason text)
returns public.issued_payment_receipts language plpgsql security definer set search_path='' as $$
declare r public.issued_payment_receipts; txn uuid;
begin
  if auth.uid() is null or not coalesce(public.is_staff(),false) then raise exception 'Staff access required'; end if;
  if p_reason is null or length(btrim(p_reason)) not between 3 and 500 then raise exception 'Enter a void reason (3–500 characters)'; end if;
  select transaction_id into txn from public.issued_payment_receipts where id=p_id;
  perform 1 from public.payment_transactions where id=txn for update;
  select * into r from public.issued_payment_receipts where id=p_id for update;
  if not found then raise exception 'Receipt not found'; end if;
  if r.status='voided' then return r; end if;
  update public.issued_payment_receipts set status='voided',void_reason=btrim(p_reason),voided_by=auth.uid(),voided_at=now()
    where id=p_id returning * into r;
  return r;
end $$;
revoke all on function public.protect_issued_payment_receipt() from public,anon,authenticated,service_role;
revoke all on function public.record_issued_payment_receipt(uuid,uuid,text,date,text) from public,anon,service_role;
revoke all on function public.void_issued_payment_receipt(uuid,text) from public,anon,service_role;
grant execute on function public.record_issued_payment_receipt(uuid,uuid,text,date,text) to authenticated;
grant execute on function public.void_issued_payment_receipt(uuid,text) to authenticated;
notify pgrst,'reload schema';
commit;

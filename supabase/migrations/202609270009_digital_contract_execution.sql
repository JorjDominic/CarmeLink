-- Make contract identifiers server-generated and make verified electronic
-- signatures the authoritative activation evidence.

create sequence if not exists public.tenant_contract_number_seq;

create or replace function public.next_tenant_contract_number()
returns text
language sql
security definer
set search_path = ''
as $$
  select 'CTR-' || to_char(current_date, 'YYYY') || '-' ||
         lpad(nextval('public.tenant_contract_number_seq')::text, 6, '0');
$$;

alter table public.tenant_contracts
  alter column contract_number set default public.next_tenant_contract_number();

revoke all on function public.next_tenant_contract_number() from public, anon, authenticated;

-- The former signed-photocopy item belongs to the retired paper workflow.
update public.contract_requirements
set is_required = false,
    status = case when status = 'verified' then 'verified' else 'waived' end,
    updated_at = now()
where requirement_type = 'signed_photocopies';

create or replace function public.initialize_contract_onboarding(p_contract_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into public.contract_requirements
    (contract_id, requirement_type, is_required, status)
  values
    (p_contract_id, 'tenant_identity', true, 'missing'),
    (p_contract_id, 'guardian_identity', false, 'waived'),
    (p_contract_id, 'signed_photocopies', false, 'waived')
  on conflict (contract_id, requirement_type) do nothing;

  insert into public.contract_signers (contract_id, signer_role, is_required)
  values
    (p_contract_id, 'lessor', true),
    (p_contract_id, 'tenant', true),
    (p_contract_id, 'guardian', false),
    (p_contract_id, 'witness', false)
  on conflict (contract_id, signer_role) do nothing;
end;
$$;

drop policy if exists contract_documents_storage_owner_signature_insert
  on storage.objects;
create policy contract_documents_storage_owner_signature_insert
on storage.objects for insert to authenticated with check (
  bucket_id = 'contract-documents'
  and (select public.current_user_role()) = 'owner'
  and (storage.foldername(name))[2] = 'signatures'
  and exists (
    select 1 from public.tenant_contracts c
    where c.id::text = (storage.foldername(name))[1] and c.status = 'draft'
  )
);

create or replace function public.submit_owner_electronic_signature(
  p_contract_id uuid,
  p_storage_path text,
  p_size_bytes bigint,
  p_sha256 text
) returns public.contract_signers
language plpgsql security definer set search_path = '' as $$
declare v_signer public.contract_signers;
begin
  if public.current_user_role() <> 'owner' then raise exception 'Owner access required'; end if;
  if p_size_bytes not between 1 and 2097152 then raise exception 'Signature image must be 2 MB or smaller'; end if;
  if p_sha256 !~ '^[a-f0-9]{64}$' then raise exception 'Invalid signature hash'; end if;
  if p_storage_path not like p_contract_id::text || '/signatures/lessor-%' then
    raise exception 'Invalid signature storage path';
  end if;
  if not exists (
    select 1 from public.tenant_contracts where id = p_contract_id and status = 'draft'
  ) then raise exception 'Draft contract not found'; end if;

  update public.contract_signers
  set status = 'verified',
      signer_name = (select full_name from public.profiles where id = auth.uid()),
      signature_method = 'electronic', signed_at = now(),
      verified_by = auth.uid(), verified_at = now(),
      signature_storage_path = p_storage_path,
      signature_size_bytes = p_size_bytes,
      signature_sha256 = p_sha256,
      notes = 'Electronically signed by authenticated owner', updated_at = now()
  where contract_id = p_contract_id and signer_role = 'lessor'
    and status in ('pending', 'signed', 'rejected')
  returning * into v_signer;
  if v_signer.id is null then raise exception 'Owner signer is not eligible for signing'; end if;
  return v_signer;
end $$;

revoke all on function public.submit_owner_electronic_signature(uuid,text,bigint,text)
  from public, anon;
grant execute on function public.submit_owner_electronic_signature(uuid,text,bigint,text)
  to authenticated;

create or replace function public.sync_electronic_contract_signature_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pending boolean;
  v_rejected boolean;
begin
  select
    exists (
      select 1 from public.contract_signers
      where contract_id = new.contract_id and is_required and status <> 'verified'
    ),
    exists (
      select 1 from public.contract_signers
      where contract_id = new.contract_id and is_required and status = 'rejected'
    )
  into v_pending, v_rejected;

  update public.tenant_contracts
  set signature_status = case
    when v_rejected then 'rejected'
    when not v_pending then 'verified'
    when new.status = 'signed' then 'pending_verification'
    else 'awaiting_signature'
  end,
  updated_at = now()
  where id = new.contract_id;
  return new;
end;
$$;

drop trigger if exists contract_signers_sync_contract_status on public.contract_signers;
create trigger contract_signers_sync_contract_status
after insert or update of status, is_required on public.contract_signers
for each row execute function public.sync_electronic_contract_signature_status();

revoke all on function public.sync_electronic_contract_signature_status()
  from public, anon, authenticated;

create or replace function public.require_verified_email_for_active_contract()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' and new.status = 'active' then
    raise exception 'Contracts must be created as Draft before activation';
  end if;
  if new.status = 'active' and (tg_op = 'INSERT' or old.status is distinct from 'active') then
    if not exists (
      select 1 from public.profiles where id = new.tenant_id and email_verified_at is not null
    ) then raise exception 'Tenant email must be verified before contract activation'; end if;
    if not exists (
      select 1 from public.contract_documents
      where contract_id = new.id and document_type = 'generated'
    ) then raise exception 'Official contract PDF must be generated before activation'; end if;
    if exists (
      select 1 from public.contract_requirements
      where contract_id = new.id and is_required and status <> 'verified'
    ) then raise exception 'Required onboarding documents must be verified before activation'; end if;
    if exists (
      select 1 from public.contract_signers
      where contract_id = new.id and is_required and status <> 'verified'
    ) then raise exception 'Every required digital signer must be verified before activation'; end if;
  end if;
  return new;
end;
$$;

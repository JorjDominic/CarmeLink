-- Tenant-facing contract checklist and electronic signature evidence.

alter table public.contract_signers
  add column if not exists signature_storage_path text,
  add column if not exists signature_size_bytes bigint
    check (signature_size_bytes is null or signature_size_bytes between 1 and 2097152),
  add column if not exists signature_sha256 text
    check (signature_sha256 is null or signature_sha256 ~ '^[a-f0-9]{64}$');

create policy tenant_contracts_tenant_select on public.tenant_contracts
for select to authenticated using (
  tenant_id = (select auth.uid())
  and (select public.current_user_role()) = 'tenant'
);

create policy contract_requirements_tenant_select on public.contract_requirements
for select to authenticated using (
  (select public.current_user_role()) = 'tenant'
  and exists (
    select 1 from public.tenant_contracts c
    where c.id = contract_requirements.contract_id
      and c.tenant_id = (select auth.uid())
  )
);

create policy contract_signers_tenant_select on public.contract_signers
for select to authenticated using (
  (select public.current_user_role()) = 'tenant'
  and exists (
    select 1 from public.tenant_contracts c
    where c.id = contract_signers.contract_id
      and c.tenant_id = (select auth.uid())
  )
);

create policy contract_documents_storage_tenant_signature_insert
on storage.objects for insert to authenticated with check (
  bucket_id = 'contract-documents'
  and (select public.current_user_role()) = 'tenant'
  and (storage.foldername(name))[2] = 'signatures'
  and exists (
    select 1 from public.tenant_contracts c
    where c.id::text = (storage.foldername(name))[1]
      and c.tenant_id = (select auth.uid())
      and c.status = 'draft'
  )
);

create policy contract_documents_storage_tenant_requirement_insert
on storage.objects for insert to authenticated with check (
  bucket_id = 'contract-documents'
  and (select public.current_user_role()) = 'tenant'
  and (storage.foldername(name))[2] = 'requirements'
  and exists (
    select 1 from public.tenant_contracts c
    where c.id::text = (storage.foldername(name))[1]
      and c.tenant_id = (select auth.uid())
      and c.status = 'draft'
  )
);

create policy contract_documents_storage_tenant_cleanup
on storage.objects for delete to authenticated using (
  bucket_id = 'contract-documents'
  and (storage.foldername(name))[2] in ('requirements', 'signatures')
  and exists (
    select 1 from public.tenant_contracts c
    where c.id::text = (storage.foldername(name))[1]
      and c.tenant_id = (select auth.uid())
      and c.status = 'draft'
  )
);

create policy contract_documents_storage_tenant_own_select
on storage.objects for select to authenticated using (
  bucket_id = 'contract-documents'
  and exists (
    select 1 from public.tenant_contracts c
    where c.id::text = (storage.foldername(name))[1]
      and c.tenant_id = (select auth.uid())
  )
);

create or replace function public.get_my_contract()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_result jsonb;
begin
  if public.current_user_role() <> 'tenant' then
    raise exception 'Tenant access required';
  end if;
  select jsonb_build_object(
    'id', c.id, 'tenant_id', c.tenant_id,
    'contract_number', c.contract_number, 'starts_on', c.starts_on,
    'ends_on', c.ends_on, 'monthly_rent', c.monthly_rent,
    'security_deposit', c.security_deposit, 'status', c.status,
    'notes', c.notes, 'signature_status', c.signature_status,
    'created_at', c.created_at, 'updated_at', c.updated_at,
    'profiles', jsonb_build_object('full_name', p.full_name)
  ) into v_result
  from public.tenant_contracts c
  join public.profiles p on p.id = c.tenant_id
  where c.tenant_id = auth.uid() and c.status in ('draft', 'active')
  order by case when c.status = 'active' then 0 else 1 end, c.starts_on desc
  limit 1;
  return v_result;
end $$;

create or replace function public.submit_tenant_electronic_signature(
  p_contract_id uuid,
  p_storage_path text,
  p_size_bytes bigint,
  p_sha256 text
) returns public.contract_signers
language plpgsql security definer set search_path = '' as $$
declare v_signer public.contract_signers;
begin
  if public.current_user_role() <> 'tenant' then
    raise exception 'Tenant access required';
  end if;
  if p_size_bytes not between 1 and 2097152 then
    raise exception 'Signature image must be 2 MB or smaller';
  end if;
  if p_sha256 !~ '^[a-f0-9]{64}$' then raise exception 'Invalid signature hash'; end if;
  if p_storage_path not like p_contract_id::text || '/signatures/tenant-%' then
    raise exception 'Invalid signature storage path';
  end if;
  if not exists (
    select 1 from public.tenant_contracts
    where id = p_contract_id and tenant_id = auth.uid() and status = 'draft'
  ) then raise exception 'Draft contract not found for this tenant'; end if;

  update public.contract_signers
  set status = 'signed', signer_name = (
        select full_name from public.profiles where id = auth.uid()
      ),
      signature_method = 'electronic', signed_at = now(),
      verified_by = null, verified_at = null,
      signature_storage_path = p_storage_path,
      signature_size_bytes = p_size_bytes,
      signature_sha256 = p_sha256,
      notes = 'Electronic signature submitted by tenant; owner verification required',
      updated_at = now()
  where contract_id = p_contract_id and signer_role = 'tenant'
    and status in ('pending', 'signed', 'rejected')
  returning * into v_signer;
  if v_signer.id is null then
    raise exception 'Tenant signer record is not eligible for signature submission';
  end if;
  return v_signer;
end $$;

-- Replace the owner-only submission function so a tenant can submit files for
-- their own Draft contract. Review and verification remain owner-only.
create or replace function public.submit_contract_requirement(
  p_requirement_id uuid,
  p_storage_path text,
  p_original_filename text,
  p_mime_type text,
  p_size_bytes bigint,
  p_sha256 text,
  p_physical_copy_received boolean default false,
  p_signature_count smallint default 0
) returns public.contract_requirements
language plpgsql security definer set search_path = '' as $$
declare
  v_item public.contract_requirements;
  v_role public.app_role := public.current_user_role();
begin
  if v_role not in ('owner', 'tenant') then raise exception 'Forbidden'; end if;
  if p_mime_type not in ('application/pdf', 'image/jpeg', 'image/png') then
    raise exception 'Unsupported document type';
  end if;
  if p_size_bytes not between 1 and 10485760 then
    raise exception 'Document must be 10 MB or smaller';
  end if;
  if p_sha256 !~ '^[a-f0-9]{64}$' then raise exception 'Invalid document hash'; end if;

  update public.contract_requirements r
  set storage_path = p_storage_path,
      original_filename = trim(p_original_filename), mime_type = p_mime_type,
      size_bytes = p_size_bytes, sha256 = p_sha256,
      physical_copy_received = case
        when v_role = 'owner' and requirement_type = 'signed_photocopies'
          then p_physical_copy_received else false end,
      signature_count = case
        when v_role = 'owner' and requirement_type = 'signed_photocopies'
          then p_signature_count else 0 end,
      status = 'pending_review', submitted_by = auth.uid(), submitted_at = now(),
      reviewed_by = null, reviewed_at = null, review_notes = null,
      updated_at = now()
  where r.id = p_requirement_id
    and p_storage_path like (r.contract_id::text || '/requirements/%')
    and (
      v_role = 'owner'
      or exists (
        select 1 from public.tenant_contracts c
        where c.id = r.contract_id and c.tenant_id = auth.uid()
          and c.status = 'draft'
      )
    )
  returning * into v_item;
  if v_item.id is null then
    raise exception 'Contract requirement not found or not available for submission';
  end if;
  return v_item;
end $$;

revoke all on function public.get_my_contract() from public, anon;
grant execute on function public.get_my_contract() to authenticated;
revoke all on function public.submit_tenant_electronic_signature(uuid,text,bigint,text)
  from public, anon;
grant execute on function public.submit_tenant_electronic_signature(uuid,text,bigint,text)
  to authenticated;

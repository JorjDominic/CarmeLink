-- Read-only contract/document visibility for the tenant and linked guardian.

create policy contract_documents_tenant_select on public.contract_documents
for select to authenticated using (
  (select public.current_user_role()) = 'tenant'
  and exists (
    select 1 from public.tenant_contracts c
    where c.id = contract_documents.contract_id and c.tenant_id = auth.uid()
  )
);

create policy tenant_contracts_guardian_select on public.tenant_contracts
for select to authenticated using (
  (select public.current_user_role()) = 'guardian'
  and public.is_guardian_of(tenant_id)
);

create policy contract_documents_guardian_select on public.contract_documents
for select to authenticated using (
  (select public.current_user_role()) = 'guardian'
  and exists (
    select 1 from public.tenant_contracts c
    where c.id = contract_documents.contract_id
      and public.is_guardian_of(c.tenant_id)
  )
);

create policy contract_requirements_guardian_select on public.contract_requirements
for select to authenticated using (
  (select public.current_user_role()) = 'guardian'
  and exists (
    select 1 from public.tenant_contracts c
    where c.id = contract_requirements.contract_id
      and public.is_guardian_of(c.tenant_id)
  )
);

create policy contract_signers_guardian_select on public.contract_signers
for select to authenticated using (
  (select public.current_user_role()) = 'guardian'
  and exists (
    select 1 from public.tenant_contracts c
    where c.id = contract_signers.contract_id
      and public.is_guardian_of(c.tenant_id)
  )
);

create policy contract_documents_storage_guardian_select
on storage.objects for select to authenticated using (
  bucket_id = 'contract-documents'
  and (select public.current_user_role()) = 'guardian'
  and exists (
    select 1 from public.tenant_contracts c
    where c.id::text = (storage.foldername(name))[1]
      and public.is_guardian_of(c.tenant_id)
  )
);


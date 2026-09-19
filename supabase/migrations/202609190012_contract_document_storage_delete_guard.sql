-- Match Storage deletion to the metadata rule: active contracts are immutable.
drop policy if exists contract_documents_storage_owner_delete on storage.objects;
create policy contract_documents_storage_owner_delete on storage.objects
for delete to authenticated using (
  bucket_id = 'contract-documents'
  and (select public.current_user_role()) = 'owner'
  and exists (
    select 1 from public.tenant_contracts c
    where c.id::text = (storage.foldername(name))[1]
      and c.status <> 'active'
  )
);

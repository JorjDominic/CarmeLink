-- Limit each contract to one generated original and one signed copy.
-- Existing duplicate versions remain available for owner-directed cleanup.

create policy contract_documents_owner_delete on public.contract_documents
for delete to authenticated using (
  (select public.current_user_role()) = 'owner'
  and exists (
    select 1 from public.tenant_contracts c
    where c.id = contract_id and c.status <> 'active'
  )
);

grant delete on public.contract_documents to authenticated;

create policy contract_documents_storage_owner_delete on storage.objects
for delete to authenticated using (
  bucket_id = 'contract-documents'
  and (select public.current_user_role()) = 'owner'
);

create or replace function public.validate_contract_document()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.storage_path not like (new.contract_id::text || '/%') then
    raise exception 'Document path must be scoped to its contract';
  end if;

  if exists (
    select 1 from public.contract_documents
    where contract_id = new.contract_id
      and document_type = new.document_type
  ) then
    raise exception 'Only one % document is allowed per contract', new.document_type;
  end if;

  if new.document_type = 'generated' then
    new.version := 1;
    new.review_status := 'not_required';
  else
    if not exists (
      select 1 from public.contract_documents
      where contract_id = new.contract_id and version = new.version
        and document_type = 'generated'
    ) then
      raise exception 'Signed document must match the generated contract';
    end if;
    new.review_status := 'pending';
  end if;
  return new;
end;
$$;

create or replace function public.recompute_contract_signature_status_after_delete()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_generated_version integer;
  v_review_status text;
begin
  select max(version) into v_generated_version
  from public.contract_documents
  where contract_id = old.contract_id and document_type = 'generated';

  if v_generated_version is null then
    update public.tenant_contracts set signature_status = 'not_generated'
    where id = old.contract_id;
    return old;
  end if;

  select review_status into v_review_status
  from public.contract_documents
  where contract_id = old.contract_id
    and version = v_generated_version and document_type = 'signed';

  update public.tenant_contracts
  set signature_status = case
    when v_review_status = 'verified' then 'verified'
    when v_review_status = 'rejected' then 'rejected'
    when v_review_status = 'pending' then 'pending_verification'
    else 'awaiting_signature'
  end
  where id = old.contract_id;
  return old;
end;
$$;

create trigger contract_documents_recompute_status_after_delete
after delete on public.contract_documents
for each row execute function public.recompute_contract_signature_status_after_delete();

revoke all on function public.recompute_contract_signature_status_after_delete()
  from public, anon, authenticated;

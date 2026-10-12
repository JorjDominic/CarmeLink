begin;

-- Signature evidence and the final PDF must not overwrite each other's state.
create or replace function public.refresh_contract_execution_status(p_contract_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_version integer; v_review text; v_status text;
begin
  perform 1 from public.tenant_contracts where id=p_contract_id for update;
  select max(version) into v_version from public.contract_documents
    where contract_id=p_contract_id and document_type='generated';
  select review_status into v_review from public.contract_documents
    where contract_id=p_contract_id and document_type='signed' and version=v_version;
  v_status := case
    when v_review='rejected' then 'rejected'
    when exists(select 1 from public.contract_signers where contract_id=p_contract_id
      and is_required and status='rejected') then 'rejected'
    when v_review='pending' then 'pending_verification'
    when exists(select 1 from public.contract_signers where contract_id=p_contract_id and signer_role='tenant' and is_required and status='verified')
      and exists(select 1 from public.contract_signers where contract_id=p_contract_id and signer_role='lessor' and is_required and status='verified')
      and not exists(select 1 from public.contract_signers where contract_id=p_contract_id and is_required and status<>'verified') then 'verified'
    when exists(select 1 from public.contract_signers where contract_id=p_contract_id and is_required and status='signed') then 'pending_verification'
    when v_version is null then 'not_generated'
    else 'awaiting_signature' end;
  update public.tenant_contracts set signature_status=v_status where id=p_contract_id;
end $$;
revoke all on function public.refresh_contract_execution_status(uuid) from public,anon,authenticated;

create or replace function public.sync_contract_signature_status()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  perform public.refresh_contract_execution_status(new.contract_id);
  return new;
end $$;
create or replace function public.sync_electronic_contract_signature_status()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  perform public.refresh_contract_execution_status(new.contract_id);
  return new;
end $$;
create or replace function public.recompute_contract_signature_status_after_delete()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  perform public.refresh_contract_execution_status(old.contract_id);
  return old;
end $$;

-- Supplement all existing email, identity, signer and renewal guards.
create function public.require_signed_copy_for_activation()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.status='active' and (tg_op='INSERT' or old.status is distinct from 'active') then
    if not exists(
      select 1 from public.contract_documents d
      join storage.objects o on o.bucket_id='contract-documents' and o.name=d.storage_path
      where d.contract_id=new.id and d.document_type='signed' and d.review_status='verified'
        and d.version=(select max(version) from public.contract_documents
          where contract_id=new.id and document_type='generated')
    ) then raise exception 'Generate and verify the signed contract copy before activation'; end if;
  end if;
  return new;
end $$;
revoke all on function public.require_signed_copy_for_activation() from public,anon,authenticated;
create trigger tenant_contracts_require_signed_copy
before insert or update of status on public.tenant_contracts
for each row execute function public.require_signed_copy_for_activation();

-- Correct stale labels without changing lifecycle state or historical billing.
select public.refresh_contract_execution_status(id) from public.tenant_contracts;
commit;

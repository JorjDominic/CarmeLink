-- Immutable, versioned contract documents stored in a private bucket.
alter table public.tenant_contracts
  add column signature_status text not null default 'not_generated'
    check (signature_status in (
      'not_generated', 'awaiting_signature', 'pending_verification',
      'verified', 'rejected'
    ));

create table public.contract_documents (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.tenant_contracts(id) on delete restrict,
  version integer not null check (version > 0),
  document_type text not null check (document_type in ('generated', 'signed')),
  storage_path text not null unique,
  original_filename text not null,
  mime_type text not null check (mime_type in ('application/pdf', 'image/jpeg', 'image/png')),
  size_bytes bigint not null check (size_bytes between 1 and 10485760),
  sha256 text not null check (sha256 ~ '^[a-f0-9]{64}$'),
  review_status text not null default 'not_required'
    check (review_status in ('not_required', 'pending', 'verified', 'rejected')),
  uploaded_by uuid not null default auth.uid()
    references public.profiles(id) on delete restrict,
  uploaded_at timestamptz not null default now(),
  reviewed_by uuid references public.profiles(id) on delete restrict,
  reviewed_at timestamptz,
  review_notes text,
  unique (contract_id, version, document_type),
  constraint contract_document_review_valid check (
    (document_type = 'generated' and review_status = 'not_required'
      and reviewed_by is null and reviewed_at is null)
    or
    (document_type = 'signed' and review_status in ('pending', 'verified', 'rejected'))
  )
);

create index contract_documents_contract_idx
  on public.contract_documents(contract_id, version desc);

alter table public.contract_documents enable row level security;
create policy contract_documents_owner_select on public.contract_documents
for select to authenticated using ((select public.current_user_role()) = 'owner');
create policy contract_documents_owner_insert on public.contract_documents
for insert to authenticated with check (
  (select public.current_user_role()) = 'owner' and uploaded_by = auth.uid()
);
grant select, insert on public.contract_documents to authenticated;
revoke all on public.contract_documents from anon;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'contract-documents', 'contract-documents', false, 10485760,
  array['application/pdf', 'image/jpeg', 'image/png']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy contract_documents_storage_owner_insert on storage.objects
for insert to authenticated with check (
  bucket_id = 'contract-documents'
  and (select public.current_user_role()) = 'owner'
  and exists (
    select 1 from public.tenant_contracts c
    where c.id::text = (storage.foldername(name))[1]
  )
);
create policy contract_documents_storage_owner_select on storage.objects
for select to authenticated using (
  bucket_id = 'contract-documents'
  and (select public.current_user_role()) = 'owner'
);

create or replace function public.validate_contract_document()
returns trigger language plpgsql set search_path = '' as $$
declare
  v_latest_version integer;
begin
  if new.storage_path not like (new.contract_id::text || '/%') then
    raise exception 'Document path must be scoped to its contract';
  end if;
  if new.document_type = 'generated' then
    select coalesce(max(version), 0) + 1 into v_latest_version
    from public.contract_documents where contract_id = new.contract_id
      and document_type = 'generated';
    if new.version <> v_latest_version then
      raise exception 'Generated contract version must be %', v_latest_version;
    end if;
    new.review_status := 'not_required';
  else
    if not exists (
      select 1 from public.contract_documents
      where contract_id = new.contract_id and version = new.version
        and document_type = 'generated'
    ) then
      raise exception 'Signed document must match a generated contract version';
    end if;
    if new.version <> (
      select max(version) from public.contract_documents
      where contract_id = new.contract_id and document_type = 'generated'
    ) then
      raise exception 'Only the latest contract version may be signed';
    end if;
    new.review_status := 'pending';
  end if;
  return new;
end;
$$;

create trigger contract_documents_validate
before insert on public.contract_documents
for each row execute function public.validate_contract_document();

create or replace function public.sync_contract_signature_status()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.tenant_contracts
  set signature_status = case
    when new.document_type = 'generated' then 'awaiting_signature'
    else 'pending_verification'
  end
  where id = new.contract_id;
  return new;
end;
$$;

create trigger contract_documents_sync_status
after insert on public.contract_documents
for each row execute function public.sync_contract_signature_status();

create or replace function public.review_signed_contract_document(
  p_document_id uuid,
  p_approve boolean,
  p_notes text
) returns public.contract_documents
language plpgsql security definer set search_path = '' as $$
declare
  v_document public.contract_documents;
begin
  if public.current_user_role() <> 'owner' then raise exception 'Forbidden'; end if;
  if p_notes is null or length(trim(p_notes)) < 3 then
    raise exception 'Review notes must contain at least 3 characters';
  end if;

  update public.contract_documents
  set review_status = case when p_approve then 'verified' else 'rejected' end,
      reviewed_by = auth.uid(), reviewed_at = now(), review_notes = trim(p_notes)
  where id = p_document_id and document_type = 'signed'
    and review_status = 'pending'
  returning * into v_document;
  if v_document.id is null then raise exception 'Pending signed document not found'; end if;

  update public.tenant_contracts
  set signature_status = case when p_approve then 'verified' else 'rejected' end
  where id = v_document.contract_id;
  return v_document;
end;
$$;

grant execute on function public.review_signed_contract_document(uuid, boolean, text)
  to authenticated;
revoke execute on function public.review_signed_contract_document(uuid, boolean, text)
  from public, anon;

create or replace function public.protect_contract_after_signature()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.status = 'active' and (
    old.tenant_id is distinct from new.tenant_id
    or old.contract_number is distinct from new.contract_number
    or old.starts_on is distinct from new.starts_on
    or old.ends_on is distinct from new.ends_on
    or old.monthly_rent is distinct from new.monthly_rent
    or old.security_deposit is distinct from new.security_deposit
  ) then
    raise exception 'Active contract terms are immutable; terminate and create a new contract';
  end if;
  if old.status <> 'active' and (
    old.tenant_id is distinct from new.tenant_id
    or old.contract_number is distinct from new.contract_number
    or old.starts_on is distinct from new.starts_on
    or old.ends_on is distinct from new.ends_on
    or old.monthly_rent is distinct from new.monthly_rent
    or old.security_deposit is distinct from new.security_deposit
  ) then
    new.signature_status := 'not_generated';
  end if;
  return new;
end;
$$;

create trigger tenant_contracts_protect_signed_terms
before update on public.tenant_contracts
for each row execute function public.protect_contract_after_signature();

create or replace function public.require_verified_email_for_active_contract()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'active' and (tg_op = 'INSERT' or old.status is distinct from 'active') then
    if not exists (
      select 1 from public.profiles
      where id = new.tenant_id and email_verified_at is not null
    ) then
      raise exception 'Tenant email must be verified before contract activation';
    end if;
    if new.signature_status <> 'verified' then
      raise exception 'Signed contract must be verified before activation';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.validate_contract_document() from public, anon, authenticated;
revoke all on function public.sync_contract_signature_status() from public, anon, authenticated;
revoke all on function public.protect_contract_after_signature() from public, anon, authenticated;

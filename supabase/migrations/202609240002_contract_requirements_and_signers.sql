-- Contract onboarding requirements and independent signer verification.
-- Guardian and witness are optional by default while client policy is open.

create table public.contract_requirements (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.tenant_contracts(id) on delete cascade,
  requirement_type text not null check (requirement_type in (
    'tenant_identity', 'guardian_identity', 'signed_photocopies'
  )),
  is_required boolean not null default true,
  status text not null default 'missing' check (status in (
    'missing', 'pending_review', 'verified', 'rejected', 'waived'
  )),
  physical_copy_received boolean not null default false,
  signature_count smallint not null default 0 check (signature_count between 0 and 3),
  storage_path text,
  original_filename text,
  mime_type text check (mime_type is null or mime_type in (
    'application/pdf', 'image/jpeg', 'image/png'
  )),
  size_bytes bigint check (size_bytes is null or size_bytes between 1 and 10485760),
  sha256 text check (sha256 is null or sha256 ~ '^[a-f0-9]{64}$'),
  submitted_by uuid references public.profiles(id) on delete restrict,
  submitted_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete restrict,
  reviewed_at timestamptz,
  review_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (contract_id, requirement_type),
  constraint contract_requirement_file_complete check (
    (storage_path is null and original_filename is null and mime_type is null
      and size_bytes is null and sha256 is null)
    or
    (storage_path is not null and original_filename is not null and mime_type is not null
      and size_bytes is not null and sha256 is not null)
  ),
  constraint signed_photocopy_metadata check (
    requirement_type = 'signed_photocopies'
    or (signature_count = 0 and physical_copy_received = false)
  )
);

create table public.contract_signers (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references public.tenant_contracts(id) on delete cascade,
  signer_role text not null check (signer_role in (
    'lessor', 'tenant', 'guardian', 'witness'
  )),
  is_required boolean not null default true,
  status text not null default 'pending' check (status in (
    'pending', 'signed', 'verified', 'rejected', 'waived'
  )),
  signer_name text,
  signature_method text check (signature_method is null or signature_method in (
    'physical_upload', 'electronic'
  )),
  signed_at timestamptz,
  verified_by uuid references public.profiles(id) on delete restrict,
  verified_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (contract_id, signer_role),
  constraint contract_signer_status_metadata check (
    (status = 'pending' and signed_at is null and verified_at is null)
    or (status = 'signed' and signed_at is not null and verified_at is null)
    or (status in ('verified', 'rejected') and signed_at is not null and verified_at is not null)
    or (status = 'waived' and is_required = false)
  )
);

create index contract_requirements_contract_idx
  on public.contract_requirements(contract_id, requirement_type);
create index contract_signers_contract_idx
  on public.contract_signers(contract_id, signer_role);

alter table public.contract_requirements enable row level security;
alter table public.contract_signers enable row level security;

create policy contract_requirements_owner_select on public.contract_requirements
for select to authenticated using ((select public.current_user_role()) = 'owner');
create policy contract_signers_owner_select on public.contract_signers
for select to authenticated using ((select public.current_user_role()) = 'owner');
grant select on public.contract_requirements, public.contract_signers to authenticated;
revoke all on public.contract_requirements, public.contract_signers from anon;

create policy contract_requirements_storage_owner_all on storage.objects
for all to authenticated
using (
  bucket_id = 'contract-documents'
  and (select public.current_user_role()) = 'owner'
  and (storage.foldername(name))[2] = 'requirements'
)
with check (
  bucket_id = 'contract-documents'
  and (select public.current_user_role()) = 'owner'
  and (storage.foldername(name))[2] = 'requirements'
  and exists (
    select 1 from public.tenant_contracts c
    where c.id::text = (storage.foldername(name))[1]
  )
);

create or replace function public.initialize_contract_onboarding(p_contract_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into public.contract_requirements
    (contract_id, requirement_type, is_required)
  values
    (p_contract_id, 'tenant_identity', true),
    (p_contract_id, 'guardian_identity', false),
    (p_contract_id, 'signed_photocopies', true)
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

create or replace function public.initialize_contract_onboarding_trigger()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.initialize_contract_onboarding(new.id);
  return new;
end;
$$;

create trigger tenant_contracts_initialize_onboarding
after insert on public.tenant_contracts
for each row execute function public.initialize_contract_onboarding_trigger();

do $$
declare v_contract record;
begin
  for v_contract in select id from public.tenant_contracts loop
    perform public.initialize_contract_onboarding(v_contract.id);
  end loop;
end $$;

-- Preserve compatibility for already verified signed contract copies.
update public.contract_signers s
set status = 'verified', signature_method = 'physical_upload',
    signed_at = d.reviewed_at, verified_at = d.reviewed_at,
    verified_by = d.reviewed_by,
    notes = 'Backfilled from owner-verified signed contract document'
from public.contract_documents d
where s.contract_id = d.contract_id
  and s.signer_role in ('lessor', 'tenant')
  and d.document_type = 'signed' and d.review_status = 'verified';

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
declare v_item public.contract_requirements;
begin
  if public.current_user_role() <> 'owner' then raise exception 'Forbidden'; end if;
  if p_mime_type not in ('application/pdf', 'image/jpeg', 'image/png') then
    raise exception 'Unsupported document type';
  end if;
  if p_size_bytes not between 1 and 10485760 then
    raise exception 'Document must be 10 MB or smaller';
  end if;
  if p_sha256 !~ '^[a-f0-9]{64}$' then raise exception 'Invalid document hash'; end if;

  update public.contract_requirements
  set storage_path = p_storage_path,
      original_filename = trim(p_original_filename), mime_type = p_mime_type,
      size_bytes = p_size_bytes, sha256 = p_sha256,
      physical_copy_received = case when requirement_type = 'signed_photocopies'
        then p_physical_copy_received else false end,
      signature_count = case when requirement_type = 'signed_photocopies'
        then p_signature_count else 0 end,
      status = 'pending_review', submitted_by = auth.uid(), submitted_at = now(),
      reviewed_by = null, reviewed_at = null, review_notes = null,
      updated_at = now()
  where id = p_requirement_id
    and p_storage_path like (contract_id::text || '/requirements/%')
  returning * into v_item;
  if v_item.id is null then raise exception 'Contract requirement not found'; end if;
  return v_item;
end;
$$;

create or replace function public.review_contract_requirement(
  p_requirement_id uuid, p_approve boolean, p_notes text
) returns public.contract_requirements
language plpgsql security definer set search_path = '' as $$
declare v_item public.contract_requirements;
begin
  if public.current_user_role() <> 'owner' then raise exception 'Forbidden'; end if;
  if length(trim(coalesce(p_notes, ''))) < 3 then
    raise exception 'Review notes must contain at least 3 characters';
  end if;
  update public.contract_requirements
  set status = case when p_approve then 'verified' else 'rejected' end,
      reviewed_by = auth.uid(), reviewed_at = now(),
      review_notes = trim(p_notes), updated_at = now()
  where id = p_requirement_id and status = 'pending_review'
    and (not p_approve or requirement_type <> 'signed_photocopies'
      or (physical_copy_received and signature_count = 3))
  returning * into v_item;
  if v_item.id is null then
    raise exception 'Pending requirement not found or verification details are incomplete';
  end if;
  return v_item;
end;
$$;

create or replace function public.set_contract_requirement_required(
  p_requirement_id uuid, p_required boolean
) returns public.contract_requirements
language plpgsql security definer set search_path = '' as $$
declare v_item public.contract_requirements;
begin
  if public.current_user_role() <> 'owner' then raise exception 'Forbidden'; end if;
  update public.contract_requirements
  set is_required = p_required,
      status = case when not p_required and status = 'missing' then 'waived'
                    when p_required and status = 'waived' then 'missing'
                    else status end,
      updated_at = now()
  where id = p_requirement_id and requirement_type = 'guardian_identity'
  returning * into v_item;
  if v_item.id is null then raise exception 'Configurable requirement not found'; end if;
  return v_item;
end;
$$;

create or replace function public.update_contract_signer(
  p_signer_id uuid,
  p_status text,
  p_signer_name text default null,
  p_signature_method text default 'physical_upload',
  p_notes text default null,
  p_required boolean default null
) returns public.contract_signers
language plpgsql security definer set search_path = '' as $$
declare v_item public.contract_signers;
begin
  if public.current_user_role() <> 'owner' then raise exception 'Forbidden'; end if;
  if p_status not in ('pending', 'signed', 'verified', 'rejected', 'waived') then
    raise exception 'Invalid signer status';
  end if;
  update public.contract_signers
  set is_required = case
        when signer_role in ('guardian', 'witness')
          then coalesce(p_required, is_required)
        else true
      end,
      status = p_status, signer_name = nullif(trim(p_signer_name), ''),
      signature_method = case when p_status = 'pending' then null else p_signature_method end,
      signed_at = case when p_status = 'pending' then null else coalesce(signed_at, now()) end,
      verified_by = case when p_status in ('verified', 'rejected') then auth.uid() else null end,
      verified_at = case when p_status in ('verified', 'rejected') then now() else null end,
      notes = nullif(trim(p_notes), ''), updated_at = now()
  where id = p_signer_id
    and (
      p_status <> 'waived'
      or (
        signer_role in ('guardian', 'witness')
        and coalesce(p_required, is_required) = false
      )
    )
  returning * into v_item;
  if v_item.id is null then raise exception 'Signer not found or cannot be waived'; end if;
  return v_item;
end;
$$;

-- Expand the existing activation guard with required documents and signers.
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
    if new.signature_status <> 'verified' then
      raise exception 'Signed contract document must be owner-verified before activation';
    end if;
    if exists (
      select 1 from public.contract_requirements
      where contract_id = new.id and is_required and status <> 'verified'
    ) then raise exception 'Required onboarding documents must be verified before activation'; end if;
    if exists (
      select 1 from public.contract_signers
      where contract_id = new.id and is_required and status <> 'verified'
    ) then raise exception 'Every required contract signer must be verified before activation'; end if;
  end if;
  return new;
end;
$$;

grant execute on function public.submit_contract_requirement(uuid, text, text, text, bigint, text, boolean, smallint) to authenticated;
grant execute on function public.review_contract_requirement(uuid, boolean, text) to authenticated;
grant execute on function public.set_contract_requirement_required(uuid, boolean) to authenticated;
grant execute on function public.update_contract_signer(uuid, text, text, text, text, boolean) to authenticated;
revoke execute on function public.submit_contract_requirement(uuid, text, text, text, bigint, text, boolean, smallint) from public, anon;
revoke execute on function public.review_contract_requirement(uuid, boolean, text) from public, anon;
revoke execute on function public.set_contract_requirement_required(uuid, boolean) from public, anon;
revoke execute on function public.update_contract_signer(uuid, text, text, text, text, boolean) from public, anon;
revoke all on function public.initialize_contract_onboarding(uuid) from public, anon, authenticated;
revoke all on function public.initialize_contract_onboarding_trigger() from public, anon, authenticated;

comment on table public.contract_requirements is
  'Per-contract identity and signed-photocopy verification checklist.';
comment on table public.contract_signers is
  'Independent lessor, tenant, guardian, and optional witness signature states.';

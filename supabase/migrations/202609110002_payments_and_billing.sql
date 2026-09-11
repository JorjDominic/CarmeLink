-- ==============================================================================
-- Migration: 202609110002_payments_and_billing.sql
-- Description: Core payments and billing table, RLS policies, storage bucket for
--              receipt proof uploads, security triggers, and realtime publication.
-- ==============================================================================

-- 1. Create payments table
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 2 and 150),
  category text not null default 'rent'
    check (category in ('rent', 'utility', 'deposit', 'penalty', 'other')),
  amount numeric(10, 2) not null check (amount >= 0),
  due_date date not null,
  status text not null default 'due'
    check (status in ('due', 'pending_verification', 'verified', 'rejected')),
  payment_method text
    check (payment_method is null or payment_method in ('GCash', 'Maya', 'Bank transfer', 'Cash', 'Other')),
  reference_number text,
  receipt_path text,
  paid_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  review_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Performance Indexes
create index if not exists payments_tenant_id_idx on public.payments (tenant_id);
create index if not exists payments_status_idx on public.payments (status);
create index if not exists payments_due_date_idx on public.payments (due_date);
create index if not exists payments_created_at_idx on public.payments (created_at desc);

-- 2. Auto-update updated_at timestamp
drop trigger if exists payments_set_updated_at on public.payments;
create trigger payments_set_updated_at
  before update on public.payments
  for each row execute function public.set_updated_at();

-- 3. Validate tenant profile role
create or replace function public.validate_payment_tenant_role()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select role from public.profiles where id = new.tenant_id) <> 'tenant' then
    raise exception 'payments.tenant_id must reference an existing user with role tenant';
  end if;
  return new;
end;
$$;

drop trigger if exists payments_validate_tenant_role on public.payments;
create trigger payments_validate_tenant_role
  before insert or update of tenant_id on public.payments
  for each row execute function public.validate_payment_tenant_role();

-- 4. Protection trigger for tenant submissions
create or replace function public.protect_tenant_payment_submission()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select public.current_user_role()) = 'tenant' then
    -- Tenants cannot change core invoice details set by staff
    if old.tenant_id <> new.tenant_id then
      raise exception 'Tenant cannot reassign payment ownership';
    end if;

    if old.amount <> new.amount then
      raise exception 'Tenant cannot change invoice amount';
    end if;

    if old.title <> new.title or old.category <> new.category then
      raise exception 'Tenant cannot modify invoice metadata';
    end if;

    if old.due_date <> new.due_date then
      raise exception 'Tenant cannot modify invoice due date';
    end if;

    if old.created_at <> new.created_at then
      raise exception 'Tenant cannot alter payment creation timestamp';
    end if;

    if old.status = 'verified' then
      raise exception 'Verified payments cannot be modified';
    end if;

    -- Tenants cannot self-verify or modify review results
    if new.reviewed_by is not null and new.reviewed_by <> old.reviewed_by then
      raise exception 'Tenant cannot set review staff';
    end if;

    if new.reviewed_at is not null and new.reviewed_at <> old.reviewed_at then
      raise exception 'Tenant cannot set review timestamp';
    end if;

    if new.review_notes is not null and new.review_notes <> old.review_notes then
      raise exception 'Tenant cannot set review notes';
    end if;

    -- Tenant submission must set status to pending_verification
    if new.status <> 'pending_verification' then
      raise exception 'Tenant submission status must be pending_verification';
    end if;

    -- Receipt path must belong to the tenant's own storage folder
    if new.receipt_path is not null and new.receipt_path not like (auth.uid()::text || '/%') then
      raise exception 'Tenant cannot attach another user''s payment receipt';
    end if;

    -- Set payment submission timestamp if not already provided
    if new.paid_at is null then
      new.paid_at = now();
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists payments_protect_tenant_submission on public.payments;
create trigger payments_protect_tenant_submission
  before update on public.payments
  for each row execute function public.protect_tenant_payment_submission();

-- 5. Enable Row Level Security
alter table public.payments enable row level security;

-- Policies for public.payments
drop policy if exists "staff manage all payments" on public.payments;
create policy "staff manage all payments"
  on public.payments
  for all
  to authenticated
  using ((select public.is_staff()))
  with check ((select public.is_staff()));

drop policy if exists "tenants view own payments" on public.payments;
create policy "tenants view own payments"
  on public.payments
  for select
  to authenticated
  using (
    tenant_id = (select auth.uid())
    and (select public.current_user_role()) = 'tenant'
  );

drop policy if exists "tenants submit payment proof" on public.payments;
create policy "tenants submit payment proof"
  on public.payments
  for update
  to authenticated
  using (
    tenant_id = (select auth.uid())
    and (select public.current_user_role()) = 'tenant'
    and status in ('due', 'rejected', 'pending_verification')
  )
  with check (
    tenant_id = (select auth.uid())
    and (select public.current_user_role()) = 'tenant'
    and status = 'pending_verification'
    and (
      receipt_path is null
      or receipt_path like ((select auth.uid())::text || '/%')
    )
  );

drop policy if exists "guardians view linked tenant payments" on public.payments;
create policy "guardians view linked tenant payments"
  on public.payments
  for select
  to authenticated
  using (
    (select public.current_user_role()) = 'guardian'
    and exists (
      select 1 from public.guardian_tenant_links
      where guardian_id = (select auth.uid())
        and tenant_id = payments.tenant_id
    )
  );

-- 6. Storage Bucket for Payment Receipts
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'payment-proofs',
  'payment-proofs',
  false,
  5242880,
  array[
    'image/jpeg',
    'image/png',
    'image/webp'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Storage RLS Policies
drop policy if exists "tenants upload own payment receipts" on storage.objects;
create policy "tenants upload own payment receipts"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'payment-proofs'
    and (select public.current_user_role()) = 'tenant'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "tenants read own payment receipts" on storage.objects;
create policy "tenants read own payment receipts"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'payment-proofs'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "staff read all payment receipts" on storage.objects;
create policy "staff read all payment receipts"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'payment-proofs'
    and (select public.is_staff())
  );

drop policy if exists "guardians read linked tenant payment receipts" on storage.objects;
create policy "guardians read linked tenant payment receipts"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'payment-proofs'
    and (select public.current_user_role()) = 'guardian'
    and exists (
      select 1 from public.guardian_tenant_links
      where guardian_id = (select auth.uid())
        and tenant_id::text = (storage.foldername(name))[1]
    )
  );

drop policy if exists "tenants delete own payment receipts" on storage.objects;
create policy "tenants delete own payment receipts"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'payment-proofs'
    and (select public.current_user_role()) = 'tenant'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "staff delete payment receipts" on storage.objects;
create policy "staff delete payment receipts"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'payment-proofs'
    and (select public.is_staff())
  );

-- 7. Add payments to realtime publication
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'payments'
  ) then
    execute 'alter publication supabase_realtime add table public.payments';
  end if;
end $$;

-- 8. Seed initial sample invoices for any existing tenants if payments table is empty
do $$
declare
  t_record record;
begin
  if not exists (select 1 from public.payments limit 1) then
    for t_record in select id from public.profiles where role = 'tenant' loop
      insert into public.payments (
        tenant_id, title, category, amount, due_date, status, created_at
      ) values
        (t_record.id, 'September Rent', 'rent', 3500.00, (current_date + interval '5 days')::date, 'due', now() - interval '2 days'),
        (t_record.id, 'August Utilities (Electricity & Water)', 'utility', 900.00, (current_date - interval '2 days')::date, 'pending_verification', now() - interval '10 days'),
        (t_record.id, 'August Rent', 'rent', 3500.00, (current_date - interval '20 days')::date, 'verified', now() - interval '30 days');
    end loop;
  end if;
end $$;


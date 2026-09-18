-- Allow database records to reference either legacy private Supabase objects or
-- authenticated Cloudinary assets scoped to the current user's folder.

drop policy if exists "tenants update own pending maintenance reports"
on public.maintenance_reports;

create policy "tenants update own pending maintenance reports"
on public.maintenance_reports for update to authenticated
using (
  tenant_id = (select auth.uid()) and status = 'pending'
  and (select public.current_user_role()) = 'tenant'
)
with check (
  tenant_id = (select auth.uid()) and status = 'pending'
  and (select public.current_user_role()) = 'tenant'
  and (
    photo_path is null
    or photo_path like ((select auth.uid())::text || '/%')
    or photo_path like ('cloudinary://authenticated/' || (select auth.uid())::text || '/%')
  )
);

create or replace function public.protect_tenant_maintenance_update()
returns trigger language plpgsql set search_path = '' as $$
begin
  if public.current_user_role() = 'tenant' then
    if old.tenant_id <> new.tenant_id then
      raise exception 'Tenant cannot change maintenance report ownership';
    end if;
    if old.status <> new.status then
      raise exception 'Tenant cannot change maintenance report status';
    end if;
    if old.created_at <> new.created_at then
      raise exception 'Tenant cannot change maintenance report creation time';
    end if;
    if old.status <> 'pending' then
      raise exception 'Only pending maintenance reports can be edited';
    end if;
    if new.photo_path is not null
       and new.photo_path not like (auth.uid()::text || '/%')
       and new.photo_path not like ('cloudinary://authenticated/' || auth.uid()::text || '/%') then
      raise exception 'Tenant cannot attach another user''s maintenance photo';
    end if;
  end if;
  return new;
end;
$$;

drop policy if exists "tenants submit payment proof" on public.payments;

create policy "tenants submit payment proof"
on public.payments for update to authenticated
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
    or receipt_path like ('cloudinary://authenticated/' || (select auth.uid())::text || '/%')
  )
);

create or replace function public.protect_tenant_payment_submission()
returns trigger language plpgsql set search_path = '' as $$
begin
  if public.current_user_role() = 'tenant' then
    if old.tenant_id <> new.tenant_id or old.amount <> new.amount
       or old.title <> new.title or old.category <> new.category
       or old.due_date <> new.due_date or old.created_at <> new.created_at then
      raise exception 'Tenant cannot change invoice fields';
    end if;
    if new.reviewed_by is distinct from old.reviewed_by
       or new.reviewed_at is distinct from old.reviewed_at
       or new.review_notes is distinct from old.review_notes then
      raise exception 'Tenant cannot change payment review fields';
    end if;
    if new.status <> 'pending_verification' then
      raise exception 'Tenant submission status must be pending_verification';
    end if;
    if new.receipt_path is not null
       and new.receipt_path not like (auth.uid()::text || '/%')
       and new.receipt_path not like ('cloudinary://authenticated/' || auth.uid()::text || '/%') then
      raise exception 'Tenant cannot attach another user''s payment receipt';
    end if;
    if new.paid_at is null then new.paid_at = now(); end if;
  end if;
  return new;
end;
$$;

comment on column public.maintenance_reports.photo_path is
  'Legacy private Storage path or cloudinary://authenticated/<owner>/<asset> reference.';
comment on column public.payments.receipt_path is
  'Legacy private Storage path or cloudinary://authenticated/<owner>/<asset> reference.';

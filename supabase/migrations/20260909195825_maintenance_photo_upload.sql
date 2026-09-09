alter table public.maintenance_reports
add column photo_path text;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'maintenance-photos',
  'maintenance-photos',
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
  file_size_limit =
    excluded.file_size_limit,
  allowed_mime_types =
    excluded.allowed_mime_types;


drop policy if exists
  "tenants create own maintenance reports"
on public.maintenance_reports;

create policy
  "tenants create own maintenance reports"
on public.maintenance_reports
for insert
to authenticated
with check (
  tenant_id =
    (select auth.uid())
  and
    (select public.current_user_role())
      = 'tenant'
  and status = 'pending'
  and (
    photo_path is null
    or photo_path like (
      (select auth.uid())::text
      || '/%'
    )
  )
);


drop policy if exists
  "tenants update own pending maintenance reports"
on public.maintenance_reports;

create policy
  "tenants update own pending maintenance reports"
on public.maintenance_reports
for update
to authenticated
using (
  tenant_id =
    (select auth.uid())
  and status = 'pending'
  and
    (select public.current_user_role())
      = 'tenant'
)
with check (
  tenant_id =
    (select auth.uid())
  and status = 'pending'
  and
    (select public.current_user_role())
      = 'tenant'
  and (
    photo_path is null
    or photo_path like (
      (select auth.uid())::text
      || '/%'
    )
  )
);


create or replace function
  public.protect_tenant_maintenance_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if public.current_user_role()
      = 'tenant'
  then
    if old.tenant_id
        <> new.tenant_id
    then
      raise exception
        'Tenant cannot change maintenance report ownership';
    end if;

    if old.status
        <> new.status
    then
      raise exception
        'Tenant cannot change maintenance report status';
    end if;

    if old.created_at
        <> new.created_at
    then
      raise exception
        'Tenant cannot change maintenance report creation time';
    end if;

    if old.status
        <> 'pending'
    then
      raise exception
        'Only pending maintenance reports can be edited';
    end if;

    if new.photo_path is not null
       and new.photo_path not like (
         auth.uid()::text || '/%'
       )
    then
      raise exception
        'Tenant cannot attach another user''s maintenance photo';
    end if;
  end if;

  return new;
end;
$$;


create policy
  "tenants upload own maintenance photos"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'maintenance-photos'
  and
    (select public.current_user_role())
      = 'tenant'
  and
    (storage.foldername(name))[1]
      = (select auth.uid())::text
);


create policy
  "tenants read own maintenance photos"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'maintenance-photos'
  and
    (storage.foldername(name))[1]
      = (select auth.uid())::text
);


create policy
  "staff read maintenance photos"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'maintenance-photos'
  and (select public.is_staff())
);


create policy
  "tenants delete own maintenance photos"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'maintenance-photos'
  and
    (select public.current_user_role())
      = 'tenant'
  and
    (storage.foldername(name))[1]
      = (select auth.uid())::text
);


create policy
  "staff delete maintenance photos"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'maintenance-photos'
  and (select public.is_staff())
);
-- Guardian-to-tenant relationship management belongs exclusively to owners.
drop policy if exists "staff manage guardian links"
on public.guardian_tenant_links;

create policy "owners manage guardian links"
on public.guardian_tenant_links
for all
to authenticated
using ((select public.is_owner()))
with check ((select public.is_owner()));

-- A tenant may have several guardians, but only one can be primary.
create unique index if not exists guardian_links_one_primary_per_tenant
on public.guardian_tenant_links (tenant_id)
where is_primary;

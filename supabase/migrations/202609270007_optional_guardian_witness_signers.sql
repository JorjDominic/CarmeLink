-- Guardian and witness signatures are supplemental and must never block
-- contract activation. Only the authenticated tenant and owner are required.

update public.contract_signers
set is_required = false,
    updated_at = now()
where signer_role in ('guardian', 'witness');

create or replace function public.force_optional_contract_signers()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.signer_role in ('guardian', 'witness') then
    new.is_required := false;
  end if;
  return new;
end;
$$;

drop trigger if exists contract_signers_force_optional on public.contract_signers;
create trigger contract_signers_force_optional
before insert or update of signer_role, is_required on public.contract_signers
for each row execute function public.force_optional_contract_signers();

revoke all on function public.force_optional_contract_signers()
  from public, anon, authenticated;


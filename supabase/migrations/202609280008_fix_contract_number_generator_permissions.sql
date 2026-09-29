-- Column defaults execute with the inserting caller's privileges. Because the
-- generator is intentionally not executable by authenticated users, the old
-- default failed before the privileged BEFORE INSERT trigger could run.
-- Keep generation exclusively in ensure_tenant_contract_number().
alter table public.tenant_contracts
  alter column contract_number drop default;
-- Preserve least privilege: clients create a contract, while the SECURITY
-- DEFINER trigger owns sequence access and assigns the public identifier.
revoke all on function public.next_tenant_contract_number()
  from public, anon, authenticated;

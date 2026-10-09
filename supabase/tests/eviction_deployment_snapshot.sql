-- READ ONLY. Compare existing history before and after eviction deployment.
-- Exclude only newly defaulted case_type plus the earlier compatibility columns.
select 'tenant_contracts' as entity, count(*)::integer as row_count,
  md5(coalesce(string_agg(md5((to_jsonb(t)-'previous_contract_id')::text),'' order by id),'')) as fingerprint
from public.tenant_contracts t
union all
select 'security_deposit_receipts',count(*)::integer,
  md5(coalesce(string_agg(md5((to_jsonb(t)-'transferred_to_contract_id')::text),'' order by contract_id),''))
from public.security_deposit_receipts t
union all
select 'security_deposit_receipt_events',count(*)::integer,
  md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' order by id),''))
from public.security_deposit_receipt_events t
union all
select 'billing_charges',count(*)::integer,
  md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' order by id),''))
from public.billing_charges t
union all
select 'payment_transactions',count(*)::integer,
  md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' order by id),''))
from public.payment_transactions t
union all
select 'tenant_details',count(*)::integer,
  md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' order by profile_id),''))
from public.tenant_details t
union all
select 'move_out_cases',count(*)::integer,
  md5(coalesce(string_agg(md5((to_jsonb(t)-'case_type')::text),'' order by id),''))
from public.move_out_cases t
union all
select 'activation_and_billing_functions',count(*)::integer,
  md5(coalesce(string_agg(md5(pg_get_functiondef(p.oid)),'' order by p.oid::regprocedure::text),''))
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.proname in (
  'activate_tenant_contract','get_my_contract','generate_contract_billing_charges',
  'require_verified_email_for_active_contract','protect_contract_after_signature',
  'guard_contract_price_terms','initialize_contract_deposit_receipt'
)
union all
select 'move_out_deductions',count(*)::integer,
  md5(coalesce(string_agg(md5((to_jsonb(t)-'billing_charge_id'-'deposit_applied_amount')::text),'' order by id),''))
from public.move_out_deductions t
union all
select 'billing_charge_actions',count(*)::integer,
  md5(coalesce(string_agg(md5((to_jsonb(t)-'deposit_deduction_id')::text),'' order by id),''))
from public.billing_charge_actions t
union all
select 'move_out_settlements',count(*)::integer,
  md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' order by case_id),''))
from public.move_out_settlements t
union all
select 'tenant_assignments',count(*)::integer,
  md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' order by id),'')) from public.tenant_assignments t
union all
select 'bed_spaces',count(*)::integer,
  md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' order by id),'')) from public.bed_spaces t
union all
select 'rooms',count(*)::integer,
  md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' order by id),'')) from public.rooms t
union all
select 'contract_documents',count(*)::integer,
  md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' order by id),'')) from public.contract_documents t
union all
select 'contract_signers',count(*)::integer,
  md5(coalesce(string_agg(md5(to_jsonb(t)::text),'' order by id),'')) from public.contract_signers t
order by entity;

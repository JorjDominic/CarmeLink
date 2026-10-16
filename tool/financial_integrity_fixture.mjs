// Relevant real migrations with isolated identity/transport fixtures; no remote services.
import {bootstrapPaymongoFixture,source} from './paymongo_phase1_fixture.mjs';
export async function bootstrapFinancialIntegrity(db) {
 await bootstrapPaymongoFixture(db);
 const utility=source('202609230001_separate_rent_utility_billing.sql');
 await db.exec(utility.slice(0,utility.indexOf('create or replace view')));
 const audit=source('202609260001_audited_billing_actions.sql');
 await db.exec(audit.slice(0,audit.indexOf('create table public.billing_charge_actions')));
 const staff=source('202610080001_staff_received_payments.sql');
 await db.exec(staff.slice(0,staff.indexOf('create or replace function public.review_payment_transaction'))
   .replace('add column received_on date','add column if not exists received_on date')+'commit;');
 const jorge=source('202610080006_jorge_contracts_and_staff_receipts.sql');
 await db.exec(jorge.slice(jorge.indexOf('create or replace function public.record_staff_payment'),jorge.indexOf('--',jorge.indexOf('grant execute on function public.record_staff_payment'))));
 await db.exec(source('202610130004_payment_verification_charge_categories.sql'));
 // Staff-view policies are intentionally retained; direct charge mutation is revoked by utility migration.
 await db.exec(`create function set_updated_at() returns trigger language plpgsql as $$begin new.updated_at=clock_timestamp();return new;end$$;
   create publication supabase_realtime;`);
 await db.exec(source('20260924100000_phase5a_retention_settings.sql'));
}
export async function applyFinancialIntegrity(db) {
 await db.exec(source('202610160008_payment_receipt_integrity.sql'));
 await db.exec(source('202610160009_additional_charge_retries.sql'));
}

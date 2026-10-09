# Contract renewals

The rent agreed in a saved contract stays fixed. A higher rate is entered in a
new renewal agreement and billed only for that agreement's term. The app does
not apply a dorm-wide price increase to existing contracts.

## Owner workflow

1. Open **Contracts**, then choose **Renew** on the tenant's latest active or
   expired contract. An existing draft or later agreement prevents another renewal.
2. Review the current rent and enter the agreed **New monthly rent**. The tenant
   is fixed. Dates default to the day after the old term ends and a one-year term;
   the start must be after the old contract's inclusive end date.
3. Save the renewal as **Draft**. Use **Documents** to generate its new PDF and
   complete the existing document, signing and owner verification process.
4. On or after the new start date, activate the verified draft through
   **Documents**. Activation is manual; advance signing does not activate it.

Activation expires the old active contract, generates rent bills from the new
contract's dates and rent, updates the tenant's active contract dates, and
transfers the held deposit in one transaction. A failed check rolls everything
back. Old signed prices, existing bills and payment history remain unchanged.
No new rent bills are generated just by saving a renewal draft.

The existing deposit terms carry forward. Saving a renewal does not claim a
second deposit payment. Activation moves the confirmed receipt to the new
contract, preserves receipt events, labels the old receipt **Transferred to
renewal**, and prevents the same funds from being settled again against the old
contract. A move-out case or settled/deducted deposit blocks carryover. Deposit
top-ups and replacement deposits are outside this renewal workflow.

Tenants can sign the renewal through their requirements checklist while their
current active contract continues to control app access. Renewal drafts show
the proposed rent and its start date. Signing does not change the current rent.

## Database installation

Apply `supabase/migrations/202610090004_contract_renewals.sql` after the existing
migrations, including contract signatures/onboarding, security deposit receipts,
and automatic deposit receipt initialization. Deploy the app after the schema
update: contract queries now select `previous_contract_id`, and signing uses the
new `get_my_contract_for_signing` RPC.

The migration adds a self-reference to contract history, a unique live successor,
owner-only renewal creation, guards against overlapping terms and early
activation, an audited deposit transfer, and a guard against stale move-out
requests. It retains existing signature, email, emergency contact, required
document and signer activation checks and the existing billing generator.

Migration `202610090004` was applied to the app's linked Supabase project
`iuplkgvitovzjbmtzpme` on **2026-10-09 (Asia/Manila)**. The CLI dry run confirmed
it was the only pending migration. A transaction trial against the deployed
schema passed and rolled back before the migration was committed through
`supabase db push --linked --yes`.

Post-installation schema, enabled triggers, RLS and function grants passed
`supabase/tests/contract_renewal_deployment_verify.sql`. Both new RPCs are
available through the API schema and reject anonymous access. The remote
migration history is up to date.

Before/after aggregate fingerprints matched for all 4 contracts, 41 billing
charges, 5 payment transactions, 4 deposit receipts, 1 deposit receipt event,
2 move-out cases and 5 tenant detail records. The 7 existing activation,
contract protection and billing functions also matched. The comparison uses
`supabase/tests/contract_renewal_deployment_snapshot.sql`; local deployment
snapshots are stored under ignored `build/contract_renewal_deployment`.

The deployment checks do not replace end-to-end testing of document generation,
tenant signing, guardian documents, owner activation, or simultaneous
activation/move-out and receipt updates. Those workflows retain the existing
application approval and signing requirements. Build/reload the updated app
to use the renewal controls and the explicit security-deposit receipt relation.

## Local verification

- `flutter analyze --no-pub`: no issues.
- Focused contract, onboarding and security-deposit Flutter tests: **33 passed**
  (29 UI/model/PDF checks and 4 local API checks).
- `node tool/test_contract_renewals.mjs`: **20 PostgreSQL checks passed**.

The PostgreSQL test uses in-memory PGlite and repository SQL for contract
protection, activation gates, date synchronization, billing and deposit receipt
initialization. Unrelated services use minimal fixtures. It checks original-rent
preservation, save retries, authorization, signing metadata, failed activation
rollback, conflicting contracts, billing periods, deposit carryover, stale
move-out requests, draft cancellation, and subsequent renewals. It does not
connect to Supabase and does not prove full-schema or concurrent deployment behavior.

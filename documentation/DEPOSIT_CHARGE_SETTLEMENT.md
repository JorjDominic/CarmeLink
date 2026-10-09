# Security deposit and damage bills

Staff can propose a move-out deduction for damage, cleaning, replacement,
utilities, or another documented cost. They can select an existing outstanding
bill or propose a new item. The proposal requires an evidence note referring
to inspection photos or repair receipts. Only the owner can approve or reject
it; proposing or approving does not spend the deposit.

When the owner records settlement, approved new items become bills and the
held deposit is applied as audited credits. Existing bills receive credits
against their current outstanding balance, so payments already made are not
charged again. Owner and tenant billing cards show the amount covered by the
deposit. The remaining deposit is refundable; any uncovered damage balance
remains payable and blocks readiness for closure until cleared.

For example, a ₱3,000 deposit and ₱800 damage leave a ₱2,200 refund and no damage
balance. A ₱3,000 deposit and ₱3,800 damage leave ₱800 payable. Multiple approved
items share the same deposit budget, allocated in creation order.

Ordinary rent remains subject to the existing clearance requirement. Contract
termination, ending assignments, and releasing beds remain separate actions.
Renewals still carry the held deposit forward. Existing finalized settlements
are not retroactively converted to bills or credits.

## Accounting and safeguards

- Original bill amounts and genuine tenant payment transactions are preserved.
  Deposit application uses `billing_charge_actions` credits, with a unique link
  to each deduction. It does not create a cash payment.
- Deposit receipts record the amount actually consumed, capped at the held
  deposit; an excess damage assessment is a payable balance, not extra deposit.
- Duplicate active links to a bill, unauthorized writes, invalid currency,
  unreviewed proposals, pending payment proofs, and active payment sessions
  prevent settlement. Increased balances require review before settlement.
- The app submits the displayed totals. Changed balances require refreshing
  and reviewing them before confirmation. Bill credits, new bills, receipt
  changes, and settlement finalization commit together or roll back together.
- Refund method, reference, and an uploaded refund proof remain required when
  money is returned. A shortfall requires a note. Final inspection and
  clearance requirements remain in place.

## Verification and deployment

Migration `202610090005_deposit_charge_settlement.sql` was applied to the linked
Supabase project `iuplkgvitovzjbmtzpme` on October 9, 2026. A full-schema trial
was rolled back before deployment. Post-deployment checks verified the new
columns, RPC permissions, internal credit function restrictions, and the
billing view's existing row security. The remote database is up to date.

Before/after aggregate fingerprints from
`supabase/tests/deposit_charge_deployment_snapshot.sql` matched for existing
contracts, receipts and receipt events, bills and billing actions, payments,
tenant details, move-out cases, deductions and settlements, and seven existing
activation/billing functions. No real tenant settlement was performed for
testing.

Local validation:

- `flutter analyze --no-pub`: no issues.
- Focused move-out, billing, payment model, tenant payment, proposal dialog,
  and local API tests: 38 passed.
- `node tool/test_deposit_charge_settlement.mjs`: 17 PostgreSQL checks passed.
- `node tool/test_contract_renewals.mjs`: 20 existing renewal checks passed.

The SQL tests run in isolated PGlite using repository ledger, review,
settlement, receipt, and closure functions with fixtures for other services.
They require the same local PGlite installation used by the renewal test
script under `build/phase2_sql_tests`. They cover partial/full payments,
multiple deductions, zero/exact deposits, shortfalls, duplicate applications,
permissions, payment blockers, and rollback. They do not prove simultaneous
production transactions or replace end-to-end testing of inspection and
refund-proof uploads. Rebuild/reload the app to use the updated controls.

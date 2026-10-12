# Payment balance and drill-down audit — October 12, 2026

## Verified live findings

The staff Payments outstanding balance is PHP 9,229 across four bills:
PHP 2,500 rent, PHP 2,800 rent, PHP 3,829 electricity and PHP 100 damage.
The electricity and damage bills have future due dates. They are issued charges
and contribute to outstanding balance; scheduled future rent and deposits do not.
Outstanding balance is therefore different from money due today.

The card previously selected the Due filter, which excluded overdue rent and
upcoming issued charges. Its count also mixed separate status counts rather than
counting the actual bills contributing to the amount. Existing search text could
further hide contributing bills.

Tenant and guardian controllers excluded upcoming utilities and other charges,
while staff FinancialSnapshot included them. Billing's summary excluded all
upcoming charges. These calculations now share outstandingBills.

The live billing summary audit found zero discrepancies between adjusted bill
amount, verified ledger payments, deposit allocations and remaining balance.
PaymentService and GuardianService read the same billing_charge_summaries view.
The table refresh service already expands legacy payments subscriptions to
billing_charges, payment_transactions and billing_charge_actions, with a 30-second
catch-up timer. Live publication contained the first two tables, but not actions
or PayMongo sessions. Actions can change summaries without changing the bill row.

## Changes

- Outstanding card opens its actual contributing bills and clears search.
- Counts and metrics use the same scoped list, including notification targets.
- Collected drill-down includes partially paid bills with verified collections.
- Tenant, guardian and Billing balance calculations use the same issued-charge rule.
- Tenant billing details say Outstanding bills rather than Due now.
- Billing summary explains that deposits and future rent are excluded.
- Payment refresh subscriptions include PayMongo sessions.
- Migration 202610120003 adds actions and gateway sessions to Realtime publication
  without modifying RLS or granting additional access.

## Verification and limits

78 Flutter tests passed across accounting policies, payment models, staff and
tenant payment views, guardian views, controller behavior, PayMongo views and
narrow layouts. The reproduction test verifies the four bills totaling PHP 9,229
remain visible after tapping Outstanding, including after a previous search.
Targeted analysis passed. Local PostgreSQL verifies publication repair,
idempotency, missing-publication handling and unchanged RLS.

The database publication repair was deployed separately from the pending advance
rent migration. The application changes require a rebuilt/released client.
Cross-device event delivery was not exercised on physical devices. No bill amounts
or payment ledger entries were changed by this repair.

# Jorge feedback - October 8, 2026

Implemented in the Flutter app and two new Supabase migrations:

- Add room suggests the first unused positive room number, starting at 1. Existing room identifiers, assignments and drawing positions are preserved.
- Private report follow-up messages/corrections are expanded by default. Tenants can append messages to their own reports; the original submission remains in the history. Existing authorization, notifications and retry deduplication are retained.
- Removed Adjust future rent. Saved contract rent and deposit fields are read-only, with a database guard. New prices require a new contract; existing contract activation generates rent from that contract and existing creation automation records its deposit. Historical ledger entries are preserved.
- Staff-collected payments use Face-to-face receipt with no method selector. The database generates a stable F2F receipt reference from the receipt request UUID, ignoring caller-supplied method/reference values. The displayed reference is read-only.
- The tenant/bill selector separates Overdue and Upcoming / due today, sorts by due date and clears selection when changing groups. Paid, voided, pending-proof and deposit bills are excluded.
- Saved staff payment receipts open an 80 mm PDF through the platform print dialog. Reviewed payment cards also support reprinting their latest confirmed receipt. Use a printer exposed by the browser/OS print system; proprietary Bluetooth-only protocols are not implemented. No physical printer was available for testing.
- Staff maintenance photos now use Cloudinary authorization for Cloudinary references and retain legacy Supabase Storage/HTTP support.
- Removed the Operations navigation item for owners/caretakers; management shortcuts remain available.
- Added the nightly 11 PM Asia/Manila curfew snapshot. For every tenant profile, it persists notifications for the tenant, linked guardians, all owners and all caretakers. IN/OUT comes from recorded gate presence; unavailable presence is reported explicitly. This is a status report, not a new location measurement or automatic violation. Existing push delivery handles retries. The UTC cron schedule is 15:00; daily event keys prevent duplicate notifications.

## Rollout

Applied `202610080006_jorge_contracts_and_staff_receipts.sql` and
`202610080007_nightly_curfew_status.sql` to the linked live Supabase project on
October 8, 2026. A subsequent CLI dry run confirmed the remote database is up to
date. The updated app screen had been calling the old staff payment function,
which rejected the new `f2f` method with "Choose an active payment method".
The migrated function generates the reference and fixes the method server-side.
The payment and curfew PostgreSQL checks passed before applying the migrations.
No tenant payment was created during this fix; retry the existing receipt request
in the app. The request UUID remains the idempotency key to prevent duplicates.

The Flutter application was not rebuilt or published by this task. Release the
updated app for clients that have not yet received the UI changes.

Curfew push delivery relies on the existing notification queue, configured push
Edge Functions/credentials, and recipient push tokens. The Cloudinary URL Edge
Function must already be deployed and configured. Validate notification delivery
on physical devices and printing with the intended printer during rollout.

## Local validation

- Flutter analyzer and relevant widget/model tests.
- Receipt PDF generation and validation tests.
- `tool/jorge_staff_payment_local_test.mjs`: local PostgreSQL tests for staff role
  access, generated references/fixed method, receipt scope, partial/full payments,
  retries, overpayment, pending proofs, void/deposit guards and contract pricing.
- `tool/nightly_curfew_local_test.mjs`: local PostgreSQL tests for Philippine time,
  every recipient, IN/OUT/unavailable states, queue metadata, daily deduplication,
  next-day refresh and restricted execution. The controlled clock and scheduler
  fixtures do not contact the live backend.

The SQL tests take a PGlite module path as their first command-line argument.

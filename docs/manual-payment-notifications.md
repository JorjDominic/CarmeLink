# Manual payment notifications

Migration `202610180001_manual_payment_notifications.sql` persists payment
notifications in the same transaction as the manual payment ledger event.
Each event notifies the tenant, linked guardians, owner, and caretaker, including
the person who performed the action:

| Event | Notification |
| --- | --- |
| Manual proof submitted | Proof submitted; awaiting staff review |
| Manual proof approved | Payment approved and credited |
| Manual proof rejected | Rejection result with the review reason, if supplied |
| Face-to-face payment recorded | Payment received and credited |

Every notification enters the existing `notification_push_jobs` queue via
`server_push=true`. The `process-report-pushes` worker delivers queued FCM
pushes and retries failures. The saved alert also appears in the in-app inbox.
Routes point to the bill; metadata includes the individual transaction ID.

The trigger handles new proofs, pending-to-reviewed transitions, and new staff
receipts. Unchanged statuses, receipt recovery, and retries of an existing staff
request do not send another alert. PayMongo and security deposits keep their
existing separate workflows. Historical transactions are not backfilled.

Apply this migration before releasing the updated `PaymentService`, which no
longer dispatches manual payment alerts from the client. Older app versions still
make the old notification calls and can produce duplicate alerts until updated.
The existing queue worker, cron, FCM credentials, and device registration must be
operational for phone push delivery. Web/desktop continue to use the in-app inbox.

Local regression: `node tool/test_manual_payment_notifications.mjs` uses an
isolated PostgreSQL engine and verifies recipients, queue entries, review
transitions, duplicate suppression, gateway/deposit exclusion, and rollback.

On 2026-10-18, the deployed database was found to be missing this trigger and
the `process-report-pushes` Edge Function. Migration 202610180001 was applied
and the worker deployed. At the user's request, 312 historical queued pushes
were suppressed while preserving their inbox rows. The recent missing manual
payment review alert was recovered; FCM accepted delivery to the owner and tenant.
The caretaker had no active device token and retained an inbox alert.

Migration `202610180003_payment_test_notification_labels.sql` changes automatic
sandbox notifications to use a `(TEST)` suffix, normalizes saved inbox wording,
and includes the tenant and amount in future confirmations. App payment labels,
receipt headings, and financial report labels follow the same suffix convention.
Sandbox payments simulate confirmation and may credit sample bills; no real
money is received. Test credits remain excluded from actual collection totals.

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

# Pay Now and expired PayMongo QR requests

Opening Pay Now for an unpaid bill now asks the backend to prepare a usable
request. Valid requests are reused. Expired/failed/cancelled requests can be
replaced in the same create operation after provider verification. The general
payment page still lets tenants select rent months before generating a request.
Existing active multi-month requests retain their full bill selection when
reopened from one included rent bill.

QRs have a 30-minute validity window; generating one daily would not keep it
valid throughout the day. No background job generates new unpaid payment requests.

Some sandbox intents remain `awaiting_next_action` after their recorded QR
deadline. Synchronization now requests provider cancellation for these overdue
waiting intents, then reads the provider again. Only confirmed cancellation or
provider-reported expiry/failure releases the old request for replacement. Paid
results settle through the existing idempotent ledger RPC; processing and
needs-review requests remain reserved. Uncertain cancellation/provider responses
never release the reservation based on the clock alone.

Expired QR images and simulation links are hidden. The client exposes **Generate
new QR** for terminal requests and displays processing/reconciliation issues.
An ordinary Pay Now opening prepares or resumes the request without requiring a
second Generate tap. Confirmed-payment pages retain their existing receipt flow.

The existing billing RPC locks selected bills, so replacement uses the same
concurrency and balance validation as first-time creation. Repeated taps reuse
the active replacement or its creation lease. The old request remains in history.
The QR deadline is saved after successful attachment, matching the start of the
payment-method validity window.

Deploy `paymongo-payments`, `paymongo-webhook` and
`reconcile-paymongo-payments`; each packages the shared synchronization code.
No database migration is required. Updated client builds are needed for automatic
preparation on opening Pay Now and the new QR visibility/button behavior.

Validation covers provider-confirmed retirement and fresh QR creation, reuse,
payment racing cancellation, processing/reconciliation protection, cancellation
refusal, unavailable provider rechecks, webhook settlement, Flutter Pay Now,
multi-month selection and receipt recovery.

Provider reference: [PayMongo QR Ph API](https://docs.paymongo.com/docs/payment-acceptance-qr-ph-api)
and [payment intent states](https://docs.paymongo.com/docs/payment-acceptance-key-concepts).

Deployment: the three Edge Functions were redeployed for this fix. Focused
validation passed: 20 provider/webhook tests, 22 isolated billing SQL checks,
14 Flutter payment/receipt tests, Edge Function type checking and changed-source
Flutter analysis. Updated client builds and a physical-device walkthrough remain.

## October 19 sample-bill registration repair

The connected demo project had 153 non-deposit bills and zero registered test
bills. The workspace reset script includes `paymongo_test_bills` in its cleared
tables, consistent with the empty registry after rebuilding sample data. Test
configuration remained enabled, so the environment guard rejected those bills
before a QR could be created. This is separate from QR expiry.

Given the user's existing confirmation that this project contains only sample
data, all 153 current non-deposit bills were explicitly registered. The repair
required test mode, staging configuration and enabled demo credits; it did not
change balances, create payments or remove production/test isolation. The guard
was verified after registration. The earlier paint/October payment requests were
no longer present in the rebuilt data, so no old request statuses were manually
rewritten.

After creating new sample bills or resetting/rebuilding demo data, register the
intended sample bills again before testing. Registration is intentionally not
automatic for arbitrary bills, and sandbox payments remain disabled for
unregistered bills. Do not use sample registration to enable simulated credits
against real tenant billing.

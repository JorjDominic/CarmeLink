# Payment collection: manual and PayMongo QR Ph

Owners control the dormitory-wide mode in Billing on web and mobile. The
authenticated edge endpoint and database RPC enforce owner access. Caretakers
can review manual receipts, record payments received in person, and check or
cancel active gateway requests; they cannot change the mode or gateway readiness.

## Working without keys

Manual mode remains active. Automatic mode is disabled until configuration is
present and the owner enables it. No account, API key, or payment provider call
is required for **Try payment demo (no keys needed)** in the owner's Billing
card, or the demo button in tenant Payments. The demo uses a local sample bill
and a QR encoding demo text only. Success, failure, expiry, and cancellation
do not write to Supabase or change tenant balances.

The demo works with the same Flutter screen on web, Android and iOS. Physical
iOS builds still require the normal macOS/Xcode release process. It is not a
completed payment on PayMongo and does not validate merchant API access.

## Configure PayMongo sandbox on disposable staging only

Follow [Phase 1 validation and setup](phase1-paymongo-validation.md). Test payments
are blocked by default: both backend project pinning and database sample-bill
registration are required. Never perform this setup on the production project.

1. Create a PayMongo account and obtain public and secret **test** keys.
2. Register an enabled webhook pointing to
   `https://<STAGING_PROJECT_REF>.supabase.co/functions/v1/paymongo-webhook`,
   subscribed to `payment.paid`, `payment.failed`, and `qrph.expired`.
3. Store these in Supabase Edge Function secrets, never Flutter, source code or chat:
   `PAYMONGO_PUBLIC_KEY`, `PAYMONGO_SECRET_KEY`, `PAYMONGO_WEBHOOK_SECRET`,
   and `PAYMONGO_ENVIRONMENT=test`. Also set
   `PAYMONGO_DEPLOYMENT_ENVIRONMENT=staging` and pin
   `PAYMONGO_TEST_SUPABASE_URL` to that disposable project's `SUPABASE_URL`.
4. Refresh the owner's Billing setting and select Automatic. The backend checks
   the merchant credentials and matching enabled webhook before saving the mode.
5. Create a payment request against a sample unpaid bill. Use **Open test payment
   page** to simulate a provider outcome. The app displays a demo QR encoding nonpayment text instead of the provider
   test QR. Complete the simulation through the test URL. Live mode displays
   the actual provider payment QR.
6. Check successful/failed/expired requests and repeat callbacks. Provider test
   confirmations credit only registered sample bills in an explicitly marked
   local/staging database with `demo_test_credits=true`. Production defaults
   reject sandbox creation and settlement even if the legacy flag is true.
   Test receipts are labelled as invalid for official collection.

If a response omits the provider test URL, the app does not invent a payment
link. Check the account/API response before continuing provider testing.

## Payment and verification behavior

- The backend derives outstanding bill amounts in centavos. Tenants may pay one
  bill or select multiple scheduled rent months in one QR payment. They cannot
  choose another tenant's bill, override amounts, or pay deposits here.
- Rent selection shows each month's billing period, due date, remaining amount,
  and the combined total. Months come from existing contract/staff rent bills;
  this does not create charges beyond the contract or hold unallocated credit.
  The session saves an immutable month breakdown, available after confirmation
  through **View payment breakdown** on each credited tenant bill and on active
  staff requests. One confirmed provider payment creates one ledger entry per
  selected bill with the same provider reference.
- Overlapping active requests block new payments and staff receipts for every
  selected month. Confirmation validates all balances before crediting any month.
  A changed/voided bill sends the entire payment to staff reconciliation, with no
  partial allocation. Repeated confirmations never credit the months twice.
- An active session is reused per exact bill selection/environment. Provider creation stages
  use distinct, stable idempotency keys. Interrupted stages retain IDs and may
  resume after a lease; creation is not retried beyond the key lifetime.
- Payment confirmation requires a fresh secret-key provider read matching the
  session, bill metadata, exact PHP amount, environment, paid transaction, and
  QR Ph source. Neither a client success screen nor an unverified callback pays
  a bill. Webhooks validate the raw-body HMAC and timestamp first.
- Only the service role can settle payments. For the current demo, test
  confirmations create labeled verified `payment_transactions` only for
  registered sample bills, with explicit local/staging opt-in and
  `payment_collection_settings.demo_test_credits=true`. The flag alone never
  authorizes production test credits. Live confirmations create one verified transaction
  per selected bill with immutable gateway provenance and a provider payment reference.
- Owners remain the enabling actor in the existing required reviewer field;
  review notes explicitly identify automatic provider confirmation. This is
  not a manual owner approval. Live confirmation notifies the tenant/guardian.
- An unpaid active live request (or test request with demo credits enabled) blocks a second staff receipt until cancelled
  or reconciled. Existing pending manual proofs remain reviewable after switching
  modes. New tenant proof submissions are rejected while automatic is selected.
- Switching to Manual saves the mode first to stop new automatic requests, then
  automatically checks and cancels all unpaid QR requests with the provider.
  Failed cancellations display a retry action; requests stay protected until
  provider cancellation is confirmed. Payments already received still settle or
  remain available for staff reconciliation. Duplicate callbacks never double-credit.
- A changed or voided bill puts received money into `needs_review`, visible to
  staff and notified for reconciliation. It is never silently discarded or credited
  twice. Resolve bill adjustments or handle a refund through PayMongo, then refresh
  the request. Refund automation is outside this implementation.
- A private cron job checks stale requests every five minutes, with bounded
  batches and leases. It reuses the existing private dispatch credential and
  skips when unconfigured. QR expiry is confirmed against the provider, not
  inferred solely from a device clock.

## Live activation

Use live keys only after merchant approval and a successful provider sandbox
test. Reconcile active requests before changing credentials/environments. Set
`PAYMONGO_ENVIRONMENT=live` and `PAYMONGO_ALLOW_LIVE=true` explicitly; the default
is test and live processing is otherwise disabled. Refresh and enable the mode
through the owner UI, set `demo_test_credits=false` in the database, then perform an approved live smoke test. Receiving money,
settlement, account eligibility and fees remain subject to PayMongo approval.

Ordinary transfers to a personal bank/GCash account cannot be automatically
verified by this integration. Only bill-linked PayMongo QR Ph payments qualify.

## Verification

Advance payment rollout requires applying
`202610120001_paymongo_advance_rent.sql`, deploying the updated `paymongo-payments`
function, and releasing the updated Flutter app, in that order. The migration
backfills month breakdowns for existing sessions and retains their provider IDs.

- `flutter test test/views/payment_collection_settings_card_test.dart test/views/paymongo_payment_page_test.dart test/views/tenant_payments_test.dart`
- `npx --yes deno test --allow-env supabase/functions/_shared/paymongo_test.ts`
- `node tool/staff_payment_local_smoke_test.mjs <path-to-pglite/dist/index.js>`

No provider transaction has been executed without merchant keys. The mocked
gateway tests and isolated PostgreSQL tests verify logic, not merchant enablement.

References: [QR Ph API](https://docs.paymongo.com/docs/payment-acceptance-qr-ph-api),
[Sandbox testing](https://docs.paymongo.com/docs/payment-acceptance-testing),
[Webhook verification](https://docs.paymongo.com/docs/developer-tools-webhook-setup-management),
[Idempotency](https://docs.paymongo.com/reference/idempotent-requests).

# Phase 1: PayMongo simulation and automatic verification

Date: 2026-10-16. Phase 1 only. No production configuration, tenant or financial
records, deployments, commits, pushes, merges, or Phase 2 work.

## Completion status

| Area | Status | Evidence and limits |
|---|---|---|
| Existing QR Ph checkout, verification, cancellation and resume | ALREADY IMPLEMENTED AND VERIFIED | Backend regressions and HTTP handler tests with mocked provider responses. No real provider checkout was run. |
| Backend test/live project separation | COMPLETED AND TESTED | Explicit nonproduction environment and matching project pin required for test keys; staging rejects live keys. |
| Database test-credit isolation | COMPLETED AND TESTED | Actual migrations executed in isolated PostgreSQL. Production default rejects test requests/credits. Only registered sample bills on explicitly opted-in local/staging databases can be credited. |
| Amount, currency, provider/session/bill/tenant checks | COMPLETED AND TESTED | Authenticated provider reads plus database ownership/allocation guards. New metadata includes tenant ID; legacy sessions still rely on their immutable session/bill association. |
| Signature validation | ALREADY IMPLEMENTED AND VERIFIED | Exact raw-body HMAC, environment-specific signature and freshness. HTTP rejection tests run before provider lookup. |
| Idempotent allocations and receipts | COMPLETED AND TESTED | Local SQL verifies exact individual obligations, stable receipt identities, sequential replay, partial balances and changed-bill reconciliation. Independent-session races remain unrun. |
| Automatic receipt record and PDF preparation | COMPLETED AND TESTED | Verified transactions create receipt snapshots. Opening/synchronizing a confirmed payment prepares PDFs using the existing generator. No backend PDF binary is stored; reopening can regenerate the same numbered receipt. |
| Receipt failure recovery | COMPLETED AND TESTED | Snapshot-generation failure does not roll back settlement; authorized reads regenerate using the transaction ID. Flutter rendering/printing failures preserve confirmation and allow retry. |
| Notification failure recovery | COMPLETED AND TESTED | Existing emitters reused. A pending flag permits status/webhook/reconciliation retry without reversing settlement. Transport failures are injected locally; actual push delivery is not tested. |
| Manual proof/OCR/reviewer fallback | ALREADY IMPLEMENTED AND VERIFIED | Existing flow retained; payment regressions and local ledger tests. Screenshots never establish gateway settlement. Actual camera/OCR devices remain external testing. |
| Application target override | IMPLEMENTED BUT NOT VERIFIED | URL/key build-time overrides and missing-pair check added. Staging initialization and authenticated sign-in need external testing. |
| Actual PayMongo test account and secrets | BLOCKED BY CONFIGURATION | User confirmed no staging project. No gateway secrets supplied or used. |
| Actual checkout, webhook and multi-role staging flow | PENDING EXTERNAL TESTING | No test records created in linked production. Real sandbox outcomes, reopen persistence and matching staff records remain pending. |
| Independent-session races | PENDING EXTERNAL TESTING | Local PostgreSQL unavailable. Guarded runner prepared; sequential PGlite results do not establish race safety. |
| Live GCash/bank-app settlement | PENDING EXTERNAL TESTING | Test-page simulation does not establish live scanning, merchant settlement, fees or eligibility. |
| Tax-compliant official document | NOT IMPLEMENTED | Payment acknowledgments are not represented as approved tax-document issuance. Test receipts explicitly exclude official collection. |

## Existing implementation and dependencies

- `supabase/functions/_shared/paymongo.ts`: provider client, key-mode checks,
  intent validation, QR/test URL validation and webhook HMAC. Depends on PayMongo
  Payment Intent/Payment Method API and configured test webhook secret.
- `supabase/functions/_shared/paymongo_store.ts`: resumable creation with stable
  idempotency keys, trusted provider re-read, cancellation and settlement RPC.
- `supabase/functions/paymongo-payments/handler.ts`: authenticated requests,
  owner-only mode switch, tenant-only creation and RLS status access.
- `supabase/functions/paymongo-webhook/index.ts` and `handler.ts`: existing webhook
  logic extracted behind a test seam, not a second gateway integration.
- `supabase/functions/reconcile-paymongo-payments/index.ts`: existing bounded
  reconciliation worker; depends on private dispatch credential and existing cron.
- Existing migrations `202610080004_paymongo_qr_payments.sql`,
  `202610110001_demo_test_payment_credits.sql`, and
  `202610120001_paymongo_advance_rent.sql`: sessions, service-only settlement,
  ledger provenance, multi-month breakdown and manual-allocation guards. The old
  demo flag alone previously allowed shared-ledger credits.
- `lib/services/paymongo_payment_service.dart` and
  `lib/views/shared/paymongo_payment_page.dart`: checkout, failure states, safe
  test-page opening, existing eight-second active-request status checks, persistent
  session resume and multi-bill breakdown. No additional polling added.
- `lib/services/payment_service.dart`, `lib/models/models.dart`, existing billing
  summaries and tenant/staff views: individual contractual obligations and verified
  balances. The gateway does not calculate room sharing or modify contracts.
- `lib/services/receipt_print_service.dart`: existing PDF/print generator reused.
- `lib/views/tenant/tenant_pages.dart`: manual proof/OCR and gateway history link.
- `lib/views/owner/owner_pages.dart` and
  `lib/views/shared/staff_payment_received_dialog.dart`: authorized receipts and
  manual records. Staff history printing now uses the saved transaction snapshot.

## Targeted changes

New migration: `202610160002_paymongo_test_isolation_and_receipts.sql`. It adds
default-deny test configuration and sample-bill registration; wraps existing bill
selection; preserves existing settlement/lock order; makes session environment and
enabling owner immutable; adds receipts, authorized regeneration and notification
retry. Existing migrations and historical balances are not rewritten.

Authenticated clients cannot change the safety configuration or sample registry.
`demo_test_credits` defaults to false for new settings rows and cannot bypass the
production guard even when an old row still has true.

Receipt IDs use verified transaction IDs and deterministic unique receipt numbers.
Snapshots include tenant, bill, amount, method, reference, verification/receipt
timestamps, environment and balance after payment. Repeated callbacks or receipt
regeneration do not create payments. Manual receipt printing remains available.
Test documents display `TEST TRANSACTION - NOT VALID FOR OFFICIAL COLLECTION`.

Notification retries reuse existing emitters and deduplication keys. The existing
reconciliation claim and private dispatch predicate include confirmed sessions
with pending notifications; no separate polling service is introduced.

## Disposable staging setup: not performed

1. Create a separate disposable Supabase project with no production tenants,
   contracts or financial records. Apply the repository migrations there.
2. Create sample Owner/Caretaker/Tenant accounts and a sample contract through
   existing workflows. Generate normal individual bills; do not copy production.
3. Only in that verified disposable database, set
   `paymongo_test_configuration.deployment_environment='staging'`, explicitly set
   `payment_collection_settings.demo_test_credits=true`, and register the exact
   sample charge IDs in `paymongo_test_bills`. Leave other bills unregistered.
4. Configure staging Edge Function secrets privately:
   - `PAYMONGO_PUBLIC_KEY` and `PAYMONGO_SECRET_KEY` with test prefixes.
   - `PAYMONGO_WEBHOOK_SECRET` for the staging test webhook.
   - `PAYMONGO_ENVIRONMENT=test`.
   - `PAYMONGO_DEPLOYMENT_ENVIRONMENT=staging`.
   - `PAYMONGO_TEST_SUPABASE_URL` matching staging `SUPABASE_URL`.
   - Supabase-provided service-role credential and project configuration.
   Do not enable live processing, print secrets, or put secrets in Flutter/source.
5. Register the test webhook on staging `/functions/v1/paymongo-webhook` for
   `payment.paid`, `payment.failed`, and `qrph.expired`. Deploy existing payment
   functions to staging only. Enable Automatic through its owner interface.
6. Build Flutter with both `--dart-define=SUPABASE_URL=<staging-url>` and
   `--dart-define=SUPABASE_PUBLISHABLE_KEY=<staging-publishable-key>`. One override
   without the other is rejected. PayMongo secrets/service-role credentials do not
   belong in build flags. Keep staging app sessions separate from production.
7. Select a registered sample bill, create a request, and open the provider's
   returned **test payment page**. Do not scan/pay the provider test QR. The app
   displays a nonpayment QR. A missing test URL is a limitation, never fabricated
   checkout success.
8. Confirm actual webhook delivery, trusted provider re-read, ledger entry, exact
   balance, receipt/PDF, owner/caretaker view and close/reopen persistence.
9. Repeat supported failure/cancellation/expiry scenarios, duplicate/out-of-order
   callbacks, delayed confirmation, manual/gateway overlap and receipt retry.
   Check unchanged original contracts, deposits, credits and bill facts.

[PayMongo testing documentation](https://docs.paymongo.com/docs/payment-acceptance-testing)
directs QR Ph simulation through `test_url` and warns against scanning/paying test
QR codes. This phase reuses QR Ph. It does not introduce separate direct GCash or
direct-bank-transfer checkout. Transfers outside the gateway retain manual review.

## Validation and reproduction

Prerequisites: Flutter, Node, Deno (or npm-executed Deno), and the existing ignored
`build/phase2_sql_tests` PGlite/pg tools. If absent, install those test dependencies
in that ignored directory. No runtime application package is added.

- `node tool/test_paymongo_phase1.mjs`: 22 isolated PostgreSQL checks using actual
  gateway migrations, ledger view, RLS and financial-fact guards. Identity and
  notification transport use fixture stubs.
- `npm exec --yes --package=deno -- deno test --allow-env --allow-net supabase/functions/_shared/paymongo_test.ts supabase/functions/paymongo-webhook/handler_test.ts`:
  25 backend checks. Provider responses are mocked; no real gateway payments.
- Flutter: **99 tests passed** across payment UI, receipt recovery, manual fallback,
  tenant/staff views, payment models/controller/services, OCR, financial totals,
  billing policy and narrow-screen regressions.
- `flutter analyze --no-pub`: no issues. Modified Dart files formatted.
- Deno checked the payment, webhook and reconciliation entrypoints successfully.
- `git diff --check`: passed. Existing PDF built-in font warnings remain; sample
  receipt text extraction passed, but extended-character names need device review.
- Actual generated test/manual PDFs were inspected with `pypdf`: test notice,
  tenant, bill, amount, reference, verification date and balance snapshot passed.
  Sample artifacts are under ignored `build/phase1_payment_validation`.
- `tool/test_paymongo_phase1_concurrency.mjs` is **not successfully executed**.
  It requires `--disposable --local-config <private connection JSON>` for an EMPTY
  loopback PostgreSQL database named `phase1_paymongo_validation_<suffix>`. It
  rejects remote hosts, proves lock overlap with independent sessions, and checks
  request reuse and single-allocation/single-receipt settlement. Sequential
  PGlite tests cannot substitute for it.

## Modified file inventory

Application files:

- `lib/core/config/supabase_config.dart`
- `lib/services/payment_service.dart`
- `lib/services/paymongo_payment_service.dart`
- `lib/services/receipt_print_service.dart`
- `lib/views/owner/owner_pages.dart`
- `lib/views/owner/payment_collection_settings_card.dart`
- `lib/views/shared/paymongo_payment_page.dart`

Backend/schema files:

- `supabase/functions/_shared/paymongo.ts`
- `supabase/functions/_shared/paymongo_store.ts`
- `supabase/functions/paymongo-webhook/index.ts`
- `supabase/functions/paymongo-webhook/handler.ts`
- `supabase/migrations/202610160002_paymongo_test_isolation_and_receipts.sql`

Validation/documentation files:

- `supabase/functions/_shared/paymongo_test.ts`
- `supabase/functions/paymongo-webhook/handler_test.ts`
- `test/views/paymongo_payment_page_test.dart`
- `test/views/paymongo_receipt_recovery_test.dart`
- `test/services/receipt_print_service_test.dart`
- `tool/paymongo_phase1_fixture.mjs`
- `tool/test_paymongo_phase1.mjs`
- `tool/test_paymongo_phase1_concurrency.mjs`
- `docs/payment-collection-mode.md`
- `docs/phase1-paymongo-validation.md`

## Release limitations and suggested Git sequence

No staging project, gateway secrets, reachable test webhook, authenticated staging
users, physical-device checks or live payment verification are available. No actual
end-to-end PayMongo success is claimed. The migration and matching app/functions
need review together before a later rollout. Existing production sessions and old
test entries require rollout review. Push transport and cron credentials need
staging verification.

Suggested commits, not executed:

1. `Guard PayMongo sandbox credits and retry failed payment notifications`
2. `Create stable payment receipts and add safe client PDF regeneration`
3. `Add Phase 1 payment security tests and staging validation guide`

Do not deploy, commit, push or start Phase 2 automatically.

# Full-system QA — October 9, 2026

Automated checks pass after the repairs below. This is **not full production
sign-off**: physical-device tests, authenticated live workflows, payment-provider
testing, signing, and the report-push deployment still have gaps.

## Results

| Check | Result |
|---|---|
| Full Flutter suite | 861 tests passed, zero failures, across 163 test files |
| Final PDF/table refinement | 8 additional financial/export checks passed |
| Flutter analyzer | No issues |
| Web release build (`lib/main_web.dart`) | Passed |
| Android debug APK | Passed using Android Studio JBR 21 |
| Android native unit tests | 6 passed; explicitly rerun |
| Existing isolated backend checks | All 14 Node/PostgreSQL/attachment suites passed |
| New boundary/access repair checks | 7 passed |
| Combined lease/deposit/eviction/financial checks | 19 passed |
| Edge-function tests | 20 passed across payment, geofence, location alerts, and report delivery |
| Edge-function type checks | All 16 entrypoints passed Deno checking |
| Browser smoke tests | Desktop 1440×1000 and mobile 390×844 passed |
| Migration synchronization | All 121 migrations installed; no pending migrations |
| Client database-function inventory | All 122 client-called RPC names installed |
| Database access metadata | All 79 public tables have RLS; no anonymous public-table policies remain |
| Anonymous gate-history HTTP check | Denied with HTTP 401; zero-row request, no tenant data retrieved |
| Database integrity metadata | No invalid indexes, unvalidated constraints, disabled triggers, or definer functions missing search paths |
| Existing-record preservation | All 16 fingerprint groups unchanged; saved boundary geometry unchanged |
| Repository guardrails and whitespace | Passed |

The RPC inventory checks function presence, not every argument combination or
business transition against production. RLS metadata checks also do not replace
authenticated, role-by-role live authorization tests.

## Repairs completed

1. **Gate-history privacy:** the live database allowed anonymous reads of gate
   events. Removed that policy and revoked anonymous table access. Existing
   authenticated tenant, linked-guardian, and staff policies remain.
2. **Boundary editor:** the client called `update_dorm_boundary_config`, but the
   deployed database did not have the function despite migration history being
   current. Restored it with owner/caretaker authorization, coordinate and polygon
   validation, row locking, and configuration-version increments. Deployment did
   not change the property's saved boundary.
3. **Small-screen layout:** finance and analytics export cards overflowed at
   320-pixel width and with 1.6× text scaling. They now stack their descriptions
   and export controls when needed. Existing responsive tests pass.
4. **Financial totals:** finance and PDF summaries treated future/voided bills
   as dues and skipped cash collected through partial payments. Charge summaries
   now expose the actual sum of verified transactions. The dashboard, finance,
   analytics, and PDF summaries share one calculation. Future rent and voided
   bills do not inflate dues; rejected proofs leave their balance payable;
   deposit credits remain separate from cash collections. PDF rows distinguish
   bill amount, verified cash, and balance, and do not invent a payment method
   when none is recorded.
5. **Partial-payment proof review:** a pending proof could be hidden by the
   charge's earlier partial-payment status. Pending proofs now remain in review
   while earlier verified cash and the unpaid balance remain intact.
6. **Stale test expectations:** corrected old navigation/label assertions,
   whitespace-sensitive source matching, and maintenance fixtures overwritten by
   the page's initial refresh. Current behavior remains covered; production
   behavior was not changed to restore obsolete labels or routes.

Database repairs were applied through migrations `202610090008`,
`202610090009`, and `202610090010`, each with a schema-only rollback trial first.
The financial view retains `security_invoker=true`, so reads continue to use
the caller's existing RLS permissions. Stored lease terms, charges, payments,
deposits, and assignments were not rewritten.

## Functional coverage

| Area | Evidence and limits |
|---|---|
| Authentication, recovery, role navigation | Controller/widget tests; browser staff sign-in and empty-form validation. No real password-reset email sent. |
| Tenant, guardian, caretaker, owner screens | Full widget/model/controller suite, responsive layouts, navigation and notification routing. |
| Contracts, renewals, room transfers | Isolated SQL authorization, signing, activation, original-term preservation, reservations and retry checks. |
| Billing, receipts, deposits, eviction | SQL and Flutter checks for balances, payment review, deposit credits, finalization, audit history and closure gates. |
| Maintenance, concerns, conduct, appeals | Policy/UI/backend regressions for evidence, permissions, transitions and notification creation. |
| Visitors, curfew, gate and presence | Policy/UI/native checks and isolated notification/cron tests. Real movement/background delivery requires devices. |
| Cleaning, inspections, messaging, notifications | Existing suite plus retry, authorization, idempotency and record-routing checks. Report push deployment remains missing. |
| Financial exports | Empty and populated financial/executive PDFs render successfully; shared financial calculations have regression coverage. |
| Public website | Real Chrome rendering, mobile navigation, room page, staff sign-in and input validation; no uncaught page errors in these smoke flows. |

## Remaining gaps

- **Report pushes are not deployed:** `process-report-pushes` exists and its tests
  pass, but it is absent from the linked project's deployed functions. The
  report-delivery cron exists, and 93 unfinished jobs were observed during the
  audit. In-app notifications and external push delivery are separate. The
  dispatcher was left inactive because deploying it could deliver queued alerts
  to real recipients; this QA request did not authorize sending those messages.
- **PayMongo end-to-end testing:** PayMongo credential names were absent from
  deployed secrets. Local tests cover test/live gating, amounts, identity,
  signatures, replay protection and settlement guards. Real test-provider
  checkout/webhooks require the test credentials and an approved QA account.
- **Mobile release verification:** Android release configuration still signs
  with the debug key. The SDK is missing command-line tools and license status
  is unknown, although Gradle debug builds succeeded. No iOS build or APNs test
  was possible from this Windows machine.
- **Physical-device checks:** background geofencing, reboot, force-stop recovery,
  offline retry, push delivery, camera/OCR, and platform permission behavior were
  not proven on real Android/iPhone devices. An emulator is available, but it
  cannot establish these physical/background guarantees.
- **Authenticated live end-to-end checks:** no dedicated QA users were supplied
  for real sign-in, multi-role approval, signing, payment, move-out or eviction
  flows. Production tenant transitions, payment writes and outgoing notifications
  were not used as tests.
- **Font warnings:** web builds report a dependency's missing Cupertino icon
  font; some PDF text uses characters unsupported by its built-in fonts. Export
  generation passes, but extended-character typography still needs review.
- **Database lint warnings:** two intentionally disabled legacy functions report
  unused parameters: `apply_owner_rent_rate_override` and
  `set_move_out_deposit_received`. No runtime errors were reported by the linter.

## Evidence and reproduction

Local logs, screenshots, browser accessibility snapshots, and aggregate-only
database checks are under ignored `build/full_system_qa*`. No secret values or
tenant rows were included in the audit output. The source fixes are local;
updated web/mobile application builds have not been published.

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter build web --release --no-pub --no-wasm-dry-run --target lib/main_web.dart
node tool/test_system_qa_repairs.mjs
node tool/test_evictions.mjs
supabase db query --linked --file supabase/tests/full_system_qa_readonly.sql --output json
supabase db push --linked --dry-run
```

The Node SQL checks use PGlite installed in the ignored
`build/phase2_sql_tests/node_modules` directory. They do not connect to production.
The read-only database audit uses a transaction explicitly marked read-only and
does not invoke reminders, dispatchers, or business-transition functions.

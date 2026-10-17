# CarmeLink Phase 6 acceptance and stabilization report

Date: 17 October 2026 (Asia/Manila). Overall status: **PARTIALLY VERIFIED**.

This report records the original audit before deployment authorization. The later user-authorized migration and commit follow-up is recorded in [phase6-release-follow-up.md](phase6-release-follow-up.md); all nine migrations listed below were subsequently applied and verified. Remaining provider/device/staging acceptance limits still apply.

The local automated checks, scoped database tests, independent-session contention tests and browser smoke checks support continuing to controlled staging verification. They do not establish production readiness. Nine migrations remain unapplied to the linked project; real provider callbacks, the complete Supabase Auth/Storage workflow, authenticated staging acceptance and physical-device behavior remain unverified.

## Scope, baseline and environment

- Started on `main`, commit `d838530` (`Occupancy, Billing and Payment Schema errors fixes`), with a clean working tree. The dashboard compatibility fix from the preceding task was already committed by the start of this audit.
- Flutter 3.44.8, Dart 3.12.2, Windows 11; Deno 2.9.6 through `npx deno`; PostgreSQL 18.3 installed locally. Existing ignored PGlite, `pg`, Playwright and Python PDF-reader dependencies were reused.
- `flutter pub get` succeeded without dependency-file changes. It reported 72 newer packages outside existing constraints; no dependency upgrades were attempted.
- Baseline `flutter analyze`: no issues. Baseline full Flutter tests: **984 passed, 3 failed, 1 skipped**.
- Baseline failures: a payment test required a literal selected column despite wildcard selection; two older source-contract tests pointed to superseded payment-review controls or the previous location of maintenance summary cards. Current payment-review and maintenance widget behavior was independently checked before updating those assertions.
- Docker was installed but its engine was unavailable. An isolated PostgreSQL cluster was initialized under ignored `build/phase6_validation/postgres`, bound to `127.0.0.1:55468`, with generated local-only credentials and fresh dedicated databases. No existing database was reset or reused for destructive tests. The test cluster was stopped after validation and its generated connection files were removed.
- No Android device was attached. iOS compilation, simulator and TestFlight checks are unavailable on this Windows host. Firebase configuration files exist for both mobile platforms; their deployed account configuration was not verified.
- Production activity was limited to **read-only migration-history inspection**. No production records, migration history, secrets or schema were changed. Nothing was committed, pushed, merged or deployed.

## Architecture and module dependencies reviewed

`lib/main.dart` starts the mobile app; `lib/main_web.dart` starts the separate public website and staff portal. Controllers hold session/role state and refresh module services; services use the shared Supabase client, guarded RPCs, RLS-protected views and private evidence storage. The browser staff gate permits Owner/Caretaker accounts; it is an interface guard, with backend authorization enforced separately.

Room inventory and active assignments feed occupancy projections and contract preparation. Immutable contract terms and verified documents gate activation and generated billing. Billing summaries combine issued charges, adjustments, deposits and verified transactions; gateway settlement uses server-calculated allocations. Receipts depend on verified transactions, not the latest displayed bill status. Configuration snapshots preserve historical reporting labels. Conduct investigations, evidence, official/internal responses and agreement acceptance use separate protected history. Notifications are downstream of module writes and queues; curfew/geofencing observations do not automatically establish confirmed disciplinary outcomes.

Inspected project entry points, controllers/services/models/views, current test inventory, Supabase config/migrations, PayMongo handlers/shared code, private-media handlers, Android manifest/Gradle/native tests, iOS plist/AppDelegate/entitlements, Codemagic, web routes and Vercel build configuration. A TODO/FIXME/unimplemented scan did not establish missing Phase 1–5 implementations; comments and earlier completion reports were not treated as evidence of completion.

## Fixed defects

### F6-01 — High: attachment loss after an uncertain database write

**Affected modules:** generated/signed contracts, tenant payment proofs, staff-collected payments, maintenance submission/photo replacement.

**Root cause:** several services deleted uploaded evidence on any registration failure. A committed database write followed by a truncated response or HTTP 503 was treated as a rejected write. Maintenance submission could additionally delete the report itself. Staff-payment cleanup also treated every `PostgrestException` as proof of rejection, although the SDK can wrap proxy and malformed-response failures in that type.

**Fix:** `lib/core/utils/database_write_outcome.dart` recognizes explicit SQL rejection codes, excluding connection errors and `statement_completion_unknown`. The three affected service files clean up only after confirmed rejection. Ambiguous outcomes retain evidence and propagate the error so the user can refresh. A maintenance photo update with an unknown outcome retains the report. Contract cleanup failures preserve the original registration error.

**Files:** `lib/services/contract_document_service.dart`, `lib/services/payment_service.dart`, `lib/services/maintenance_service.dart`, the new utility, `test/core/database_write_outcome_test.dart` and `test/services/upload_commit_recovery_test.dart`.

**Validation:** 19 focused Flutter tests pass, including six write flows × truncated reply/503/explicit SQL rejection, plus SQLSTATE/transport classification. The local HTTP fixture persists references before damaging the reply, then verifies retained files and reloadable documents. Confirmed rejection still cleans up. This tests the actual client services with simulated transport/database responses; it is not a claim of real Cloudinary/Storage failure injection. Existing conduct evidence already retained files on ambiguous registration failures and was preserved.

**Recovery tradeoff:** unknown outcomes can leave detached uploads. Refresh/reconcile before resubmitting; no automatic orphan deletion, financial retry policy or retention job was introduced.

### F6-02 — High: uploader could delete an attached private image

**Affected module:** Cloudinary cleanup endpoint.

**Root cause:** folder ownership authorized deletion without checking whether a payment transaction or maintenance report still referenced the file. The original uploader could therefore remove committed evidence, including evidence saved before a lost client reply.

**Fix:** `_shared/cloudinary.ts` adds a reference check using the server client so caller RLS cannot hide an attachment. `cloudinary-media-delete/index.ts` retains authentication and own-folder checks, then refuses deletion when either reference exists or the lookup is unavailable/incomplete. Detached uploads remain eligible for cleanup. No read permissions were expanded.

**Validation:** six new Deno tests cover detached uploads, payment and maintenance references, incomplete results and failure of either lookup. All 42 Edge tests and all 31 TypeScript source/test file checks pass. Real provider deletion was not executed. The change is **source-only until an approved Edge Function deployment**. These checks protect references observed before deletion; cross-service attachment/deletion races are not proven atomic by this fixture.

### F6-03 — Medium: three obsolete regression expectations failed the baseline

Updated `test/services/phase4_payment_service_test.dart` to assert returned transaction status, partial verified cash and balance instead of SQL selection syntax. Updated `test/ui/tester_feedback_october_contract_test.dart` to enforce the current submitted-proof-only, pending-first review screen; future unsubmitted bills belong in Billing. Updated `test/web/julian_phase2_feedback_contract_test.dart` to check maintenance-card presentation at its current delegated page.

The supported workflow was not changed to satisfy old tests. The existing `staff_upcoming_payments_test`, `owner_payment_verification_test` and `staff_maintenance_test` were rerun alongside these checks: **29 focused tests passed**. Existing assertions for amounts, scope, search, status, rejection reasons and navigation remain active.

## Phase-by-phase results

| Phase | Actual validation | Remaining evidence required |
| --- | --- | --- |
| 1 — PayMongo | 22 SQL checks against the existing fixture and another 22 against receipt-integrity schema; Deno checks for signature freshness/raw body, environment separation, authenticated provider re-read, identity/amount/currency, failed/cancelled/expired/out-of-order states, duplicate notifications, interrupted QR attachment and manual-mode guards. Independent PostgreSQL checkout/settlement races produced one session/allocation/receipt. | Disposable staging credentials, real provider checkout/callback delivery, delayed callback after app closure and provider reconciliation. No live credentials or tenant balances were used. Real GCash/bank QR behavior is unverified. |
| 2 — Dynamic reporting | Maintenance/concern/conduct option create/rename/archive/restore; historical snapshots; Other/specify; assigned-room/common-area validation; server timestamps; confidentiality/RLS; staff destinations and notification queues. 13 configuration-safety checks plus the existing reporting/notification suites and Flutter forms passed. | Authenticated cross-platform submission and actual camera/media/notification delivery in staging. |
| 3 — Rooms/contracts | 17 dynamic occupancy checks; 19 contract occupancy checks; 20 renewal checks; room projection, transfer, signature and deposit suites. Exact-cent Exclusive Shared allocation, Solo exclusion and Standard Shared fixed rents survived newcomer tests. Retired-bed identity, capacity decreases, archive/restore and activation guards were exercised. 14 independent room/contract contention checks passed. | Full Supabase Auth + real Storage + signing + activation test remains skipped. Complete migration-chain replay and physical inventory approval remain external. No departure/replacement/rent redistribution rules were added. |
| 4 — Conduct/confidentiality | 16 investigation/evidence/agreement checks; 17 official-response/conduct workflow checks; five independent contention checks. Confirmed/pending/dismissed/overturned totals, internal-note privacy, evidence metadata/history, immutable agreement versions, explicit own-user acceptance and stale-version rejection passed. | Authenticated evidence upload/download and approved legal wording in staging. No placeholder agreement was published or mandatory gate enabled. |
| 5 — Receipts/finance/admin | 12 receipt/charge/retention checks; 11 financial integrity checks; deposit/staff-payment/payment-mode/realtime suites. Partial cash, test-credit exclusion, immutable receipt recovery, original references, non-repricing rents and charge retry deduplication passed. Four independent financial contention checks passed. PDF content inspection and role/navigation tests were run. | External OCR/camera tests, real printer/export/device behavior, actual account/email/admin lifecycle and deployed RLS/Storage acceptance. No tax-compliance claim or automated deletion was introduced. |

## Role authorization and security results

| Role | Locally exercised behavior | Limit |
| --- | --- | --- |
| Owner | Configuration, room/contract preparation, financial adjustments/charges, payment review, investigation decisions, agreement publication and staff reports. | Full authenticated staging workflow not performed. |
| Caretaker | Existing payment review/maintenance duties, assignment completion and restricted administration. Added explicit SQL checks preserving warnings, termination-review recommendations, appeal decisions, resolution and dismissal. | No Owner-only capacity, charge or agreement publication privileges were granted. |
| Tenant | Own bills/proofs/receipts, contract guards, concern/report access, explanations/appeals and own agreement acceptance. Foreign-tenant reads and unauthorized writes are rejected in scoped database tests. | Local role/JWT functions are fixtures, not a complete Supabase Auth integration. |
| Guardian | Linked billing scope where authorized, agreement audience/own acceptance isolation, confidential/internal conduct restrictions and notification recipient rules. | Real linked-account login, leave approvals and device notifications remain manual staging checks. |

Scoped tests execute real module SQL, including authenticated database roles, RLS policies, Storage metadata guards and unauthorized-role/null-session rejection. Some surrounding identity, tables and notification transport are fixtures. PGlite runs serialize requests and do not establish concurrency. Separate real PostgreSQL sessions observed locking/competing writes: **25 contention checks passed** (8 contract, 6 room, 2 gateway, 5 conduct/agreement, 4 finance). Another 26 setup/functional checks ran on those PostgreSQL fixture databases. An occupancy test deliberately reproduces an older deadlock before applying the existing fix; that diagnostic is not a final-schema failure. These are bounded tested scenarios, not a universal no-deadlock guarantee.

Existing signed terms, paid invoices, deposit separation, receipt history, role permissions and configuration-only retention were preserved in fixture upgrade tests. No production-data comparison was performed. The new media guard is additional evidence protection, not proof of deployed Cloudinary authorization or distributed transaction atomicity.

## Automated results and commands

Raw logs, generated PDFs, screenshots and browser semantics are under ignored `build/phase6_validation/`, with PDFs also in their existing ignored fixture folders. Sanitized results are in `docs/testing/phase6-automated-results.json`.

| Check | Result |
| --- | --- |
| `flutter --version`, `dart --version`, `git status`, `flutter pub get` | Completed; baseline recorded above. |
| Baseline `flutter analyze` / `flutter test --reporter expanded` | No analysis issues; 984 passed, 3 failed, 1 skipped. |
| Focused upload recovery + outcome tests | 19 passed. |
| Focused affected payment/review/maintenance tests | 29 passed. |
| Final `flutter analyze` | No issues. |
| Final `flutter test --reporter expanded` | **1,006 passed, 0 failed, 1 skipped.** All three baseline failures resolved; 19 new tests added. |
| `node tool/test_*.mjs` excluding independent-session runners | 19 scripts passed; 278 printed PASS checks after the new role checks, plus two suites with summary-only output. These counts are test groups, not individual SQL assertions. |
| `node tool/test_paymongo_phase1.mjs --financial-integrity` | 22 additional checks passed against receipt-integrity schema. |
| Five existing `tool/*local*test.mjs` scripts with the local PGlite module path | Staff payments, Jorge feedback, payment mode, nightly Manila curfew and deposits passed. |
| Five `tool/*concurrency.mjs` scripts with `--disposable --local-config <private-loopback-config>` | 25 independent-session checks passed. Conduct/financial fixture scripts also passed on real PostgreSQL. |
| `npx deno test --allow-env --allow-read` with the six test files | 42 passed, 0 failed. No provider calls made. |
| `npx deno check` with all Edge TypeScript files | All 31 checked successfully. |
| `flutter build web --release --no-wasm-dry-run --target lib/main_web.dart` | Passed. Flutter emitted a Cupertino font-family warning; no fatal build error. |
| Local Playwright/Chrome smoke test | Passed at 1440×1000 and 390×844: public pages, menu, empty sign-in validation, anonymous guard, back/forward and reload. App-backend requests were intercepted to prevent production access. No browser page exceptions. Authenticated staff operations were not exercised. |
| `flutter build apk --release` | Passed; `build/app/outputs/flutter-apk/app-release.apk`, approximately 103.5 MB. Uses existing debug signing configuration, unsuitable for store release. |
| `android/gradlew.bat :app:testReleaseUnitTest` | Passed: six native `LocationReminderPolicyTest` tests, zero failures/errors/skips. Gradle reported existing deprecated features. |
| `python tool/test_financial_receipt_pdf.py`, `python tool/test_phase4_financial_pdf.py` | Both passed; nine receipt PDFs plus actual financial/executive PDF text checked for references, amounts, balances, test labels, chronology across years and missing dates. |
| `dart format` on modified Dart files; `git diff --check` | Completed. |

The skipped Flutter test is `test/services/contract_occupancy_staging_test.dart`: the explicitly disposable local Supabase Auth/Storage manifest and credentials are not configured. Standalone PostgreSQL fixtures do not replace it. Android doctor also reports missing SDK command-line tools and unknown license status even though the existing Gradle toolchain completed the APK build. iOS build/device tests were not run.

## Migrations and release blockers

Read-only `supabase migration list --linked` confirmed the remote history ends at `202610140001`. All nine below are locally present and missing remotely:

1. `202610160001_configurable_business_categories.sql`
2. `202610160002_paymongo_test_isolation_and_receipts.sql`
3. `202610160003_reporting_configuration_safety.sql`
4. `202610160004_dynamic_physical_room_capacity.sql`
5. `202610160005_standard_shared_contract_occupancy.sql`
6. `202610160006_conduct_investigation_evidence.sql`
7. `202610160007_confidentiality_agreements.sql`
8. `202610160008_payment_receipt_integrity.sql`
9. `202610160009_additional_charge_retries.sql`

Names/versions are unique and follow the existing history. Configuration safety depends on 001; room sharing depends on capacity 004; receipt integrity 008 depends on the receipt infrastructure in 002; charge retries follow the existing additional-charge API. Individual module fixtures applied relevant real migrations successfully. **The entire migration chain has not been replayed in a disposable Supabase stack**, so cross-module deployment ordering is reviewed, not fully integration-proven. No new migration was needed for these Phase 6 code fixes.

The preceding dashboard fix tolerates missing optional fields for reads. It does not make new capacity/sharing/agreement/evidence/receipt/charge RPCs available on an older database. Until the required migrations are tested and deployed through an approved release, these newer operations remain a deployment blocker.

Other release blockers and limits:

- Real PayMongo sandbox callbacks/reconciliation have not been verified against a disposable staging project. Production secrets and settings were not read or certified. Manual screenshot/OCR review remains intact.
- `cloudinary-media-delete` must be deployed with the revised shared module through a separate approved action. Provider-side cleanup/registration race behavior needs staging verification.
- Android release still signs with debug keys. Distribution signing and store packaging must be configured separately; this audit did not invent credentials.
- iOS requires macOS/Xcode, provisioning/certificate validation, production APNs entitlement verification and TestFlight/device checks. The repository entitlement currently specifies development APNs; inspect the final signed distribution entitlement rather than assuming it is production-ready.
- Actual Auth, Storage, Cloudinary, email, FCM/APNs, OCR and linked-account acceptance remain untested externally. Anonymous browser smoke and widget tests are not a substitute.
- PDF tests emit warnings about unsupported Unicode bullet glyphs in report labels/default Helvetica. Amount/reference/order text checks can pass while typography still needs visual inspection. Non-Latin names and physical print/export remain manual checks.
- Backup availability, point-in-time restore coverage and Storage/media recovery were not verified. A client rollback does not roll back an additive database upgrade.

## Required staging sequence and recovery plan

1. Provision an isolated Supabase staging project/local stack with synthetic Owner, Caretaker, two unrelated Tenants and linked/unlinked Guardians. Pin client URL/key together to that project. Inventory and verify backups before any approved production change.
2. Replay the full current migration history from a clean staging database, then upgrade a staging copy containing representative historical contracts, receipts and reports. Apply the nine pending files in repository order. Compare row counts, contract terms, paid amounts, deposits and immutable snapshots before/after; verify schema-cache reload and permissions.
3. Deploy matching Edge Functions, including the media cleanup fix, to staging only through a separately authorized operation. Set project-specific server credentials securely: Supabase service role/anon configuration, Cloudinary server credentials, notification/cron credentials and relevant FCM/APNs configuration. Never place server keys in Flutter defines.
4. Configure PayMongo **test** keys, webhook secret, pinned test Supabase URL and staging deployment environment. Database test credits must be explicitly enabled only for registered synthetic sample bills. Verify callbacks/retries/reconciliation before considering any separately approved live activation. Production must not inherit staging sample-bill or test-credit settings.
5. Build staging clients against the staging project. Run the skipped Supabase contract workflow and the separate manual checklist. Capture four-role positive/negative authorization evidence, real uploads and provider callbacks, background/relaunch behavior, printer/PDF checks and device results.
6. Resolve the remaining blockers and obtain release approval. Deploy database dependencies, matching server functions/configuration and then compatible clients. Do not change roommate departure policy, legal acceptance, tax receipt status or retention enforcement as part of deployment.

Before an approved production upgrade, record the current schema/migration inventory and take a verified database backup through the established project process; verify a restore into an isolated environment. Include private Storage objects and Cloudinary recovery/inventory separately—database references alone do not restore files. Retain the prior signed app/web artifact and Edge source for rollback. Prefer a reviewed forward migration for schema defects. Do not remove retirement/history columns, new occupancy snapshots, receipt context, decisions or acceptances once they contain records. Restoring a whole database can discard later payments and contracts and requires reconciliation; it is not a routine automated rollback. Preserve deployment logs and compare balances/history after any recovery.

## Pending client decisions

Roommate departure/replacement, group amendments, redistribution and penalties remain blocked pending approved rules. Final tenant/guardian confidentiality wording and any mandatory legal gate remain pending approval. Official tax receipt issuance requirements, automated retention/deletion rules and actual physical bed expansion approval were not inferred or activated.

## Suggested commits (not executed)

1. `Preserve committed contract and payment evidence after lost write responses` — shared outcome utility, three client services and recovery regression tests.
2. `Protect referenced payment and maintenance media from cleanup deletion` — Edge cleanup guard and Deno tests.
3. `Align acceptance checks with current review pages and preserve staff conduct permissions` — updated behavioral/source checks and two explicit staff-role SQL checks.
4. `Document Phase 6 acceptance evidence and staging release blockers` — this report, sanitized test results and the manual checklist.

No commit, push, merge, production data change or deployment was performed.

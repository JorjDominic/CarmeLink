# Phase 4 payment verification and financial integration

Implemented and locally validated on `main`, 2026-10-13. The working tree was clean at the start; Phase 2/3 commits were preserved. Validation was completed before committing. The user subsequently authorized six separate Phase 4 commits and a push to `main`. No production/shared Supabase writes, external migration deployment, database reset, or migration-history repair was performed. Phase 5 was not started.

## Status of the six fixes

| Fix | Status | Result and limit |
| --- | --- | --- |
| 1. Payment Verification interface | COMPLETED AND TESTED | Pending proofs are the default; Bills workspace, charge creation, balance controls and bill management removed from Payments. Existing Billing actions remain accessible. Proof/rejection/printing/search/notification paths tested. |
| 2. Contract rental billing | ALREADY IMPLEMENTED AND VERIFIED | Existing generator uses stored individual contract rent, not current roommate counts. Solo/2/3/4 charges, cycles, duplicate prevention and departure preservation verified on isolated real PostgreSQL. Amendment/prepaid reconciliation scenarios remain blocked separately below. |
| 3. Other category specification | COMPLETED AND TESTED | Conditional required field persists in existing charge metadata and appears in Billing, payment details and the financial PDF. Owner-only backend validation and service payload tested. |
| 4. Reason label | COMPLETED AND TESTED | Phase 1 form was already correct. The separate Billing form still had the old label; its visible label is now `Reason (Required)`, with the existing reason property/API/storage and required validation retained. |
| 5. Financial PDF ordering | COMPLETED AND TESTED | Actual date values sorted ascending across years, missing dates displayed last as `Not specified`; actual PDF text and unchanged figures inspected. |
| 6. Verification/financial consistency | IMPLEMENTED BUT NOT VERIFIED | Local protocol/UI/SQL tests and an independent-session approval race passed. Full Supabase Auth/private storage/realtime, native OCR and live gateway/sandbox end-to-end verification remain external tasks. |

Approved group amendments and application of prepaid value to replacement contracts are **BLOCKED BY DEPENDENCY**. No placeholder amendment/reconciliation process was added or claimed tested. Phase 4 is not production-ready until the migration and external checks below are verified, and launch scope for those blocked operations is agreed.

## Audit and root causes

- `lib/views/owner/owner_pages.dart`: Payments defaulted to Bills and duplicated Billing actions, metrics and an additional-charge form. The existing proof thumbnail/fullscreen viewer, reference display/copy, rejection sheet, verification service and printing path were reusable.
- `lib/views/owner/billing_management_page.dart`: an established Billing workspace already provides utility creation, Owner additional charges/actions, balances, deposit records, received payments, PayMongo sessions, payment-mode settings, filters and pagination. Those essential functions were retained here; the manual due-alert action was moved here from Payments.
- `lib/services/payment_service.dart` and `lib/controllers/owner_controller.dart`: read `billing_charge_summaries` and use existing submission/review RPCs. The selected latest transaction ID was not represented in the model or passed back on review. A stale bill-only review could therefore approve a newer pending proof than the one shown.
- The current summary prioritized partial cash over the latest rejected transaction. A bill could be `partially_paid` while its newest proof was rejected; filtering only by bill status hid the rejected proof. Financial status and proof status need separate presentation, while financial formulas remain unchanged.
- `lib/services/dormitory_report_service.dart`: the financial statement exported the controller's ledger order, normally fetched by descending due date. Its itemized financial table is the affected due-date collection. Executive reports contain totals, and receipt prints contain a single received date; no unrelated report generator needed sorting changes.
- `supabase/migrations/202610040002_separate_security_deposit_receipts.sql`: the existing rent generator uses `tenant_contracts.monthly_rent`, due dates equal the original monthly period start, and the existing contract/category/period unique index prevents duplicate generation. Phase 2 already supplies the approved centavo-allocated per-tenant rent.
- `202609260001_audited_billing_actions.sql`: additional-charge approval evidence already uses immutable `terms_snapshot`; a new category table/column is unnecessary. Its Owner guard and the review RPC's staff guard needed explicit missing-session/role handling.
- Existing OCR parsing and PayMongo implementation were inspected and retained. OCR assists input extraction; it does not approve a payment.

## Resulting behavior

Payments now displays submitted records with Pending, Verified, Rejected and All filters. Unsubmitted invoices and deposit ledgers remain in Billing. Both an approved partial proof and a rejected proof following earlier partial payment stay reviewable, even when the bill itself remains partially paid. The summary still exposes only the latest non-reversed transaction per bill; full historical transactions remain in the database and existing receipt/audit workflows, rather than being deleted or presented as a new history system.

Cards show tenant, current registered room where available, submitted amount, full bill amount/remaining balance, method, reference, submission date, proof status, receipt evidence and review notes. Receipt printing continues to retrieve confirmed evidence. Current room labels come from the existing staff tenant directory; they are not a replacement for historical contractual room evidence.

The existing proof viewer and rejection choices remain. Only one review is processed at a time in the page. New client reviews send the exact latest transaction ID; the backend locks the charge and pending transaction, checks that ID, rejects a changed/already-reviewed proof, and retains the existing balance/overpayment checks. Missing role/session and null approval decisions cannot slip through. Partial-payment messages/notifications use the submitted amount rather than describing the entire bill as paid. Existing payment notifications remain: reviewed-proof targets bypass the default Pending filter, and notifications about bills without a submission provide a link to existing Billing actions.

Billing is still the place to create charges, adjust permitted non-rent/non-deposit charges, manage balances/deposits and record received payments. Owner-only additional-charge creation remains; caretaker financial permissions were not expanded. No PayMongo fees, configuration, webhook logic, transaction statuses, OCR engine, or unrelated notification functionality was changed.

`Specify Category` appears only for Other, is required (2–120 trimmed characters), and clears on switching to a fixed category. The enum remains `other`; the specific label is saved in `terms_snapshot.specific_category`. Fixed categories are unchanged. Title, amount, due date, notes, reason and approval evidence remain. The canonical Billing form now uses the already requested `Reason (Required)` label. Backend currency validation rejects non-finite/nonpositive values and more than two decimal places; historical values are untouched.

The financial PDF sorts a copy of the authorized ledger by actual `DateTime`, earliest first. Equal dates have deterministic tenant/ID ordering; invalid/missing dates remain last and are not displayed as fabricated dates. Existing model financial date fallback behavior is retained for compatibility, with a separate `hasDueDate` flag for reporting/serialization. Layout, formatting, calculations and source list remain unchanged. Specified Other labels appear in the category column. Existing current-ledger report selection is preserved; no new date-range system was introduced.

## Phase 2 financial boundaries

Rent remains contract-derived: PHP 6,000 total gives stored monthly obligations of PHP 6,000 / 3,000 / 2,000 / 1,500 for 1/2/3/4 occupants. Room Management and Payments never redistribute rent after a departure. Generated paid, partial, overdue and future charges are not recalculated, cancelled or replaced by this change. Existing deposit application and audited charge adjustments are preserved.

The Owner's amendment rules remain requirements: retain paid charges; cancel/replace unpaid future charges only as part of a valid signed amendment; preserve original records; apply prepaid value through a **separately approved credit reconciliation process**. Phase 2 still lacks coordinated contract versions, signer evidence, original deposit references and that reconciliation activation transaction. Therefore approved group amendment activation and prepaid carryforward tests were not executed. Existing individually signed renewal/transfer behavior is not a substitute. The previously disabled direct rent override RPCs remain disabled.

## Files changed

Application:

- `lib/views/owner/owner_pages.dart`: simplified verification workspace; preserve proof viewer/rejection/printing, directory room labels, scoped notifications and blocked-review feedback; remove the obsolete duplicate additional-charge form.
- `lib/views/owner/billing_management_page.dart`: canonical public additional-charge dialog, conditional specification, corrected duplicate reason label, finite-amount validation, category display and moved manual due alerts.
- `lib/models/models.dart`: optional category/proof metadata and missing-due-date flag; existing financial/status getters retained.
- `lib/services/payment_service.dart`: read new summary fields, send category specification/expected proof ID, correct partial-payment notification amount.
- `lib/controllers/owner_controller.dart`: pass those existing-workflow metadata values through.
- `lib/core/utils/financial_snapshot.dart`: report ordering helper only; existing calculations unchanged.
- `lib/services/dormitory_report_service.dart`: chronological financial rows, explicit missing dates and category labels.

Database and tests:

- `supabase/migrations/202610130004_payment_verification_charge_categories.sql` (new).
- `test/core/phase4_financial_report_test.dart` (new): chronology, missing dates, partial-proof financial separation and real PDF artifacts.
- `test/services/phase4_payment_service_test.dart` (new): isolated local HTTP/auth protocol fixture; specification/review payloads, parsed partial amounts and server failure propagation.
- `test/views/phase4_additional_charge_test.dart` (new): required/conditional fields, stale specification clearing, finite currency and responsive form checks.
- `test/views/owner_payment_verification_test.dart`: update old Bills-centric expectations to verification defaults, proof history, failure handling, search and notification targets.
- `test/views/staff_upcoming_payments_test.dart`, `test/views/payments_overflow_test.dart`: reflect Billing relocation while retaining responsive proof/utility form coverage.
- `test/ui/owner_caretaker_phase1_test.dart`: reason assertion follows the canonical Billing form after duplicate removal.
- `tool/test_phase4_financial_integrity.mjs` (new): embedded/real PostgreSQL financial regression runner.
- `tool/test_phase4_financial_pdf.py` (new): inspect actual exported fixture PDF text, order, categories and figures.
- This report.

## Database adjustment and rollout

Migration **004** adds two read-only summary columns at the end: `specific_category` from existing JSON metadata, and `latest_transaction_status`. The original summary's amount, cash, balance, due-date and status formulas are copied unchanged; security-invoker behavior and existing grants/RLS remain. No historical record update, financial recalculation, table, column on a base table, category enum change, or weakened constraint is introduced.

An eight-parameter additional-charge overload accepts the specific category. The existing seven-parameter API remains for fixed categories; legacy Other requests are rejected until a specification is supplied. This is intentional required-field enforcement, not a backfill or inferred category. Coordinate migration/app rollout for older clients. The legacy three-parameter review API remains compatible and atomic; the new four-parameter overload binds updated clients to the proof they actually reviewed. Older bill-only callers retain their previous behavior and do not gain this stale-proof protection; require updated staff clients for that guarantee. PUBLIC/anon cannot execute privileged RPCs.

Apply all historical prerequisites and Phase 2/3 **001 → 002 → 003 → 004**, then the matching application. The new application selects the new view columns and sends the new RPC argument sets, so it must not be released ahead of migration 004. Schema-cache reload notification is included. No external deployment was performed.

For a separately configured disposable local Supabase workdir, follow the existing outbound cron/HTTP safeguards in the [Phase 2 report](contract-room-occupancy-phase2-stabilization.md), then review history/dry-run before applying:

```powershell
supabase migration list --local --workdir <disposable-local-workdir>
supabase db push --local --dry-run --workdir <disposable-local-workdir>
supabase db push --local --workdir <disposable-local-workdir>
supabase migration list --local --workdir <disposable-local-workdir>
```

Full historical migration-chain verification is still pending. The test runner loads selected actual repository schemas/functions/policies plus minimal fixtures; applying this migration there is not evidence that a shared deployment matches every prerequisite. Do not reset, repair migration history, use a linked production target, or automatically release the app. Review deployed state and authorize any external target separately.

Read-only postflight:

```sql
select column_name from information_schema.columns
where table_schema='public' and table_name='billing_charge_summaries'
  and column_name in ('specific_category','latest_transaction_status');
select to_regprocedure('public.create_additional_charge(uuid,text,text,numeric,date,text,text,text)'),
       to_regprocedure('public.review_payment_transaction(uuid,boolean,text,uuid)');
select has_function_privilege('anon','public.review_payment_transaction(uuid,boolean,text,uuid)','EXECUTE');
-- Must be false.
select pg_get_viewdef('public.billing_charge_summaries'::regclass,true);
```

Verify roles with disposable signed-in sessions, not just administrative SQL. Prefer a forward corrective migration if a rollout issue occurs. Removing appended summary columns requires dependency review; do not drop the view indiscriminately or delete financial records for rollback. No automatic rollback/history repair was added.

## Actual validation results

- **196 Flutter tests passed across 32 selected files.** Includes new Phase 4 coverage, Payment/Billing/Analytics balance consistency, partial cash and deposit preservation, OCR parsing, gateway/payment-mode UI, received-payment and deposit-settlement services/forms, Phase 1 labels/responsiveness and Phase 2/3 contract/room regressions.
- `flutter analyze`: no issues found. Modified Dart files formatted; `git diff --check` passed.
- **10 embedded PostgreSQL checks passed; 11 checks passed on real PostgreSQL 17.6 with three independent sessions.** Covers representative pre-migration unpaid/partial/paid history and unchanged summary figures, all four occupancy counts, unchanged cycles/duplicate generation, departure preservation, category/reason/amount metadata validation, forbidden roles, separate partial/rejected proof status, stale/null/repeated review rejection, overpayment/pending duplication, immutable financial facts, unrelated-charge preservation and tenant summary RLS. The real run additionally raced Owner and caretaker approvals; exactly one allocation succeeded, with unchanged expected balance.
- Actual generated financial PDF text was extracted and checked: October 2026 → November 2026 → October 2027 → undated. Specific Other category included; PHP 500 collected, PHP 2,600 outstanding, and PHP 2,500 partial remaining balance retained. Executive PDF figures agreed. No claim based only on a PDF header or formatted-string comparison.
- Existing SQL suites passed: staff received-payment guards/idempotency; PayMongo callback/request/mode/sandbox/conflict/reconciliation checks; 17 deposit-to-charge settlement checks; payment realtime publication/idempotency/RLS checks. These are local fixtures, not live gateway calls.
- No full Supabase Auth/private Storage/realtime integration, native Android/iOS OCR, physical-device/browser manual checks, gateway end-to-end session, approved group amendment or prepaid carryforward execution occurred. Those are pending/blocked, not successful tests.

Real database testing used a fresh empty `phase2_validation_phase4` database in the existing isolated internal Docker network. No shared/live connection, destructive reset or real tenant records were used. The runner rejects unapproved hosts/names and nonempty databases. Role contexts are simulated fixture identities, not actual Supabase JWT sessions. Credentials and evidence are ignored under `build/`; no secrets were printed. The dedicated container was stopped after testing, retaining datasets.

Reproduce embedded checks: `node tool/test_phase4_financial_integrity.mjs`. Real-engine checks add `--real-postgres --disposable --local-config <ignored-local-connection.json>` and require a fresh empty approved local database; the internal Docker setup additionally uses `--docker-network` inside its existing test network. Do not reuse/reset the retained populated fixture.

Generate PDF fixtures with `flutter test test/core/phase4_financial_report_test.dart`, then inspect with `python tool/test_phase4_financial_pdf.py`. The local parser dependency was installed only under ignored `build/phase4_pdf_tools` using `python -m pip install --target build/phase4_pdf_tools pypdf`; application dependencies were unchanged. Logs/artifacts: `build/phase4-flutter-final.log`, `build/phase4-analyze-final.log`, `build/phase4-sql.log`, `build/phase4-real-postgres.log`, `build/phase4_reports/financial.pdf`, and `build/phase4_reports/executive.pdf`.

## Remaining checks and commit wording

Before production, use disposable full-stack staging to verify migration compatibility, private proof URL authorization, real Owner/caretaker/tenant/guardian permissions, pending/rejected/verified partial flows, two-reviewer stale proof behavior, realtime totals across Billing/Payments/Analytics, existing notifications and receipts, and sandbox gateway creation/callback reconciliation. Test OCR on supported physical Android/iOS devices and keep extracted values subject to actual administrative verification. Check narrow/desktop browser layouts, long labels, keyboard/rejection forms, and visual PDF readability. Earlier phases' staging/device dependencies remain.

User-approved separate commit wording:

1. Payment Verification interface simplified
2. Additional Charge category specification implemented
3. Billing Additional Charge required reason label corrected
4. Financial PDF due-date sorting corrected
5. Payment proof review and partial-payment consistency fixes implemented
6. Phase 4 financial regression tests and deployment notes added

Shared model/service/migration hunks must remain with their matching feature dependencies. Do not create a commit implying a new rent engine: the existing contract billing path was verified, not rebuilt.

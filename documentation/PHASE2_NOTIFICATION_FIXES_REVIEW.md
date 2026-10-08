# Phase 2 notification fixes — review handoff

Transfer note (2026-10-09): this report records the original implementation audit. The notification-only changes were subsequently transferred to the existing `CarmeLink_Automation` worktree for local commits on `japelbranch`, under explicit user approval. The original worktree remains untouched. The coverage matrix contains updated test counts; the final Git handoff lists committed files and intentionally excluded work. No migration was deployed.

Work performed in `C:\Users\ligay\OneDrive\Documents\Capstone\CarmeLink`, on the existing `main` branch. Existing uncommitted changes were inspected and preserved. `Automation.txt` was not present in the workspace; scope follows the three tester requirements quoted in the task.

## Findings and implementation

- Shared routing recognized canonical types but not legacy curfew-pass/request, maintenance-report, or room-inspection aliases. FCM record identifiers nested in a map or JSON-string `data` payload were not decoded. The shared notification model now normalizes those aliases and reads nested routing data.
- Secondary notification types already emitted by repository migrations lacked destinations: employee curfew, cleaning schedule, room assignment, guardian link, move-out, and tenant/guardian onboarding. Added destinations using existing authorized pages. Where a page has no record-selection interface, it opens the existing module rather than inventing a details screen.
- Staff inspection notifications opened the general Rooms page and did not select the referenced inspection. They now load the exact inspection and room number through the current user's RLS-protected session. Missing, inaccessible, and failed loads show a readable fallback.
- Tenant curfew notifications already retained a request ID, but the selected request appeared below presence/geofence content. They now show the existing request card immediately, including scheduled departure and expected return, for both Late Return and Overnight Leave. Guardian taps retain the Requests segment and show an explicit unavailable state for missing/inaccessible requests. Existing staff target lookup and approval rules are unchanged.
- Web workspace labels used raw notification types separately from the shared destination resolver. They now use normalized types. Existing workspace navigation remains in place; behavioral tests confirm web taps do not push the public/root navigator, while mobile taps push the role navigator.

## Saved-report workflow inventory

| Existing workflow | Notification producer / change |
| --- | --- |
| Tenant maintenance submission | Existing AppNotificationService; retained |
| Tenant maintenance saved edits / cancellation | Review migration: staff recipients, excluding actor |
| Staff maintenance status save | Existing post-RPC AppNotificationService; retained as the single producer |
| Staff maintenance notes-only save | Review migration: affected tenant |
| Confidential report submission / status review | Existing trigger replaced with existing emit helpers; adds notes-only review coverage |
| Confidential correction/addendum | Review migration: staff and report owner, excluding actor; existing request-key uniqueness prevents retry duplicates |
| Cleaning-duty report submission / status / notes | Existing transactional cleaning trigger; retained, no extra producer |
| Conduct draft, response, review, resolution, termination recommendation, evidence | Review migration: existing append-only case events; private drafts/evidence notify staff only; published review changes also notify tenant |
| Conduct publish / warning | Existing AppNotificationService; excluded from new event trigger |
| Conduct appeal submit / decision | Existing AppNotificationService; retained |
| Conduct appeal review / withdrawal | Review migration: authorized staff and tenant, excluding actor |
| Inspection schedule / completion | Existing scheduling trigger and completion AppNotificationService; retained |
| Inspection start / cancellation / findings / evidence | Review migration: staff; published visible changes also reach distinct active room tenants; evidence remains staff-only |
| Analytics, disciplinary register, financial snapshot, PDF exports | Read/export views; no saved report mutation to notify. No billing/payment implementation changed |

The review migration uses the existing `emit_app_notification`, `emit_staff_notification`, `app_notifications`, and server report push queue. It sends generic bodies without confidential text or staff evidence. Trigger writes are part of the report transaction: failed writes and rollbacks do not leave success notifications. No-op updates are ignored, immutable event/addendum IDs deduplicate retries, and workflows with existing client producers are excluded to avoid duplicates.

## Files changed by this task

Modified:

- `lib/core/widgets/adaptive_shell.dart`
- `lib/services/app_notification_service.dart`
- `lib/views/shared/notification_destination.dart`
- `lib/views/tenant/tenant_pages.dart`
- `lib/views/guardian/guardian_pages.dart` (preserves pre-existing announcement edits)
- `test/ui/notification_destination_test.dart`

Added:

- `test/ui/phase2_notification_behavior_test.dart`
- `supabase/migrations/202610090001_phase2_saved_report_notifications.sql`
- `tool/test_phase2_report_notifications.mjs`
- `documentation/PHASE2_NOTIFICATION_FIXES_REVIEW.md`

`dart format` was run only on modified Dart files. It also normalized a few pre-existing lines in the overlapping guardian file without changing their behavior.

## Automated validation

`flutter analyze` — **No issues found**.

```powershell
flutter test test/ui/phase2_notification_behavior_test.dart test/ui/notification_destination_test.dart test/services/notification_delivery_policy_test.dart test/web/staff_notification_deeplink_contract_test.dart test/ui/notification_coverage_completion_contract_test.dart test/ui/phase2_notification_center_contract_test.dart test/ui/phase2b_reports_addenda_contract_test.dart test/ui/phase1_cleaning_notification_contract_test.dart test/ui/curfew_requests_scroll_layout_test.dart test/ui/phase1_curfew_return_contract_test.dart test/ui/phase1_messaging_notifications_dynamic_contract_test.dart
```

Result: **51 tests passed**. Includes actual schedule rendering, unavailable targets, role routing, malformed/legacy payload handling, and behavioral mobile/web navigator checks. An initial widget-test assertion was corrected to include the mobile shell preserved offstage; the final suite passes.

```powershell
npm install --prefix build/phase2_sql_tests --no-audit --no-fund --ignore-scripts @electric-sql/pglite
node tool/test_phase2_report_notifications.mjs
```

Result: **20 PostgreSQL checks passed**. The harness executes the repository's actual helper/trigger SQL in an isolated in-memory PostgreSQL engine with minimal schema fixtures. Covers recipients, actor exclusion, confidential-content isolation, failed persistence, rollback, unchanged saves, retry duplicates, retained single notification producers, room-recipient deduplication, and queue creation. Dependencies are contained in ignored `build/phase2_sql_tests`; no Flutter dependency changes.

`git diff --check` — **passed** (Git prints existing LF/CRLF conversion notices).

## Review-only migration and remaining testing

`202610090001_phase2_saved_report_notifications.sql` requires review and approval before deployment. It depends on the existing notification helper and push-queue migrations. It has **not been applied to any Supabase database**. New report-save notifications therefore will not activate against the live backend until an authorized person applies it.

The isolated SQL tests do not prove deployed RLS, installed migration versions, live FCM credentials, or cron-worker configuration. Validate the migration against a disposable full-schema environment before approval. Device/leader testing should cover:

- Owner, Caretaker, Tenant, and a currently linked Authorized Guardian.
- Inbox taps plus Android/iOS foreground, background, and cold-start push taps; login/account-switch behavior.
- Late Return and Overnight Leave schedule visibility, archived requests, deleted targets, and revoked guardian links.
- Browser taps, back navigation, reload, and authenticated workspace retention.
- Each report save, notes-only changes, unchanged-save retries, failed saves, private evidence, and no self/unauthorized notifications.
- After approved deployment, server push queue processing and actual device delivery.

No commit, push, checkout, branch change, reset, stash, pull, merge, production database operation, or deployment was performed. Phase 1 Curfew Return services/calculations, Visitor QR/integration, PayMongo, billing/payment logic, UI theme, and generated platform files were not changed by this task. Await user and leader testing/approval before Git operations.

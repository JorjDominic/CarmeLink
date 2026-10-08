# Phase 2 notification audit continuation

Local transfer validation (2026-10-09): the same 157 Flutter tests and 37 isolated SQL checks also passed in `CarmeLink_Automation` on `japelbranch`; six focused Phase 1 tests passed independently. `flutter analyze` reported no issues. References below to no commits describe the original implementation audit, before the user authorized local commits. No pushes or migration deployments were authorized or performed.

Existing Phase 2 changes were reviewed rather than reimplemented. See [initial implementation report](PHASE2_NOTIFICATION_FIXES_REVIEW.md) for report workflows and the review-only migration. This continuation supersedes its earlier test counts.

## Confirmed defects improved in this review

- Mark All was hidden when unread notifications existed outside the loaded page. It now uses the server unread count.
- Failed optimistic read saves restored an old list, losing concurrent realtime entries. Rollback now affects only the entries changed by that save.
- Single-read success did not refresh the badge after persistence. Successful writes now refresh the snapshot/count, with stale count responses ignored.
- Concurrent reads of the same notification caused redundant writes. Pending writes are coalesced per account and notification.
- Tenant move-out notifications lacked a destination despite an existing tenant-authorized page. They now open that page.

Additional modified file: `lib/views/shared/shared_views.dart`. Existing modified service and destination files were improved surgically. Added tests: `test/services/notification_creation_coverage_test.dart`, `test/ui/notification_read_state_behavior_test.dart`, and `test/ui/notification_all_roles_coverage_test.dart`. Expanded `tool/test_phase2_report_notifications.mjs`. No other developers' changes were discarded.

## All existing route families and roles

M = existing authorized module; D = readable notification details without access to a protected module. Each row has automated destination/record-scope checks for all four roles. M does not imply every module offers record selection: exact-record behavior follows its existing interface. All rows still need live backend/device verification.

| Route family | Owner | Caretaker | Tenant | Guardian |
| --- | --- | --- | --- | --- |
| announcement | M | M | M | M |
| payment | M | M | M | M |
| maintenance / maintenance_report | M | M | M | D |
| curfew / curfew_pass / curfew_request / late_return / overnight_leave | M | M | M | M |
| visitor | M | M | M | D |
| gate | M | M | M | M |
| safety | M | M | M | M |
| onboarding | M | M | M | M |
| message | M | M | M | M |
| system | D | D | D | D |
| conversation | M | M | M | M |
| gate_event | M | M | M | M |
| confidential_report | M | M | M | D |
| cleaning_report | M | M | M | D |
| conduct_case | M | M | M | D |
| inspection / room_inspection | M | M | M | D |
| location_monitoring_incident | M | M | M | M |
| guardian_presence_alert | M | M | D | M |
| location_status_request | M | M | M | M |
| location_settings | D | D | M | D |
| employee_curfew | M | M | M | D |
| cleaning_schedule | M | M | M | D |
| room_assignment | M | M | M | M |
| guardian_link | M | M | M | M |
| move_out | M | M | M | D |

Database/push base categories audited: announcement, payment, maintenance, curfew, visitor, gate, safety, onboarding, message, system. Route families above are payload destinations, not additional database category values. Unsupported roles keep safe details; no new role permissions were granted.

## Creation, delivery and state coverage

| Area | Automated evidence | Source-reviewed / remaining verification |
| --- | --- | --- |
| Creation and recipients | 16 existing service wrappers exercised; ten base categories tested with actual SQL staff helpers | Live Edge authorization and each production workflow still require integration tests |
| Guardian permissions | SQL tenant-circle recipients and revoked-link exclusion; route isolation for all roles | Full deployed module RLS, guardian preferences and account changes |
| Curfew request schedules | Late Return/Overnight card rendering; aliases, target IDs and unavailable target tests | Live approval rules, guardian decisions, archived/deleted requests |
| Deep links | Nested map/JSON payloads, malformed payloads, record scope and role routes | FCM cold-start/login timing, revoked access and real record loads |
| Read/unread and Mark All | Actual SQL inbox RLS/read RPCs for all four roles; older unread pages; failed-save rollback | Real Supabase realtime/reconnection and cross-device state |
| Badge updates | Post-save callback and server-count behavior; existing badge contracts | Real shell badge timing on all platforms |
| Duplicates | Concurrent read coalescing; SQL event-key dedup, distinct recipients, repeated Mark All | Push worker/device retries and live Edge endpoint retries |
| Saved report changes | Actual review SQL: successful saves, recipients, actor exclusion, no-op/retry, rollback/failure, private evidence, queue | Full-schema staging validation and approved migration deployment |

Existing visitor creation is database-trigger based; no additional client producer was introduced. Existing utility allocation, maintenance-status, conduct publish/warning, appeal decisions, inspection completion and cleaning-report producers were retained; the new report migration avoids overlapping them. Push queue/device delivery deduplication was source-reviewed, not exercised against FCM.

Limits: the message Edge endpoint is not durably idempotent across arbitrary repeated HTTP requests; this audit did not establish a normal-flow duplicate or change that endpoint. Geofence fallback/retry behavior requires integration testing and was not modified under the curfew/geofence safety constraints. Do not interpret these tests as proof that every possible external retry is deduplicated.

## Platform coverage

| Platform | Tested here | Still manual |
| --- | --- | --- |
| Web | Shared routing/widget tests ensure taps remain in authenticated role navigation rather than the root/public navigator | Actual browser reload/back/session expiry, realtime badge, live RLS. Browser FCM push is not initialized by the existing architecture |
| Android | Shared mobile navigator behavior, payload parsing and role destinations | Physical-device foreground/background/terminated FCM and local notification taps, login/account switching |
| iOS | Same shared Dart routing/payload tests | Physical-device APNs/FCM delivery, permission states, foreground/background/terminated taps |

These are host Flutter tests, not Android/iOS device or browser end-to-end runs. Native push launch handlers and queue/cron workers were inspected; no production calls or deployments were made.

## Final verification

`flutter analyze`: **No issues found**.

```powershell
flutter test test/services/notification_creation_coverage_test.dart test/ui/notification_read_state_behavior_test.dart test/ui/notification_all_roles_coverage_test.dart test/ui/phase2_notification_behavior_test.dart test/ui/notification_destination_test.dart test/services/notification_delivery_policy_test.dart test/web/staff_notification_deeplink_contract_test.dart test/ui/notification_coverage_completion_contract_test.dart test/ui/phase2_notification_center_contract_test.dart test/ui/phase2b_reports_addenda_contract_test.dart test/ui/phase1_cleaning_notification_contract_test.dart test/ui/curfew_requests_scroll_layout_test.dart test/ui/phase1_curfew_return_contract_test.dart test/ui/phase1_messaging_notifications_dynamic_contract_test.dart --reporter expanded
```

**157 tests passed.** Includes behavioral tests and existing source-contract regression tests; not every assertion is an end-to-end test.

`node tool/test_phase2_report_notifications.mjs`: **37 PostgreSQL checks passed**, in isolated PGlite with minimal schema fixtures and actual repository SQL. Not a production/full-schema database test.

`dart format` ran only on modified Dart files. `git diff --check` passed.

Review-only migration: `supabase/migrations/202610090001_phase2_saved_report_notifications.sql`. Not deployed; its new saved-report notifications require approval and deployment before they work against the live backend.

No commit, push, branch switch, reset, stash, pull, merge, or production database operation was performed. Existing Visitor preview/integration, geofencing/calculations, billing/PayMongo, UI theme and generated-platform changes were preserved without modifications by this task.

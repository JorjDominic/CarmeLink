# Phase 5: report management and official conduct responses

Phase 5 is implemented locally and passes the targeted automated validation below. The migration is prepared for review and has **not** been deployed. Full Supabase Auth/realtime/push integration and browser/device acceptance remain unverified. No production data was modified during this task. Implementation was initially left uncommitted; the user subsequently authorized local commits. No push, merge, deployment, or Phase 6 work was performed.

## Audit and preserved capabilities

The branch was `main`. Existing contract-related working-tree changes were inspected and left untouched. Phase 5 edits are confined to the paths listed below.

| Existing capability | Actual implementation | Assessment |
| --- | --- | --- |
| Separate report queues | `ReportManagementPage` and `ConfidentialReportsPage` in `lib/views/owner/owner_pages.dart`; maintenance detail in `lib/views/owner/staff_maintenance_page.dart` | ALREADY IMPLEMENTED AND VERIFIED: queues remain separate; existing maintenance search, filters, navigation and attachment access retained. Confidential reports are not merged into general reports. |
| Maintenance status protection and audit | `lib/services/staff_maintenance_service.dart`; `202609100001_staff_maintenance_workflow.sql` | ALREADY IMPLEMENTED AND VERIFIED: backend role checks, row locks, expected-version checks, allowed transitions, resolution reasons, responsible actor and `maintenance_staff_history`. Duplicate shortcut controls and a preview incorrectly replacing the displayed persisted status needed UI changes. |
| Confidential review and audit | `lib/services/confidential_report_service.dart`; `202609190004_owner_confidential_report_review.sql`; `202610060002_staff_report_notification_access.sql`; configured concern migrations | Existing staff review and audited reads were retained. The old review API lacked stale-version/finalization protection, and the UI offered duplicate or inappropriate actions. |
| Tenant explanations, warnings and evidence | `lib/services/conduct_case_service.dart`; `lib/views/shared/conduct_case_pages.dart`; `20260924070000_phase4a_conduct_cases.sql` | ALREADY IMPLEMENTED AND VERIFIED: original explanations, restricted staff evidence, formal warnings and explicit review decisions are preserved. There was no structured staff-response entry with tenant/internal visibility. |
| Appeals and separate lifecycle decisions | `lib/services/conduct_case_appeal_service.dart`; `lib/views/shared/conduct_case_appeal_panel.dart`; `20260924090000_phase4c_conduct_case_appeals.sql` | ALREADY IMPLEMENTED AND VERIFIED: appeal submission and staff decisions still work; warnings and explanations remain intact. Existing owner-only eviction navigation/authority is unchanged. |
| Notifications and deep links | `202610090001_phase2_saved_report_notifications.sql`; notification emitter and push-queue migrations; `lib/views/shared/notification_destination.dart` | ALREADY IMPLEMENTED AND VERIFIED locally: saved tenant explanations notify staff; `conduct_case` plus `case_id` opens the exact staff/tenant case. Existing notification architecture is reused. |

Privacy finding: maintenance `staff_notes` and confidential `response_notes` were already readable by the reporting tenant through existing APIs. Some UI labels incorrectly called them private. Their labels now explicitly say **tenant-visible**. No existing note was copied into a newly exposed response projection. New internal notes use only the existing staff-restricted histories. Confidential addenda retain their existing visibility and are not repurposed as private staff notes.

## Requirement status

These statuses describe executed local automated checks, not production or physical-device verification.

| Requirement | Status | Result and evidence |
| --- | --- | --- |
| Fix 1: simplify report status triage | COMPLETED AND TESTED | One maintenance action selector replaces duplicate chips/dropdown controls. Current status stays persisted until saving succeeds. Valid choices, transition descriptions, confirmation and existing backend transition rules are preserved. |
| Fix 2: report information and administrative actions | COMPLETED AND TESTED | Original category/content/date/tenant/photo remain; available responsible staff is displayed. Confidential actions depend on current state; resolved/dismissed reports offer no review transitions. Tenant-visible updates and private staff notes are distinct. History and guarded review writes preserve originals and configured concern details. |
| Fix 3: structured staff conduct responses | COMPLETED AND TESTED | Existing case detail gains an official-response section with author name, role, date/time, visibility and full instructions. Case reference is displayed. Explanations, warnings, evidence, decisions and appeals retain separate sections. |
| Fix 4: formal response workflow | COMPLETED AND TESTED | Add Official Response opens an entry form defaulting to internal visibility, then a full preview and confirmation. A stable UUID, disabled controls and backend idempotency prevent repeated-click/retry duplicates. Completion appears only after the RPC succeeds. |
| Fix 5: status/decision synchronization | COMPLETED AND TESTED | Staff entries update the case version without changing status or issuing penalties. Additional tenant explanations also invalidate stale staff actions. Row locks serialize with existing warning/decision RPCs. Finalized/draft cases reject new responses. Warnings, appeal decisions and original explanations survive. |
| Fix 6: response visibility and authorization | COMPLETED AND TESTED | Existing staff-only event RLS stays unchanged. The tenant reader returns only explicitly visible official entries from the caller's own published case. Other tenants, guardians, missing roles and null sessions cannot create staff replies or access internal histories. No caretaker disciplinary/lifecycle powers were expanded. |
| Fix 7: notifications and links | COMPLETED AND TESTED | The existing event trigger creates generic staff notices and tenant notices only for visible official replies; internal notes never notify tenants/guardians. Retries create no duplicate notification. Inserts enter the existing push queue. A notification failure rolls back the response. Existing destination tests verify exact case IDs for both staff roles and tenants. |
| Fix 8: history presentation | COMPLETED AND TESTED | Staff responses reuse `conduct_case_events`, and internal report notes reuse `maintenance_staff_history` or `confidential_report_audit`. Protected confidential history is exposed to staff through an authorized RPC. Report and official response histories are ordered oldest first; existing explanations/warnings/appeals remain available. |
| Existing submission, warning and appeal workflows | ALREADY IMPLEMENTED AND VERIFIED | Existing Flutter/SQL regression tests and the new isolated integration checks pass. No new automatic decision or financial workflow was introduced. |
| Full-stack Supabase, browser and physical-device acceptance | IMPLEMENTED BUT NOT VERIFIED | Local fixtures do not validate real JWT issuance, deployed schema compatibility, realtime transport, push providers or on-device rendering. |
| Production enablement | BLOCKED BY DEPENDENCY | Requires separately authorized migration deployment after staging verification. This request explicitly forbids deployment or production mutation. |

No Phase 5 business decision remains unresolved. Requesting additional information uses an official response containing instructions; it does not introduce another case status. Existing warning, appeal, recommendation and owner lifecycle rules remain authoritative.

## Response storage, permissions and notification behavior

`202610140001_phase5_report_and_conduct_responses.sql` adds optional request IDs and staff-response metadata to existing histories. Legacy conduct events default to `visibility='internal'`. A new `official_response` **event type** is added; no report or case status is added. It is an administrative record, not a warning or decision.

`add_conduct_official_response` derives author ID, name and role on the server, validates body/visibility, locks the case, checks its expected version and refuses draft/finalized cases. A matching idempotent retry returns the original event; a changed payload using the same key is rejected. Direct application-role event inserts/updates remain denied. The saved action and its existing notification trigger share one database transaction.

`get_my_conduct_official_responses` returns only ID, response body, author name/role and timestamp for explicit tenant-visible replies on the caller's own published case. It exposes no source identity, other event types, internal instructions, evidence paths or confidential report records. No tenant SELECT policy is added to the event table. Guardian access is not expanded.

`append_report_internal_note` appends to existing report history with a retry key, refuses finalized reports, and never writes tenant-readable `staff_notes` or `response_notes`. It produces no tenant notification. `get_confidential_report_history` retains staff-only authorization and does not grant client access to the underlying audit table.

`review_confidential_report_guarded` adds expected-version protection for the revised app. The legacy `owner_review_confidential_report` is also hardened against duplicate status decisions and reopening finalized reports, so old/direct API calls cannot bypass finalization. The public tenant explanation API retains its signature and established awaiting-response-to-under-review behavior; additional explanations now refresh the case version as well.

Existing table refresh subscriptions update case/report views, with the existing 30-second catch-up mechanism where RLS excludes realtime events. Confidential audit history is refreshed through its protected RPC only while expanded. Maintenance refresh avoids overwriting an unsaved staff draft; a stale save still fails at the backend. Staff-visible audit rows are never republished to tenants to provide realtime delivery.

The response composer allows a retry of an uncertain submission with the same key and immutable payload. Editing is disabled after the first attempted save; cancel and refresh after a stale-version error before composing another action.

## Changed files

Modified:

- `lib/models/models.dart`: preserve confidential report version; recognize finalized reports.
- `lib/services/confidential_report_service.dart`: call guarded review RPC with the original version.
- `lib/services/conduct_case_service.dart`: structured response model, staff/tenant readers, versioned response RPC and UUID generation.
- `lib/services/staff_maintenance_service.dart`: responsible staff metadata; chronological history.
- `lib/views/owner/owner_pages.dart`: confidential actions, confirmation, correct visibility labels, protected history and refresh.
- `lib/views/owner/staff_maintenance_page.dart`: single action selector, persisted status, confirmation, internal notes, responsible staff, safe refresh and responsive headings/map control.
- `lib/views/shared/conduct_case_pages.dart`: official-response panels, case reference, explicit action/explanation sections and detail refresh.

Created:

- `lib/services/report_administration_service.dart`.
- `lib/views/shared/administrative_entry_dialog.dart`.
- `lib/views/shared/conduct_official_responses.dart`.
- `lib/views/shared/confidential_report_history.dart`.
- `lib/views/shared/report_status_actions.dart`.
- `supabase/migrations/202610140001_phase5_report_and_conduct_responses.sql`.
- `tool/test_phase5_report_conduct.mjs`.
- `test/services/phase5_administration_service_test.dart`.
- `test/views/phase5_administrative_response_test.dart`.
- This report.

No historical migration was edited. Cleaning report handling, financial obligations, contract amendments, room management, payment verification and gateway/geofencing/curfew/visitor implementations were not changed. The existing maintenance floor-plan control remains available through a labeled map icon; its map implementation is unchanged.

## Executed validation

- `dart format` on every modified/new Dart file.
- `flutter analyze`: **No issues found**.
- **82 Flutter tests passed** across the selected service, widget, model, policy, notification-destination and existing regression suites below.
- **17 new isolated PostgreSQL checks passed**. The runner applies the actual baseline conduct/appeal/report migrations, actual notification emitters/push queue and new Phase 5 migration to an in-memory PGlite database. It exercises application-role grants and RLS, staff/tenant/other-tenant/guardian/null-role/null-session cases, private histories, idempotency, stale writes, finalization, preserved warnings/appeals, chronological visible responses and notification rollback.
- Existing isolated SQL runners: **37 notification checks**, **21 report/room safety checks**, **5 configured concern checks** passed. These are baseline regressions, not evidence of a full historical deployment. Total SQL checks: **80**.
- `git diff --check`: passed.

The new widget checks cover internal-by-default visibility, explicit tenant selection, preview before persistence, repeated clicks, save failure/retry with the same key, invalid short entries, separate staff/tenant projections, valid next actions and responsive dialogs/details at 320/1280 pixels with 1.35 text scaling. Dialog checks include a 220-pixel keyboard inset. Five maintenance heading/location overflows found by these checks were fixed. These are Flutter widget tests, not browser or device runs.

Reproduce Flutter checks:

```powershell
flutter analyze
flutter test test/services/phase5_administration_service_test.dart test/views/phase5_administrative_response_test.dart test/core/conduct_case_policy_test.dart test/core/conduct_case_appeal_policy_test.dart test/models/staff_maintenance_report_test.dart test/models/confidential_report_test.dart test/views/staff_maintenance_test.dart test/ui/phase3_reports_rooms_test.dart test/ui/phase2b_reports_addenda_contract_test.dart test/ui/notification_destination_test.dart test/ui/final_conduct_case_curfew_contract_test.dart
```

Reproduce SQL checks with the existing local PGlite dependency under ignored `build/phase2_sql_tests`:

```powershell
node tool/test_phase5_report_conduct.mjs
node tool/test_phase2_report_notifications.mjs
node tool/test_phase3_report_room_safety.mjs
node tool/test_configured_concern_safety.mjs
```

The runners use disposable in-memory databases, simulated session IDs and real role grants. They do not connect to Supabase. They do not prove independent-session contention, real Auth/Storage policies over HTTP, a full historical migration chain, actual push delivery or production behavior. No unexecuted test is counted as passing.

## Readiness and remaining acceptance work

**Not yet production-ready.** Apply the reviewed migration to an authorized disposable staging stack before deploying the matching app. It depends on the existing conduct, appeal, maintenance, confidential review, saved-event notification emitter and push-queue migrations. Schema changes cannot be replaced by merely hiding controls in Flutter. Until deployment, new RPCs are unavailable; the response/history UI shows a dependency error and does not expose internal data or use a weaker fallback. Revised confidential review also requires the guarded RPC.

Remaining acceptance work:

1. Validate the full migration chain and representative legacy histories in a disposable staging stack; verify snapshot values, privileges and RLS before/after. No production reset, migration-history repair or data deletion is needed or authorized here.
2. Use real owner, caretaker, tenant, other-tenant and linked-guardian JWTs to verify HTTP/RPC privacy, immutable history, finalization and stale-action rejection. Test independent concurrent staff sessions and tenant submissions.
3. Verify actual push delivery, queue retries and notification taps on supported devices, including internal-note silence and no private text in notification payloads. Automated tests verified database queue insertion and route IDs only.
4. Check Chrome/Edge and physical Android/iOS layouts, keyboard behavior, large text, evidence/attachment access, long case content and history. Existing staff evidence remains restricted; no new tenant evidence-sharing capability was added.
5. Verify cross-client refresh and unsaved-draft protection through real realtime connections. Restricted histories may update through the existing catch-up timer rather than an immediate event.

No user-facing unrestricted chat, AI judgments, automatic penalties/resolution, new guardian disclosure or caretaker authority expansion was introduced. No Phase 6 work was started.

Local commit groups authorized after implementation review:

1. `Add protected Phase 5 response and report history RPCs` — migration and isolated SQL checks.
2. `Add structured official conduct responses` — response model/service, shared administration service, reviewed composer and case panels/refresh.
3. `Simplify report triage and separate private staff notes` — report models/services, shared status controls and report views/history.
4. `Add Phase 5 regression coverage and validation report` — Flutter tests and this report.

Shared widget dependencies accompany their first consumer. The subsequent user request authorizes these local commits only; no push or deployment was performed.

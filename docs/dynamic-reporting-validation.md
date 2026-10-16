# Dynamic reporting configuration validation

Reviewed on 2026-10-16 on `main`. The working tree was clean before this work.
Changes are grouped into local commits at the user's subsequent request. No push, deployment, production write, remote
migration-history change, stash, reset, or room/bed lifecycle change was performed.

## Result

The existing configuration infrastructure was retained. Confirmed reporting
defects were fixed and tested locally. This is **not deployment approval**:
there is no staging project, no full local Supabase server validation, and no
native-device/browser release validation in this run.

## Audit findings and existing implementation

| Existing path | Behavior and dependency |
| --- | --- |
| `lib/services/dormitory_configuration_service.dart` | Uses `dormitory_options`; loads active options, sorts alphabetically with Other last; add/rename/archive/restore retain option ID/code and immutable workflow mappings. No duplicate repository or configuration table was introduced. |
| `lib/views/owner/dormitory_configuration_page.dart` | Owner RoleGuard; add/edit dialogs; active/archived filters, search and pagination; archive/restore confirmation. Existing protected system choices cannot be archived. CRUD reloads the list. UI inspected; owner editor was not driven against a deployed backend. |
| `lib/views/tenant/tenant_pages.dart` | Maintenance categories/common areas and assigned-room locations; confidential report types; descriptions, Other text, attachments, existing submission/status workflows. Forms already used polling/realtime refresh. |
| `lib/core/widgets/configured_choice_field.dart` | Shared active-choice field, loading/error/retry/empty handling and request sequencing; conduct category refresh preserves the selected code. Existing component retained without modification. |
| `lib/views/shared/conduct_case_create_dialog.dart` | Shared Owner/Caretaker form; configured categories, tenant picker, source validation, Other text, editable incident date/time defaulting to now. Existing form retained. |
| `lib/services/maintenance_service.dart` | Stores configured option IDs and readable snapshots; keeps unchanged historical option IDs on edits; photo upload/update workflow; omits client-created submission dates. |
| `lib/services/confidential_report_service.dart` | Original concern details and type snapshot; canonical workflow mapping; guarded review/history RPCs. |
| `lib/services/conduct_case_service.dart` | Guarded case-creation RPC; incident time serialized as UTC; readable category stored on the case. Cases use the existing label snapshot rather than a newly introduced category foreign key. |
| `lib/services/dormitory_report_service.dart` | Existing maintenance export uses submission date; conduct register uses incident date. Export data comes from report models. PDF printing/sharing was inspected, not executed. |

Confirmed defects:

1. `202610090003_configured_concern_snapshot_safety.sql` replaced the snapshot
   function and lost maintenance Other/specify checks introduced in
   `202610070013_final_choice_standardization.sql`.
2. Tenant maintenance/concern loaders could accept an older request after a
   newer response. Archiving the selected choice silently selected another
   choice. Maintenance also lost a newly selected category on rename.
3. `activeOptionId` interpreted literal `%`, `_`, and backslash characters as
   PostgreSQL pattern syntax and could resolve a different category.
4. Backend timestamp defaults did not prevent a supplied INSERT timestamp;
   original submission timestamps were not consistently protected for all roles.
5. The room linker accepted unsupported/archived room text, and the assigned-room
   locations RPC did not filter archived rooms.
6. Unmatched categories on pre-configuration maintenance rows could fail review
   because an unchanged historical label was validated as a new active choice.

## Fixes

- Tenant loaders reject obsolete success/error responses, preserve choice identity
  across renames, and require explicit reselection after archive. Initial defaults
  are retained. Existing report wording stays available when editing history.
- Maintenance subscribes to `rooms` as well as options; both forms allow manual
  refresh. Existing 15-second catch-up behavior remains. Conduct's existing
  30-second catch-up behavior was exercised in widget tests.
- Loading/failure disables the affected selectors. Empty lists have an explicit
  message. Maintenance/concern labels truncate safely in narrow dropdowns.
- Literal lookup characters are escaped while retaining case-insensitive matching.
- The new migration restores maintenance Specify validation without reverting the
  concern snapshot repair; new room selections must reference an active room or
  validated active common-area option. Assigned-room scope remains unchanged.
- Server-generated `statement_timestamp()` supplies new submission times;
  updates that change an original submission time are rejected. Existing dates
  are not backfilled. Incident time remains a separate existing field.
- Unchanged historical maintenance categories/locations remain reviewable,
  including unmatched categories with null option IDs. Existing Specify text is
  also retained when an Owner renames a custom Other option to a non-Other label;
  this scenario is covered by the migration regression test.

## Requirement status

Statuses below describe local evidence. Deployed behavior remains separately
**PENDING DEPLOYMENT VERIFICATION** for all database-dependent requirements.

| Request items | Status | Evidence / remaining limit |
| --- | --- | --- |
| Task 1: audit, paths, services, forms, schema, tests | COMPLETED AND TESTED | Existing infrastructure inspected; defects reproduced in the disposable SQL fixture before applying the fix. |
| Task 2.1–9: dynamic maintenance categories, Owner CRUD, active-only choices, history and sorting | ALREADY IMPLEMENTED AND VERIFIED | Existing source, sorting tests, local authenticated configuration operations and snapshot tests. Protected choices retain their existing restrictions. |
| Task 2.10: maintenance Other/specify | COMPLETED AND TESTED | Restored backend enforcement; trimmed details persist, switching away clears irrelevant details; widget fields tested. |
| Task 2.11: maintenance descriptions, attachments and workflow | ALREADY IMPLEMENTED AND VERIFIED | Existing maintenance widget/model and SQL workflow tests pass; photo code unchanged. Actual camera/storage upload not executed. |
| Task 2.12: changes appear without restart | COMPLETED AND TESTED | Refresh tests cover add/rename/archive/restore and overlapping requests; room subscription added. Live deployed websocket delivery pending. |
| Task 2 locations: authoritative rooms/common areas and archived history | COMPLETED AND TESTED | Actual assigned-room RPC/linker with fixture room records; rename/archive/restore, Bathroom variant, invalid choices and historical room IDs tested. No room/bed write rules changed. |
| Task 3.1–6: configurable concern types, CRUD, active-only, history and Other | ALREADY IMPLEMENTED AND VERIFIED | SQL and widget tests; descriptive custom types mapped to `other` do not incorrectly require Specify. Actual catch-all types do. |
| Task 3.7–10: dates, confidentiality, recipients, statuses and notifications | ALREADY IMPLEMENTED AND VERIFIED | Existing review/notification tests and authenticated RLS checks; new immutable timestamp guard tested separately. |
| Task 3.11: consistent mobile/web category refresh | COMPLETED AND TESTED | Shared Flutter forms tested at 390px and 1200px; stale responses and archived selections fixed. Actual platform releases pending. |
| Task 4.1–12: conduct categories, Owner CRUD, history, Other, validation and shared staff form | ALREADY IMPLEMENTED AND VERIFIED | Owner configuration SQL operations, actual case RPC validation, shared conduct widget tests and timed refresh tests. Existing evidence/status/warning/appeal and internal visibility tests pass. No disciplinary process/counting changes. |
| Task 5.1, 5.8: backend submission time and immutable originals | COMPLETED AND TESTED | New report INSERT timestamps override supplied dates; UPDATE rejects date mutation for all three report tables. |
| Task 5.2–4, 5.6, 5.9: incident defaults/editing, separate fields, existing storage convention and historical dates | ALREADY IMPLEMENTED AND VERIFIED | Dialog defaults tested; editable date/time controls inspected; UTC/timestamptz storage retained; distinct incident/submission values and historical dates tested. |
| Task 5.5, 5.7: Flutter/PDF timezone presentation | IMPLEMENTED BUT NOT VERIFIED | Existing device-local `.toLocal()` display convention retained. No fixed dormitory timezone is enforced independently of the device setting. PDF and differing-device-timezone acceptance checks remain outstanding. |
| Task 5.10: actual Android/iOS/web time behavior | BLOCKED BY DEPENDENCY | Requires platform/device/browser execution; widget tests are not native or browser release tests. |
| Task 6: add/rename/archive/restore, duplicate prevention, stable identity and historical meaning | COMPLETED AND TESTED | Existing immutable IDs/codes/mappings and case/trim-insensitive uniqueness verified; refreshed forms and historical preservation tested. No deletion API introduced. |
| Task 7: Owner/Caretaker/tenant permissions and confidential access | ALREADY IMPLEMENTED AND VERIFIED | Configuration RLS blocks Caretaker/tenant/guardian writes and anonymous reads; concern RLS prevents cross-tenant/guardian reads; staff RPC and conduct creation checks verified. |
| Task 8: ordering, constraints, references, RLS and disposable SQL integration | COMPLETED AND TESTED | Actual relevant migrations/functions applied to isolated PGlite schema fixtures. This is not a full clean replay of every repository migration or a full Supabase service environment. |
| Task 8: expected deployed schema/application compatibility | PENDING DEPLOYMENT VERIFICATION | No staging project; no production deployment attempted. |
| Task 9: cross-module CRUD/history, sorting, Other, empty/loading/failure/duplicates/refresh | COMPLETED AND TESTED | Local SQL, widget and protocol tests below. Existing search/filter contracts passed. Owner editor CRUD was not browser-driven end to end. |
| Task 9: actual Android/web session-to-session propagation | PENDING DEPLOYMENT VERIFICATION | Verify Owner changes in simultaneously open tenant and staff sessions after deployment to an approved disposable environment. |
| Task 10: formatting, analyzer, relevant Flutter and SQL regressions | COMPLETED AND TESTED | Results below. No claim of a full-repository Flutter suite or native platform run. |

There is no newly required configuration backend left **NOT IMPLEMENTED**.
An independently fixed application timezone is **NOT IMPLEMENTED**; the existing
device-local convention needs acceptance on target devices. No requirement is
claimed complete merely because its implementation was inspected.

## Permissions and history

Configuration management remains Owner-only at the database boundary; hiding a
button is not the security mechanism. Existing system Other concern choice is
protected. Label uniqueness includes archived choices, preventing restore clashes.

Existing migrations intentionally authorize **both Owner and Caretaker** concern
review via audited RPCs. Their direct concern-table access is not broadened.
Tenants can read their own concerns; unrelated tenants, guardians, and anonymous
sessions do not gain concern content access from configuration permissions.
Existing internal conduct/maintenance notes remain restricted; existing response
visibility tests passed. No new recipient, role grant or notification destination
was introduced.

Maintenance retains IDs plus original category/location text; concern reports
retain type ID plus original label; conduct cases retain existing category text.
Configuration rename/archive does not bulk-update those snapshots. Pre-existing
submission timestamps and unmatched historical maintenance choices are retained.

## Migration review and dependency order

Reviewed relevant source migrations:

1. `20260909181703_tenant_maintenance_crud.sql` and subsequent maintenance workflow/media guards.
2. `202609190003_tenant_confidential_reports.sql`, `202609190004_owner_confidential_report_review.sql`.
3. `20260924070000_phase4a_conduct_cases.sql` and existing conduct creation/response migrations.
4. `202610060002_staff_report_notification_access.sql` establishes existing staff review permissions.
5. `202610070006_dormitory_configuration_and_report_addenda.sql`: options, IDs, snapshots, RLS and RPCs.
6. `202610070008_phase3_dynamic_options_and_visitor_workflow.sql`: existing options realtime publication.
7. `202610070009_room_expansion_and_dynamic_capacity.sql` and `202610070011_dynamic_configuration_and_room_identity.sql`: room activity/identity and linker dependencies; inspected, not modified.
8. `202610070013_final_choice_standardization.sql`: Specify columns, catch-all helper, sorting.
9. `202610090003_configured_concern_snapshot_safety.sql`: current concern snapshot preservation.
10. `202610160001_configurable_business_categories.sql`: conduct options and active-category validation.
11. **New:** `202610160003_reporting_configuration_safety.sql`: reporting safety repairs.

The new migration requires the above reporting schema and functions, including
existing conduct and room tables. It creates no new configuration tables,
replaces no RLS policy, changes no notification producer, and updates no historical
rows. The preceding payment migration is not changed or exercised by the new
reporting fixture. Normal Supabase migration ordering must still be reviewed in
an approved environment; do not bypass or alter migration history to deploy this.

## Executed validation

| Command / suite | Result |
| --- | --- |
| `dart format` on all changed Dart files | Completed |
| `flutter analyze` | No issues found, 65.2 seconds |
| Targeted Flutter command below | **79 passed**, including 13 new tests |
| `node tool/test_reporting_configuration_safety.mjs` | **13 passed**, actual new migration applied in disposable in-memory PGlite |
| `node tool/test_configured_concern_safety.mjs` | **5 passed** |
| `node tool/test_phase2_report_notifications.mjs` | **37 passed** |
| `node tool/test_phase5_report_conduct.mjs` | **17 passed** |
| SQL total | **72 passed**; existing regression runners exercise their own isolated fixtures |
| `git diff --check` | Passed |

```powershell
flutter test test/views/reporting_configuration_safety_test.dart test/views/conduct_configuration_refresh_test.dart test/services/reporting_option_lookup_test.dart test/views/dynamic_business_categories_test.dart test/views/tenant_maintenance_test.dart test/views/staff_maintenance_test.dart test/models/maintenance_report_test.dart test/models/staff_maintenance_report_test.dart test/models/concern_report_configuration_test.dart test/services/dormitory_option_sorting_test.dart test/core/conduct_case_policy_test.dart test/core/conduct_case_appeal_policy_test.dart test/ui/dynamic_configuration_completion_contract_test.dart test/ui/phase2a_configuration_contract_test.dart test/ui/phase3_dynamic_options_visitor_contract_test.dart test/ui/phase4_dynamic_refresh_contract_test.dart test/ui/final_conduct_case_curfew_contract_test.dart
```

PGlite fixture prerequisites are documented in the SQL runner. Fixtures use
synthetic roles/users/rooms; PostgreSQL policies/functions are read from repository
migrations. Minimal supporting tables do not simulate Supabase Auth, PostgREST,
Storage, publication delivery, or concurrent multi-connection transactions.
The literal-label Flutter lookup test uses a loopback HTTP fixture; PostgreSQL
escape matching is also tested independently in the SQL runner.

Initial test-harness compilation and realtime timer cleanup issues were corrected
before the successful combined run. No failing check is being counted as passing.

## Files changed

- `lib/services/dormitory_configuration_service.dart`
- `lib/views/tenant/tenant_pages.dart`
- `supabase/migrations/202610160003_reporting_configuration_safety.sql`
- `test/services/reporting_option_lookup_test.dart`
- `test/views/reporting_configuration_safety_test.dart`
- `test/views/conduct_configuration_refresh_test.dart`
- `tool/test_reporting_configuration_safety.mjs`
- `docs/dynamic-reporting-validation.md`

## Commit sequence and remaining checks

Commits follow the repository's existing wording and the user's request to separate the changes:

1. `Dynamic reporting choices refresh and category lookup fixes implemented`
   (Dart changes and Flutter regression tests.)
2. `Reporting validation and automatic submission date protection implemented`
   (New migration and disposable SQL regression runner.)
3. `Dynamic reporting validation and deployment verification documentation added`
   (This report.)

Before release, provision an approved disposable Supabase environment, verify its
migration history/dependencies, apply through the normal migration workflow, and
exercise Owner CRUD plus tenant/staff forms in simultaneous sessions. Check actual
realtime/poll recovery, photos/evidence uploads, guarded concern access, status
notifications, PDF generation, and Android/iOS/web date/time presentation including
a device outside the Philippines timezone. These are remaining acceptance checks,
not permission to use production. Payments, contracts, capacity/occupancy and
disciplinary decisions/counting were not modified.

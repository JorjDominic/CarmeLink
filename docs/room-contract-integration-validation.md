# Room capacity and contract integration validation

Date: 2026-10-16. Base: `main`, `8ba2695`, initially clean and synchronized with
`origin/main`. Changes were subsequently grouped into local commits at the user's
request. No production
records, linked migration history, payment gateway, curfew or geofencing code were
changed. No push, merge, deployment, stash or reset was performed.

## Audit and retained architecture

| Path | Existing behavior and dependencies |
| --- | --- |
| `lib/services/room_service.dart` | Room/bed/assignment records, cache invalidation, archive/restore, floor registry and guarded room deletion. Reads the existing contract occupancy projection. |
| `lib/views/owner/room_monitoring_page.dart` | Existing room creation/editor, list/detail cards, room/floor/availability/name filters and realtime refresh. Capacity was presented as fixed at four. |
| `lib/views/owner/floor_plan_page.dart` | Live room projections use actual capacity/availability. Fixed drawing positions are layout slots, not a four-bed inventory. Retained without modification. |
| `lib/views/owner/contract_occupancy_fields.dart` | Registered rooms, tenants and stable bed IDs; Solo or Shared; per-tenant deposits and rent preview. Shared always reserved the room and divided total rent. |
| `lib/views/owner/contracts_page.dart` | Existing preparation confirmation, individual drafts, document generation/signing, activation and safe standalone renewal flow. |
| `lib/services/contract_service.dart`, `lib/controllers/owner_controller.dart` | Existing atomic `prepare_contract_occupancy` RPC and individual contract reload. Reused without a replacement service. |
| `lib/core/utils/contract_occupancy_policy.dart` | Existing exact-cent parsing/allocation, with an obsolete four-tenant ceiling. |
| `lib/services/contract_document_service.dart` | Contract PDFs use immutable occupancy snapshots and each contract's financial terms. Stored signed files are not regenerated automatically. |
| `lib/services/tenant_service.dart` | Existing available-bed selectors and staff assignment RPCs; selectors needed to respect contractual room reservations. |
| `lib/views/owner/room_occupancy_widgets.dart` | Read-only arrangement/member/rental/history display, with financial amounts hidden by default. |
| `supabase/migrations/202610130001_contract_room_occupancy.sql` | Existing arrangements, individual contract snapshots, reservation index, immutable terms and amendment blocks. |
| `supabase/migrations/202610130002_contract_occupancy_stabilization.sql` | Room locks, advisory tenant locks, guarded activation and signature verification. |
| `supabase/migrations/202610130003_room_contract_occupancy_display.sql` | Staff room projection, Owner-only financial fields and private room refresh triggers. |

Confirmed gaps: fixed-four constraints/triggers, no Standard Shared arrangement,
the shared rent formula applied to every shared selection, one-arrangement-only
room display, selectors offering unused exclusive beds, and release based on
contract status without checking whether assignments had ended. The new work
reuses the existing tables, signing checks, billing functions and room locks.

## Implementation and historical safety

- Four remains the default. Owner creation supports another positive integer
  capacity. The database creates the matching physical bed records.
- Owner capacity edits use a single guarded RPC, expected-capacity checking and
  room locks. Zero, negative, null and stale values are rejected. There is no new
  arbitrary business maximum; the existing integer column remains the storage type.
- Reductions retire eligible unused beds using `bed_spaces.retired_at` and
  `status='unavailable'`. They do not delete or reuse bed identities. Referenced,
  occupied or reserved beds cannot retire. Rooms with retired-bed history must be
  archived rather than deleted. Existing room/bed/assignment relationships remain.
- Deferred database constraints require physical, non-retired bed count to equal
  capacity at transaction completion. Direct writes cannot leave them inconsistent.
- Capacity reductions remain blocked while live occupancy arrangements exist.
  Increases preserve contract snapshots, rent, room identity and whole-room
  exclusivity. Capacity is physical configuration, not a rental amendment.
- Existing `shared` snapshots retain their exact stored values and continue to
  mean Exclusive Shared. `exclusive_shared` is also accepted by the backend.
  There is no historical relabeling or rate migration.
- Standard Shared uses `standard_shared` in the existing occupancy snapshot and
  an explicitly approved `monthly_rent` per incoming member. Existing exact-money
  validation and individual contract billing are reused. No total-room split is
  applied to this mode, and no rent-total figure is invented for its room display.
- Multiple Standard Shared preparations can coexist in a room. Room locks and
  existing unique tenant/bed assignments prevent conflicts. Solo/Exclusive Shared
  exclude outside occupants, including after physical expansion.
- Selecting an already occupied Standard Shared room keeps existing residents'
  contracts intact. Incoming selected tenants receive new individual drafts;
  existing roommate names are snapshotted for the incoming contract. An existing
  active contract cannot be selected for replacement by preparation.
- Room status, available beds, reserved beds, names, individual obligations and
  filters derive from existing arrangements, contracts and assignments. No new
  independently editable occupancy flag or rental engine was introduced.
- Contract preparation supports manual/realtime refresh using the existing
  subscription service. Stale responses and invalidated bed/count selections are
  rejected, including when available beds shrink without a physical capacity change.
- Legal contract end does not release an arrangement with active assignments.
  Assignment end alone does not release an active contractual obligation.
  Both event orders are tested. The existing authorized Caretaker assignment RPC
  still works; its nested display refresh may update only `updated_at`, not room
  structure. Direct structural changes and contract activation remain Owner-only.
- No old signed snapshot, agreed rent, security deposit or billing row is rewritten
  by these migrations. Original Shared snapshots/rates and existing billing rows
  are explicitly compared before/after upgrade and incoming Standard Shared leases.

Only physically approved arrangements should be entered. The application does
not grant permission to install physical beds. The Owner form states this limit.

## Requirement status

Statuses describe the evidence from this local run, not deployed acceptance.

| Task / requirements | Status | Evidence or limitation |
| --- | --- | --- |
| 1. Audit existing room/contract UI, services, schema and dependencies | COMPLETED AND TESTED | Existing paths and restrictions audited; old and new SQL/Flutter regressions executed. |
| 2.1–8: Add Room retained, default four, custom capacity, automatic beds, positive capacity, unique rooms/beds and increases | COMPLETED AND TESTED | Actual migrations and creation/configuration RPCs; custom six-bed rooms, growth, invalid/duplicate values, UI editor and selector protocol tests. |
| 2.9–14: safe decrease, occupied/reserved/history protection, archive/restore, floor identity and occupancy safety | COMPLETED AND TESTED | Retired IDs retained; unsafe decreases roll back; archived rooms reject changes/preparation; restoration retains IDs. Existing floor registry/layout safeguards remain. Decreases with live arrangements deliberately stay blocked. |
| 3.1–6: Solo selection, whole-room exclusivity, conflicts, tenant/rental display and original beds | ALREADY IMPLEMENTED AND VERIFIED | Existing Solo path retained; signing, exact full rent, reservation, model/UI and database checks passed. |
| 3.7–8: legal end and prevention of early release | COMPLETED AND TESTED | Contract-end/assignment-end order tests and authenticated Caretaker RPC check in real PostgreSQL. |
| 4.1–12: Exclusive Shared, selected registered tenants, capacity, whole-room reservation, equal shares, individual obligations, PDFs and signing | COMPLETED AND TESTED | Existing exclusive semantics retained and labeled clearly. Two/three/six-member cases, exact shares and immutable history tested; required signatures still gate each contract activation. Actual native signing/storage acceptance remains separate. |
| 5.1–13: Standard Shared, selected roommates, additional residents, fixed individual rates, no repricing, capacity, assignments, display and PDFs | COMPLETED AND TESTED | Two/three incoming members and later independent newcomer tested. Existing rent/snapshot/deposit/billing rows remain identical. Current residents remain on their own contracts; full/conflicting rooms reject preparation. |
| 6. Dashboard fields, statuses, search/filtering and responsive behavior | COMPLETED AND TESTED | Multiple Standard Shared groups aggregate in read-only summaries; exclusive beds remain unavailable; 320px/1280px widget checks and existing room/floor/name/availability filter tests pass. Native/browser release behavior remains unverified. |
| 7.1–13: room/contract preparation, reservations, capacity, activation, legal release, history, uniqueness and refresh | COMPLETED AND TESTED | Existing atomic RPCs/locks reused; new release safeguards, selectors and refresh invalidation tested. Deployed websocket delivery not exercised. |
| 7. Concurrency safety | COMPLETED AND TESTED | Three independent PostgreSQL connections; six checks including same-bed competition, different-bed retry, incompatible modes, capacity/preparation race, lock inversion and staff release. No deadlock or statement timeout accepted as success. |
| 8.1–10: existing contract billing, separate deposits, higher approved rates and historical obligations | COMPLETED AND TESTED | Fixed Standard Shared and equal Exclusive Shared calculations tested. New incoming lease uses its own higher rate; existing standalone renewal suite verifies a new agreed rate for a new term with historical bills/deposits preserved and no duplicates. |
| 9.1–9: preserve obligations, block unsupported amendments and retain safe existing infrastructure | ALREADY IMPLEMENTED AND VERIFIED | Existing occupancy-linked renewal/transfer and term mutation blocks remain. Standalone supported renewal/transfer suites pass. No departure/redistribution/deposit-transfer policy added. |
| 9. Roommate departure, replacement, redistribution and group amendment/renewal rules | REQUIRES CLIENT DECISION | Deliberately remain blocked; see decisions below. |
| 10. Owner/Caretaker/tenant permissions, constraints, references, ordering and transactional safeguards | COMPLETED AND TESTED | Owner checks on new RPCs, private helpers, existing RLS regressions, Caretaker financial redaction, actual authenticated staff release and independent concurrency checks. No new role grant over contracts or room configuration. |
| 11. Format, analyzer, relevant Flutter and local database regression tests | COMPLETED AND TESTED | Commands/results below. |
| Actual Supabase Auth/PostgREST/Storage/realtime integration and Android/iOS/browser signing/printing | BLOCKED BY DEPENDENCY | No disposable full Supabase/staging project configured. Standalone PostgreSQL and widget/protocol fixtures do not substitute for those services or devices. |
| New UI/PDF/runtime behavior in a deployed release | IMPLEMENTED BUT NOT VERIFIED | Local behavior verified; no deployment performed. |

No approved core room/occupancy feature is left **NOT IMPLEMENTED**. Unapproved
departure/amendment features were intentionally not added. Software tests cannot
verify physical room approvals.

## Migrations and rollout dependencies

Existing migrations reviewed include core room/bed constraints and active
assignment uniqueness (`202609070002`, `202609100004`), staff assignment RPCs
(`202609100002`), room lifecycle/identity/floor registry (`202610070009`,
`202610070011`, `202610090002`), contracts/signatures/billing, standalone renewal
and signed transfer (`202610090004`, `202610090006`), signed activation
(`202610120002`) and the occupancy trilogy (`202610130001`–`202610130003`).
Historical migration files were not edited.

New migrations, in this order:

1. `202610160004_dynamic_physical_room_capacity.sql`: positive configurable
   physical capacity, retirement/history protection, consistency constraints,
   guarded creation/configuration, and existing staff display refresh compatibility.
2. `202610160005_standard_shared_contract_occupancy.sql`: distinct fixed-rate
   Standard Shared, compatible reservation uniqueness, assignment validation and
   release only after contractual and physical assignment end.

The first depends on the existing room lifecycle and occupancy locking/metadata
functions. The second depends on the first and the existing preparation, signing,
activation, billing, snapshot and projection infrastructure. Neither is a standalone
bootstrap migration. Apply all missing prerequisites through normal migration
history; do not repair/reset a linked project to skip dependencies.

The app's new `retired_at` filters and Standard Shared submissions require these
migrations before releasing the changed app. Verify the API schema cache and
permissions in an approved disposable full environment first. No migration was
applied to the linked production project.

## Executed validation

| Command / suite | Result |
| --- | --- |
| `dart format` on changed Dart files | Completed |
| `flutter analyze` after final Flutter fix | No issues found (35.9 seconds) |
| Combined room/contract Flutter suite | 107 passed; log: `build/room_contract_regression_results.txt` |
| Affected form/widget suite after final refresh-count fix | 12 passed; log: `build/room_refresh_final_results.txt` |
| `node tool/test_dynamic_room_occupancy.mjs` | 17 passed; both new migrations on disposable PGlite PostgreSQL fixtures |
| `node tool/test_dynamic_room_concurrency.mjs --disposable --local-config <local connection.json>` | 6 passed; actual Docker PostgreSQL 17, three independent connections, both new migrations |
| `node tool/test_contract_occupancy.mjs` | 18 passed |
| `node tool/test_contract_renewals.mjs` | 20 passed |
| `node tool/test_room_transfers.mjs` | 14 passed |
| `node tool/test_room_contract_display.mjs` | 11 passed |
| `node tool/test_phase3_report_room_safety.mjs` | 21 passed |
| `node tool/test_signed_contract_activation.mjs` | Passed its signature/file/version/activation guard assertions; script does not print a numbered count |
| `git diff --check` | Passed |

The numbered SQL/concurrency suites total 107 checks. Existing regression runners
use their own baseline fixtures; the two new runners exercise the new migrations.
The combined Flutter suite and affected rerun overlap and must not be added as
119 distinct tests. Eleven new Flutter tests cover capacity, Standard Shared,
fixed rent/PDF behavior and service synchronization; existing tests were updated
where the approved wording/default behavior changed.

```powershell
flutter test test/views/dynamic_room_occupancy_test.dart test/core/contract_occupancy_policy_test.dart test/models/room_model_test.dart test/models/room_contract_occupancy_test.dart test/models/tenant_contract_test.dart test/models/contract_onboarding_test.dart test/views/contract_occupancy_fields_test.dart test/views/contracts_page_test.dart test/views/room_monitoring_merged_test.dart test/views/room_transfer_proposal_test.dart test/services/contract_occupancy_document_test.dart test/services/contract_document_service_test.dart test/services/contract_occupancy_service_test.dart test/services/contract_renewal_service_test.dart test/services/room_selector_sync_test.dart test/services/room_occupancy_sync_test.dart test/services/room_transfer_service_test.dart test/ui/phase3_reports_rooms_test.dart test/ui/phase4_room_expansion_contract_test.dart test/web/room_directory_filter_test.dart
```

Local SQL uses minimal supporting schemas with real migration functions,
constraints and selected policies. This was not a full clean replay of every
repository migration, a production-data clone, or a full Supabase service stack.
Concurrency scripts reject non-loopback addresses, non-test database names,
nonempty databases and missing disposable opt-in. Ignored local connection files
contain only disposable credentials and were not printed or committed.

PDF bytes and snapshot-derived rows were generated and checked. Existing
Helvetica font warnings remain; visual acceptance of non-ASCII names, native
printing/sharing and real uploaded signature evidence is still required.
Initial fixture/type, old wording and refresh issues were fixed before the
successful checks above; failed runs are not counted as passing.

## Files modified or added

Production Dart:

- `lib/core/utils/contract_occupancy_policy.dart`
- `lib/services/contract_document_service.dart`
- `lib/services/room_service.dart`
- `lib/services/tenant_service.dart`
- `lib/views/owner/contract_occupancy_fields.dart`
- `lib/views/owner/contracts_page.dart`
- `lib/views/owner/room_monitoring_page.dart`
- `lib/views/owner/room_occupancy_widgets.dart`

Migrations and database tests:

- `supabase/migrations/202610160004_dynamic_physical_room_capacity.sql`
- `supabase/migrations/202610160005_standard_shared_contract_occupancy.sql`
- `tool/room_capacity_occupancy_fixture.mjs`
- `tool/test_dynamic_room_occupancy.mjs`
- `tool/test_dynamic_room_concurrency.mjs`

Flutter tests:

- `test/views/dynamic_room_occupancy_test.dart`
- `test/views/contract_occupancy_fields_test.dart`
- `test/models/room_contract_occupancy_test.dart`
- `test/services/contract_occupancy_document_test.dart`
- `test/services/room_occupancy_sync_test.dart`
- `test/services/room_selector_sync_test.dart`
- `test/ui/phase3_reports_rooms_test.dart`
- `test/ui/phase4_room_expansion_contract_test.dart`

Report: `docs/room-contract-integration-validation.md`.

## Decisions, commit sequence and readiness

Client decisions still required: roommate departure/replacement authorization,
redistribution of obligations, group amendments/renewals and related deposit
handling. No rent was redistributed, no deposit transferred by new occupancy
logic, and no departure penalty or replacement policy was invented. Existing
occupancy-linked renewal/transfer operations remain blocked. Existing standalone
renewals/transfers retain only their already supported behavior.

Commits use the repository's wording and omit phase labels:

1. `Dynamic room capacity and shared occupancy integration implemented`
2. `Room capacity and contract occupancy regression coverage added`
3. `Room and contract integration validation documentation added`

Local implementation is ready for review and disposable staging acceptance.
Production readiness is **not established**. Before release, verify the full
migration chain and API permissions in an approved disposable Supabase stack;
exercise Owner/Caretaker/tenant sessions, actual signing/storage, concurrent
reservations, realtime refresh, mobile/browser layouts and printed PDFs. Confirm
physical capacity approval outside the software. Do not use production for those
acceptance tests or infer permission to deploy from this report.

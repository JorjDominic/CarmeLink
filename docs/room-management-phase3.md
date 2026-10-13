# Phase 3 room management integration

Implementation and local validation completed on `main`, 2026-10-13. Existing Phase 2 stabilization changes were preserved. The user subsequently authorized the grouped commits and push. No production/shared database mutation or external migration deployment was performed. Phase 4 was not started; existing tests with that name were used only as regression checks.

## Audit and data dependencies

- `lib/services/room_service.dart` already provided room/floor CRUD, fixed-four-bed creation, assignment RPCs, cached authorized room records and a Phase 2 reservation overlay. It previously read only reserved room IDs, so it could not display modes, approved amounts, group members, signing status or contract history.
- `lib/views/owner/room_monitoring_page.dart` already provided room cards/details, search, availability filters, pagination, cleaning/inspection navigation, Owner structural actions and debounced table refresh. It missed floor/arrangement filters and used physical occupancy labels for contractually reserved rooms.
- `lib/views/owner/floor_plan_page.dart` previously advertised `capacity - occupied` beds as available, including unused beds reserved by contracts.
- Phase 2's `contract_occupancy_arrangements` and `tenant_contracts.occupancy_snapshot` remain the sole contractual source. Both solo and shared groups reserve the **entire room**. There is no unresolved shared-exclusivity business decision and no new exclusivity rule.
- `tenant_assignments` remains the source of actual bed occupancy; ended records stay intact. Existing signed transfer records remain the authority for individual legacy transfers. Group transfers/amendments remain blocked by Phase 2.
- Reservation table grants allow staff room IDs/release status, not the private group snapshot/deposit fields. General contract SELECT is Owner/own-tenant/linked-guardian scoped; caretakers do not have general contract access. The new curated staff summary is needed to present room occupancy without widening those table policies or exposing financial data.
- Existing room realtime publication and `TableRefreshSubscription` are reused. Contract and reservation changes previously did not produce a room refresh event; a narrow trigger now updates only the corresponding room's `updated_at`. The existing 30-second catch-up remains a fallback.

## Feature status

| Feature | Status | Scope and evidence |
| --- | --- | --- |
| Solo occupancy | COMPLETED AND TESTED | Active versus draft labels, registered tenant/bed, exclusive reservation, unchanged physical capacity. |
| Shared occupancy | COMPLETED AND TESTED | 2/3/4-member groups, contracted versus assigned counts, unused reserved beds, departed members retained. |
| Dashboard and room details | COMPLETED AND TESTED | Derived labels, availability, roster, capacity, signing/reservation status; list and map use consistent availability. |
| Search/filtering | COMPLETED AND TESTED | Existing room/floor/description search retained, assigned-tenant search added; floor, solo/shared/vacant, reserved/unavailable filters added; natural sorting and pagination retained. |
| Synchronization | IMPLEMENTED, PENDING VERIFICATION | Service lifecycle fixtures, room refresh signals and eight real PostgreSQL contention tests passed. Actual Supabase realtime delivery and full-stack lifecycle testing remain pending. |
| Rental information | COMPLETED AND TESTED | Owner reads agreed room total and stored per-contract monthly obligations; backend omits amounts for caretakers. No recalculation or edits. |
| Room actions and permissions | COMPLETED AND TESTED | Reservation-aware archive/delete/edit/move validation; existing backend permissions and constraints retained. Metadata edits no longer force capacity to four. Four-bed creation policy unchanged. |
| Occupancy history | COMPLETED AND TESTED | On-demand existing arrangements and original assignments, dates, contract references and status; released/terminated records displayed as history. Failure/retry path tested. |
| Approved group amendment scenario | BLOCKED BY PHASE 2 DEPENDENCY | Phase 2 has no complete amendment/version, deposit-reference and approved prepaid reconciliation workflow. No simulated amendment or bypass was implemented or claimed tested. |
| Full staging/browser/physical-device verification | IMPLEMENTED, PENDING VERIFICATION | Local automated evidence below does not establish production readiness. |

No Phase 3 feature requires a new rental split decision. Additional caretaker financial privileges would require separate explicit approval and are not included.

## Final behavior

Physical capacity, current assignments and contractual member count are displayed separately. An active solo arrangement displays **Solo Occupied**; draft arrangements display **Signing Pending**, even though preparation already creates assignments/reservations. An exclusive shared arrangement displays **Shared – Fully Reserved**, including a four-bed room with only three contracted occupants. Physical unused beds never imply eligibility for another assignment.

Rooms without Phase 2 arrangements use actual assignments and bed availability. Vacant, Full, partially occupied and archived/unavailable labels are derived, not independently editable fields. Reserved room IDs remain a conservative availability guard if detailed contract data is absent. Missing summary migrations fail the load rather than treating rooms as free; previously cached rooms carry an explicit stale-data warning.

Owner financial display reads snapshot `total_rent_cents` and each contract's existing `monthly_rent`; the server converts the stored decimal amount to cents for display only. Deposits are neither fetched nor exposed. A three-person PHP 6,000 agreement retains PHP 2,000 per contract after one member departs. Ended contract members are identified by status and absence of a current bed assignment, rather than silently removed from the original terms.

A group reservation releases only when Phase 2's existing lifecycle marks every member's contract ended and releases the arrangement. Dates alone do not release a room. Any remaining active assignments or unavailable beds still reduce assignment availability afterward. Ending one physical assignment never releases the whole group or changes rental terms.

Room/floor creation, archive/restore, sorting, pagination, cleaning, inspection navigation and existing permitted legacy transfer flows remain. Reserved structural bed edits and grouped moves show useful blocks. Ending an assignment no longer promises that its bed becomes available despite a reservation. No room action changes contracts, signing requirements, billing, payment/deposit balances or transfer history.

## Files changed for Phase 3

Application:

- `lib/services/room_service.dart`: read-only occupancy/history integration, projection models, derived statuses, reservation-aware availability, useful errors; remove capacity rewriting from metadata edits.
- `lib/views/owner/room_monitoring_page.dart`: summaries, filters/search, live refresh/errors, guarded actions, history integration, clearer departure messaging.
- `lib/views/owner/room_occupancy_widgets.dart` (new): shared read-only summaries and lazy history with error/retry.
- `lib/views/owner/floor_plan_page.dart`: reservation-aware totals/status/colors, scrollable details and wrapping status/title.

Database/validation:

- `supabase/migrations/202610130003_room_contract_occupancy_display.sql` (new): curated staff read RPC and existing-room refresh triggers.
- `supabase/rollback/202610130003_room_contract_occupancy_display.sql` (new): removes display functions/triggers only; retains all history.
- `supabase/rollback/202610130002_contract_occupancy_stabilization.sql`: refuses reversal while Phase 3 refresh helpers exist; earlier Phase 2 work retained.
- `tool/test_room_contract_display.mjs` (new): actual SQL projection/authorization/lifecycle/history/rollback checks in disposable PostgreSQL fixtures.
- `tool/test_contract_occupancy_concurrency.mjs`: optional `--room-display` adds the new migration to the already prepared real PostgreSQL suite.
- `test/models/room_contract_occupancy_test.dart` (new): statuses/counts, reservation rules, rental preservation, filtering, role-safe presentation, mobile/desktop UI, floor-plan panel, history/retry.
- `test/services/room_occupancy_sync_test.dart` (new): local HTTP draft/activation/departure/termination/history fixtures and missing-migration cache/error behavior.
- `test/services/room_selector_sync_test.dart`: verify metadata edits do not write physical capacity.
- `test/services/contract_occupancy_service_test.dart`: preserve its reservation fallback test while recognizing the new read-only POST RPC separately from table writes.
- This report and the Phase 2 stabilization report: deployment dependency and rollback order.

## Database change and permissions

No new tables, redundant occupancy fields, financial engine, constraints, bed records or financial writes were added. No existing migration was rewritten. `get_room_contract_occupancies(uuid, boolean)` is SECURITY DEFINER with an empty search path and a null-safe authenticated staff guard; default reads return unreleased arrangements, while room-scoped history includes released arrangements. It returns only curated room metadata, original roster, effective dates and contract references/status. Owner amounts are included; caretaker amounts are omitted at the backend. PUBLIC/anon cannot execute it. Existing contract/reservation table policies and mutation rights are unchanged; no caretaker creation, approval or activation permission was added.

The private refresh trigger only changes `rooms.updated_at` on future reservation creation/release or contract status transitions. It reuses Phase 2's fail-fast room lock and existing rooms publication. Raw group snapshots/deposit terms and contract tables are not newly published for realtime. Triggers are not executable as application RPCs.

Required sequence: existing historical prerequisite migrations, then `202610130001_contract_room_occupancy.sql`, `202610130002_contract_occupancy_stabilization.sql`, **`202610130003_room_contract_occupancy_display.sql`**, then matching app. These files were applied only to isolated local test schemas; full historical migration-chain compatibility remains a staging task.

Use the separately configured disposable local workdir and outbound-job safeguards described in [Phase 2 stabilization](contract-room-occupancy-phase2-stabilization.md). Review local migration history and dry-run first:

```powershell
supabase migration list --local --workdir <disposable-local-workdir>
supabase db push --local --dry-run --workdir <disposable-local-workdir>
supabase db push --local --workdir <disposable-local-workdir>
supabase migration list --local --workdir <disposable-local-workdir>
```

Do not use linked production configuration, reset a database, or repair history automatically. Read-only postflight:

```sql
select to_regprocedure('public.get_room_contract_occupancies(uuid,boolean)');
select has_function_privilege('anon','public.get_room_contract_occupancies(uuid,boolean)','EXECUTE');
-- Must be false.
select tgname from pg_trigger where not tgisinternal
  and tgname in ('room_occupancy_display_changed','room_contract_display_changed');
select tablename from pg_publication_tables
where pubname='supabase_realtime' and schemaname='public'
  and tablename in ('rooms','bed_spaces','tenant_assignments','profiles');
```

Then use disposable Owner/caretaker/tenant/guardian sessions to verify exact data and role behavior; SQL run as a privileged administrator does not validate JWT/RLS integration. Confirm realtime room refresh after activation and final termination without a manual page reload.

Rollback order is display **003**, stabilization **002**, original occupancy **001**. Disable the matching new app before removing its summary RPC. The display rollback removes only its functions/signals and can preserve existing history; reversing the Phase 2 occupancy schema remains forbidden once occupancy records exist. Use forward corrective migrations after contractual history exists. No rollback or migration-history repair was run against shared/production data.

## Actual test results

- **126 selected Flutter tests passed across 22 files; one full Supabase staging test skipped.** New cases cover vacant, full, archived, solo, 2/3/4 tenants, unused exclusive beds, departures with unchanged obligations, termination with remaining assignments, filters/current-tenant search, history and retry. Responsive checks include 320/1280-pixel forms, enlarged text, keyboard inset and the narrow floor-plan details panel. Phase 1/2 and existing room/transfer regressions passed.
- `flutter analyze`: no issues found. Changed Dart files formatted; `git diff --check` passed.
- **11 new room display PostgreSQL checks passed**, including SQL role denial, caretaker financial omission and unchanged direct contract access, contract activation refresh signals, physical-capacity preservation, departure/no-rent-redistribution, retained bills/deposit terms/history, blocked conflicting assignments/archiving, immutable group terms, rollback ordering and projection rollback/reapply.
- **Eight real PostgreSQL 17.6 contention checks passed using three independent sessions with migration 003 applied.** The baseline deadlock was reproduced before corrective migration 002. New room refresh signals did not introduce a deadlock in these tested patterns.
- Existing SQL suites passed again: 18 occupancy checks, 21 room/report safety checks, 20 renewal checks, 14 signed-transfer checks and signed-contract activation checks.
- Actual Supabase Auth/Storage signing, actual realtime delivery, full historical migration-chain staging and physical-device/browser verification were not performed. The earlier browser attempt in Phase 2 stalled on Flutter CanvasKit asset HTTP 404s; it is not a Phase 3 browser pass. No approved group amendment execution test ran because that workflow does not exist.

Logs are local ignored artifacts: `build/phase3-flutter-final.log`, `build/phase3-analyze-final.log`, `build/phase3-real-concurrency.log`, and `build/phase3-sql.log`. Real database fixtures used a fresh dedicated database in the existing isolated internal Docker network; no shared/live connection or destructive reset was used. Generated credentials remain ignored and unprinted. The dedicated test container is stopped after validation, with datasets retained.

Reproduce SQL projection checks with `node tool/test_room_contract_display.mjs`. The independent runner accepts `--room-display` alongside its existing disposable local database guards; it requires a new empty validation database, not the retained used fixture. The full Supabase workflow test and its safe fixture prerequisites are documented in the Phase 2 report.

## Remaining verification and readiness

On disposable full-stack staging, verify all migration prerequisites, real roles/JWTs, Owner amounts versus caretaker omission, guard errors, missing/rejected signing evidence, solo/2/3/4-person activation, actual realtime updates, final termination, legacy signed transfers and historical reads. Check that no remaining assignment is lost on release and no other member's obligations change on departure. Run these checks with both Room Management and the contract page open.

On actual phones/tablets and supported browsers, check long room/floor/tenant labels, keyboard/search and filter selection, pagination, map pan/zoom/details scrolling, history expansion/retry, permitted Owner/caretaker actions and stale/offline warnings. Existing contract/PDF signing/upload verification remains a Phase 2 release dependency.

Production readiness is **pending** those external checks and migration rollout review. Group amendments and grouped transfers remain **BLOCKED BY PHASE 2 DEPENDENCY**, and their functionality was not recreated in Phase 3. A release without those operations requires an explicitly agreed scope that retains the blocks.

Feature-specific commit wording authorized after validation:

1. Solo and shared occupancy added to room management
2. Room search and occupancy filters implemented
3. Contract room history and reservation refresh integrated
4. Phase 3 room validation tests and deployment notes added

Keep the earlier Phase 2 stabilization fixes separately reviewable when committing; shared test/rollback hunks must accompany their matching dependencies.

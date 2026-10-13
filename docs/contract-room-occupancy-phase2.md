# Contract room occupancy - Phase 2

## Scope and architecture

Preparation extends `contracts_page.dart`, `ContractService`, `OwnerController`, `TenantContract` and the existing official lease PDF service. No Phase 3 dashboard work is included. New contracts use an existing registered room, its actual capacity, one to four selected registered tenants and distinct existing beds. Shared contracts require two to four tenants. Custom room numbers remain managed by the existing Room Management workflow and its unique database constraint; this form cannot create rooms.

Each occupant receives an individual Draft contract. `prepare_contract_occupancy` locks the room, locks tenant advisory keys in stable ID order, checks active/draft contracts and assignments, checks room and bed availability, and saves all assignments and contracts atomically. Preparation assigns beds before signing, as existing onboarding already requires a room before PDF generation. Draft agreements reserve the entire room for the selected group, including spare beds. Existing occupied beds may be retained for their current selected tenants; assignments in another room are rejected rather than moved silently.

Physical room capacity and stored bed statuses are unchanged. `RoomService` overlays the existing reserved status for live occupancy agreements. Database assignment triggers also protect reservations for direct writes and legacy assignment RPCs. Room and bed metadata cannot invalidate a reserved agreement. Each contract still completes the existing individual document, signer and activation checks; activation rechecks all confirmed member assignments and displays an explicit occupancy confirmation.

## Money and documents

Input is parsed as integer centavos. For N tenants, each share is `total ~/ N`; the first `total % N` tenants in sorted tenant ID order receive one additional centavo. SQL performs the same integer allocation and is authoritative. PHP 6,000 gives PHP 6,000 / 3,000 / 2,000 / 1,500 for one / two / three / four occupants. PHP 100 across three tenants gives 33.34, 33.33 and 33.33. The UI recalculates and shows each share before confirmation.

Each resulting share is saved into the existing `tenant_contracts.monthly_rent`, so the existing `generate_contract_billing_charges` uses it without a parallel billing engine. Dates, deposits, existing bills and payment history are retained. Deposits are entered individually and follow the current behavior of recording them as received when the draft is created. Utilities and additional charges are not split. Existing contracts without occupancy fields retain their existing terms and workflows, including legacy renewals. Direct creation of new initial contracts without occupancy preparation is rejected at the database boundary; the previous plain create helper is no longer used by the new contract form.

The shared immutable snapshot records room number, original capacity, arrangement, dates, total rent and member names, beds and shares. Individual lease PDFs use this snapshot instead of a subsequently changed assignment. The original template, clauses and signatures remain. Roommate deposit amounts are kept separately and are not present in other tenants' snapshots. Authenticated clients can read only reservation room IDs and release flags on the new arrangement table; existing contract RLS remains unchanged.

## Authorization and amendment dependency

The repository's contract creation and activation privileges currently require Owner access. This change preserves that rule. Caretakers continue to see existing room availability, but granting them contract lifecycle rights requires a separately approved authorization change.

Existing renewals and signed room transfers cover individual contracts, not group membership, group room reservations or a new split across multiple signed agreements. Consequently grouped contracts cannot use those mechanisms until a complete group amendment workflow is approved. Attempts are rejected before a room transfer reserves a destination. Legacy renewals and transfers remain available.

Solo-to-shared changes, changing the count, replacing a roommate, changing group rent, moving a grouped occupant and renewing a grouped agreement remain dependencies. The implementation does not invent an unsigned amendment path or rewrite an existing signed snapshot. Ending one member's contract does not change anyone else's rent or old bills. The reservation remains until every associated contract is Expired or Terminated. Assignment history remains; closing contracts does not silently end room assignments. Draft corrections currently require terminating the group drafts and preparing replacement individual contracts, with deposit reconciliation under the existing deposit workflow.

## Migration and deployment

1. Review `supabase/migrations/202610130001_contract_room_occupancy.sql` against a staging database containing all prior migrations, including renewals, signed room transfers and signed-copy activation.
2. Take the normal database backup, then explicitly apply the migration through the deployment process. Nothing is deployed by this task.
3. Reload the Supabase API schema cache if needed before distributing the matching application. The new client selects optional occupancy columns and reservation records; it must not be deployed before the migration.
4. Verify owner/tenant/caretaker RLS on staging and complete a real signing/storage/activation flow. Test two separate PostgreSQL connections preparing the same room and the same tenant in different rooms, plus a competing legacy bed assignment. The database locks and unique indexes are implemented; the isolated PGlite test runner serializes requests and cannot prove real-session deadlock behavior.
5. The manual rollback is `supabase/rollback/202610130001_contract_room_occupancy.sql`. It reverses an unused deployment and restores the prior tenant contract RPC. It refuses to erase any occupancy agreements once contractual records exist. After use, fix forward or restore a compatible application; do not drop signed contractual history.

## Validation

- `dart format` on changed Dart files.
- `flutter analyze`.
- Focused Flutter policy, widget, service, PDF, legacy model, contract, renewal, onboarding and room synchronization tests.
- `node tool/test_contract_occupancy.mjs`: executes the new migration in isolated PostgreSQL alongside repository assignment, contract, signer, activation and billing functions; checks one-to-four occupancy, exact centavo allocation, invalid/duplicate/conflicting rooms and tenants, activation, privacy, term immutability, historical bills, queued competition, guarded rollback and reapply.
- Existing `test_contract_renewals.mjs`, `test_signed_contract_activation.mjs`, and `test_room_transfers.mjs` verify legacy behavior separately.

PGlite setup, if absent: `npm install --prefix build/phase2_sql_tests --no-audit --no-fund --ignore-scripts @electric-sql/pglite`. This is a local test dependency, not an application dependency. No live tenant records or deployed database are used by these scripts.

## Final local results

- 69 selected Flutter tests passed across 12 test files, including narrow/desktop occupancy fields, live preview updates, service payload/error handling, reservation availability, generated PDFs, legacy contracts, grouped term protections and Phase 1 regressions.
- `flutter analyze`: no issues found.
- 15 isolated occupancy database checks passed, plus empty-database rollback/reapply. Includes capacity/conflict checks, original assignment preservation, cents allocation, signing/activation checks, unchanged historical billing, reservation RLS and rollback protection.
- Existing PostgreSQL scripts: 20 renewal checks passed; 14 signed room transfer checks passed; signed contract activation checks passed.
- Formatting and `git diff --check` passed.
- Not performed: deployed migration, live Supabase/storage signing flow, manual browser/device verification and real multi-session PostgreSQL concurrency. Docker was not running. The queued PGlite competition test is not a multi-session lock test.
- No branch switch, commit, push, stash or deployed schema modification.

## Files changed

Application files:
- `lib/core/utils/contract_occupancy_policy.dart` (new): exact centavo parsing and deterministic rent allocation preview.
- `lib/views/owner/contract_occupancy_fields.dart` (new): registered room, mode, capacity, roommate, bed, individual deposit and share selection.
- `lib/views/owner/contracts_page.dart`: preparation confirmation, immutable group term display, activation confirmation and scroll support; unsupported group renewals hidden.
- `lib/controllers/owner_controller.dart`: batch draft preparation and room cache invalidation.
- `lib/models/models.dart`: optional occupancy ID/snapshot parsing and preservation through copies.
- `lib/services/contract_service.dart`: atomic preparation RPC and authoritative individual contract reads.
- `lib/services/contract_document_service.dart`: snapshot room and occupancy rows in existing PDF and execution copy.
- `lib/services/contract_onboarding_service.dart`: optional occupancy terms on linked tenant contract reads.
- `lib/services/room_service.dart`: live group reservation availability using the existing room/bed models.

Database and documentation:
- `supabase/migrations/202610130001_contract_room_occupancy.sql` (new): transactional preparation, room/member locks, immutable snapshots, reservation guards, activation validation, privacy, lifecycle release and tenant-scoped reads.
- `supabase/rollback/202610130001_contract_room_occupancy.sql` (new): guarded unused-deployment reversal.
- `docs/contract-room-occupancy-phase2.md` (new): architecture, limitations, deployment, rollback and validation report.

Tests:
- `test/core/contract_occupancy_policy_test.dart` (new).
- `test/views/contract_occupancy_fields_test.dart` (new).
- `test/services/contract_occupancy_document_test.dart` (new).
- `test/services/contract_occupancy_service_test.dart` (new).
- `test/views/contracts_page_test.dart`: tenant picker finder updated and grouped term/renewal protection added.
- `test/core/onboarding_safety_contract_test.dart`: room source assertion made formatting independent; legacy behavior retained.
- `tool/test_contract_occupancy.mjs` (new).

## Suggested commits

Use feature hunks where shared files participate in several purposes:
1. Contract occupancy data and validation implemented
2. Room and roommate selection added to contracts
3. Equal rental sharing calculations implemented
4. Contract PDFs updated with occupancy and rental details
5. Contract activation occupancy validation integrated
6. Phase 2 regression tests and deployment notes added

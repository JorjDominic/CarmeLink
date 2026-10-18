# Current system scope

Updated October 19, 2026. This checklist covers the agreed application scope.

| Requirement | Current scope and status |
| --- | --- |
| Dynamic maintenance reports | Implemented: configured categories/locations, database-backed lists, filters, statuses and refresh. |
| Dynamic violation reports | Implemented: configured categories, tenant selection, incident time, history, warnings, responses and appeals. |
| Payment gateway / automatic verification | **Partial — test/demo only.** PayMongo QR Ph verification is implemented and test transactions exist. The linked database remains in manual collection mode with the test environment. No live collection claim. |
| Report dates | Implemented: server-generated immutable submission time; separately editable conduct incident date/time. |
| Rooms, beds and expansion | Implemented: owner-managed rooms, physical capacity, bed inventory and protected historical assignments. |
| Four-person / solo rooms | Implemented: capacity and occupancy arrangements support these, Standard Shared and exclusive shared occupancy. |
| Caretaker violation access | Implemented and intended: caretaker can manage cases, warnings, evidence and appeal review. Explicit final investigation decisions remain owner-only. |
| Confidentiality agreement | Tenant confidentiality applies to the confidential-report module. Guardian confidentiality is **not applicable** because guardians do not use that module. Guardian geofencing agreements remain separate. |
| Receipts | Complete for the current agreed scope: immutable payment receipts and management-issued receipt records. |
| System maintenance | Implemented and database-deployed: staff administration entry, owner maintenance controls, staff audit access and owner configuration backup/restore. Full infrastructure recovery remains with the hosting platform. |
| Investigation status | Implemented: separate administrative status and confirmed/not-confirmed/overturned owner findings. |
| Evidence reporting | Implemented: private staff evidence and tenant response/appeal image attachments. |
| Repeated / continuous violations | Implemented and database-deployed: two or more confirmed incidents flag repeated violations; three or more within 90 days flag continuous violations. Staff have a dedicated tenant register. |

## Staff navigation

- Mobile: Operations → Reports & Cases → **System maintenance** or
  **Repeated violations**. Both are available to owner and caretaker.
- Web: Administration → **System maintenance**; Access & Safety →
  **Repeated violations** and **Conduct & Cases**.
- The repeated-violation register lists each tenant once, includes confirmed
  incidents from closed cases, supports name/status filtering, and opens the
  tenant's case register. If all their cases are closed, that register opens
  History automatically. Counts are recalculated on refresh and scheduled catch-up.
- Tenant case details retain the affected tenant's own investigation/count view.
  Other tenants and guardians cannot access those conduct details.

## Deployment and verification

Applied these pending migrations to the linked sample-data database in order:
`202610190002`, `202610190003`, `202610190004`, `202610190005`.
The last two deploy the existing report-subject link and assignment-guard repair
alongside the maintenance and repeat-tracking changes.

The rollback-only validation in
`supabase/tests/system_maintenance_repeat_live_validation.sql` passed 22 checks
using existing profiles as authenticated PostgreSQL role identities. It verified
owner mode/backup/restore, stale versions, caretaker access and restrictions,
tenant/guardian isolation, confirmed totals, continuous flags, tenant appeals,
caretaker appeal review and owner overturn/dismissal corrections. It is a backend
role test, not a browser login or physical-device session test.

All temporary cases, warnings, appeals, notifications, backup records, option
changes and maintenance changes were rolled back. Follow-up queries confirmed
maintenance is off, no validation cases/backups remain, all four migrations are
recorded and the assignment-history guard is restored. Payment mode/environment
and agreement contents were unchanged.

Focused Flutter coverage: 37 tests passed across maintenance administration,
tenant flags, availability gates, investigation/agreements, module gates and
tenant queue regression. Disposable SQL regressions also passed: reporting 20,
investigation/maintenance 24, room/occupancy 22 and signed transfers 15.

Full `flutter analyze --no-pub` passed. Client builds also passed:

- `flutter build web --release --target lib/main_web.dart --no-wasm-dry-run`:
  output `build/web`.
- `flutter build apk --release`: output
  `build/app/outputs/flutter-apk/app-release.apk`. The project currently uses its
  existing debug signing configuration for release builds, suitable for this
  development/demo distribution rather than an app-store signing claim.

REST probes confirm that the newly deployed tracking/search endpoints and
maintenance table are discoverable and reject anonymous access with PostgreSQL
permission error 42501, rather than a missing-function/schema-cache error.

The new screens require the updated client; database deployment does not replace
an installed APK. The hosted web release is separate from the successful local
web build and source push. Actual Android/iOS file picker/export and on-device
walkthrough remain device acceptance tasks.

# Confidentiality and geofencing agreement gates

Both modules use the same workflow: open module, review the current agreement,
scroll through it, explicitly check acceptance, then **Accept and continue**.
Decline/back leaves the module locked and returns to the previous screen (or the
dashboard when it is a root destination). Other app modules stay accessible.
Failed verification or acceptance never unlocks module contents.

Owner web navigation: **Administration → Confidentiality agreements** or
**Administration → Geofencing agreements**. On mobile these are in
**Operations → Reports & Cases**. Both pages publish separate approved versions
for tenants and guardians and show acceptance status. Participants can also
review their histories from **Profile → Edit profile**.

No wording is seeded. Until the owner publishes an agreement for a module and
audience, that module is unavailable to that audience. Existing confidentiality
versions and acceptances are retained. The two modules have independent version
histories; accepting one does not accept the other. Reusing a version with
different content is rejected, and published content/acceptances are immutable.

Gates cover tenant confidential reporting and tenant/guardian presence pages,
including notification routes. Database policies and triggers protect report
reads, submissions, addenda, gate-event reads and automatic check-in writes.
Staff management and observed manual gate logs remain available. Curfew request
forms reached independently are unaffected; the combined presence module is gated.

Geofencing acceptance is checked before on-demand location evaluation, scheduler
startup, native registration and native sampling. Device location permissions
remain a separate requirement. The app checks on resume, agreement updates and
30-second polling. Native Android monitoring rechecks every 30 seconds while
running; iOS rechecks on its timer and before processing location callbacks when
the previous check is older than 30 seconds. Android boot restoration and fallback
verification also require server confirmation. Verification failures pause
monitoring; it can resume after successful validation while the app is active or
reopened. OS suspension and network delays can delay native refresh; they cannot
make a server write bypass the current agreement requirement.

Publishing a replacement invalidates prior acceptance for that module/audience.
Server writes are blocked immediately; open gates and native monitoring pause
when they receive/recheck the change. Acceptance of the replacement restores
access. Location-off alerts are not claimed for tenants who have not accepted
the current geofencing agreement, so agreement pauses are not treated as violations.

Rollout: apply `202610180002_module_agreement_gates.sql`, deploy the updated web
and mobile clients, then publish the appropriate approved agreements. Older
clients receive database denials but cannot display the new gate workflow.
Publishing affects access, so the owner publication dialog explains this before
the final publish action. No live agreements are published by these changes.

Validation:

- `node tool/test_module_agreement_gates.mjs`: disposable PostgreSQL checks for
  upgrade preservation, module/audience separation, stale versions, RLS, native
  transition RPC enforcement, staff access, immutable history and alert suppression.
- `flutter test test/views/module_agreement_gate_test.dart`: shared UI gate tests
  at mobile/desktop widths, explicit acceptance, retry, decline, replacement and
  location evaluation denial before acceptance.
- Existing agreement, reporting, geofence, web navigation and notification route
  tests verify integration. Android Kotlin compiles locally. iOS requires a macOS
  build and device checks for background/foreground permission behavior.

## Deployment repair — 2026-10-18

Both module gates displayed retry errors because migration 202610180002 had
not been applied: the live database lacked `module_agreement_status`,
`publish_module_agreement`, and the agreement `module` column. The migration
has now been applied and the REST schema cache refreshed.

Live transactional checks verified owner publication and tenant/guardian
acceptance/unlock for both modules. All diagnostic versions and acceptances
were rolled back. The project still has no published agreement content; the
owner must publish the approved versions through Administration before
participants can accept and enter the modules. This is an intentional empty
state, separate from a failed connection or missing endpoint.

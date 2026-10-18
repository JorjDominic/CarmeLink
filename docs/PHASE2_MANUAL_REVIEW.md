# Phase 2 manual review (before commits)

Run from the original project:

```powershell
cd "C:\Users\ligay\OneDrive\Documents\Capstone\CarmeLink"
flutter run -d chrome -t lib/main_web.dart
```

Use `flutter run` separately for the native mobile entry point. Stop older runs first to avoid reviewing the clone or an old tab. This checklist covers source changes; deployment status must be checked separately.

Review at 320, 360, 390, 768px and desktop. Manual browser/device acceptance remains a separate check from automated tests.

## Suggested change groups and review order

1. **Navigation restoration** — Owner: Dashboard, Tenants, Operations, Curfew, Profile. Caretaker: Dashboard, Tenants, Operations, Profile. Tenant: Home, Payments, Reports, Curfew, Profile. Guardian: Home, Curfew, Notices, Documents, Messages, Profile. Test selection, nested-page back, messages and notifications. The dedicated web portal keeps its existing sidebar/menu; the mobile surface keeps its floating bar.
2. **Rooms and occupancy presentation** — Review vacant, shared, solo, reserved and archived rooms. Compare all counts and rents with existing records. Check room cards, quick preview, Room Details, history, bed indicators, cleaning/inspection links and management actions. Verify Owner-only financial visibility.
3. **Phase 2 operations presentation** — Cleaning schedules, inspections, visitors, curfew requests, conduct and work curfew profiles. Check long names/statuses, empty/error states, dialog scrolling with the keyboard open, and existing buttons. Opening/canceling forms is sufficient for layout review.
4. **Agreement presentation** — Review both Confidentiality and Geofencing agreements. Verify current vs historical versions, audience labels, readable timestamps, accepted vs no-acceptance records, and opening an existing version. With more than six records, check the independent version/account/history pagination, last/next controls and refresh after the list changes. Publishing and acceptance policies are unchanged.
5. **Staff Profile presentation** — Owner and Caretaker identity, contact details and access level; one-column mobile and two-column desktop account details. Verify Settings, move-out/settlement, transfers and departure-notice actions remain accessible. Tenant/Guardian profile content is unchanged.

## Automated validation

Focused suite passed 96 tests covering navigation, rooms, curfew scrolling, agreement presentation and gating, and profile contracts. Navigation tests isolate the existing ListTile paint diagnostic in destination content; this is not a manual browser/device sign-off.

No migrations or backend changes are part of this review. Source commits were authorized separately; automated checks do not imply manual device approval.

## Phase 1 audit

All five Dart files in the Phase 1 ZIP match commit 16cd20d after normalizing line endings. Headers, pagination, sidebar spacing, Profile ordering, Settings copy and the existing regression test are already integrated. Later staff Profile polish is retained. No additional Phase 1 transfer was required.

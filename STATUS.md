# CarmeLink Living Status and Gap Tracker

> **Authoritative project status — October 9, 2026.** Historical progress,
> completion-audit, and Markdown-reconciliation trackers were consolidated here
> to prevent contradictory readiness claims. Repository implementation is not
> equivalent to deployed-backend or physical-device proof.

## October 9, 2026 full-system QA

- See [the full QA report](documentation/FULL_SYSTEM_QA_2026-10-09.md) for
  functionality coverage, repairs, evidence, and remaining release gaps.
- Full Flutter suite: 861 passed; analyzer clean. Web release and Android debug
  builds passed; six native Android checks and 20 Edge-function tests passed.
- Fixed narrow finance/analytics exports, restored deployed boundary editing,
  removed anonymous gate-history access, corrected partial-payment financial
  totals, and kept pending proofs visible after earlier partial payments.
- QA migrations `202610090008` through `202610090010` are deployed. All 121
  migrations are current; existing-record fingerprints and boundary geometry
  were preserved. Earlier deposit, renewal, signed-transfer, and eviction
  migrations through `202610090007` are also installed.
- Report-push dispatcher deployment, PayMongo test credentials, authenticated
  live QA, physical-device verification, Android release signing, and iOS/APNs
  remain open. Passing automation is not production sign-off.
- Source/UI fixes and rebuilt application artifacts are local, not published.

## October 4, 2026 Payments and security-deposit update

- Payments defaults to current bills, prioritizes older unpaid balances, keeps
  verified history behind filters, and collapses future rent into a read-only
  schedule. Payment actions exclude deposits and future rent. Dashboard amount
  due uses the current outstanding balance; future rent is labeled scheduled.
- Tenant and guardian deposits use a separate receipt summary. Owners record
  or correct the received total with a date, method, reference, and audit note
  from Contracts; move-out uses the same confirmed amount automatically.
- Added migration `202610040002_separate_security_deposit_receipts.sql` for
  protected receipt/audit records, legacy receipt reconciliation, rent-only
  contract billing, deposit-payment restrictions, and move-out/refund sync.
  Existing paid/part-paid/pending history is preserved; unpaid contract deposit
  charges are voided with a documented audit action. Unassigned verified
  receipts require explicit owner linking without rewriting ledger facts.
- Validation: full Flutter suite passed (557 tests), plus a later 62-test
  Payments/dashboard/responsive check; changed-source analysis passed. Local
  PostgreSQL smoke checks passed for migration, permissions, legacy preservation,
  receipt correction, auto-fill, deductions, refund sync, and finalized locks.
- Deployment: this source update and its database migration are not yet
  deployed. Apply the migration before releasing the updated mobile/web UI;
  physical/live workflow verification remains required.

## October 4, 2026 device-linking UI update

- Hidden the deferred trusted-device linking UI: removed its Settings tile,
  planned-feature badge, and unused device-binding page across shared mobile
  and web screens. Trusted-device binding remains unimplemented and deferred;
  push-device registration continues to serve notification delivery.
- Updated the existing UI closure regression to expect no device-binding UI.

## September 30, 2026 current-build update

Source baseline: `3d8a2f9` (`Geofencing fix - automatic in and out`).

### Completed in source

- Phase 8 move-out and settlement workflow, service, policy, migration, staff
  workspace integration, tenant/staff discoverability, and contract tests.
- Feedback remains explicitly non-persistent instead of presenting a false
  successful submission.
- Automatic geofencing now treats the property polygon as authoritative;
  official-gate intersection is optional wake-up evidence rather than a
  prerequisite for `IN/OUT`.
- Android and iOS now reconcile stale server presence after monitoring resumes,
  using two consecutive accurate fixes before recording a correction.
- Android recovery starts a bounded native location burst and preserves its
  connectivity-constrained offline uploader. iOS retains region plus
  significant-change monitoring, native queueing, and launch restoration.
- Tenant monitoring status and explanatory UI now match the implemented
  polygon/gate behavior.

### Verification completed

- Focused geofencing/platform/UI suite: 42 tests passed.
- Broader geofencing/UI suite before reconciliation: 46 tests passed.
- Flutter analysis of changed Dart sources: no issues.
- Android native Kotlin compilation: passed with JBR 21.
- Merge review: clean working tree before this work, no unresolved markers,
  relevant merge-contract tests passed; several old merge lines were retained
  as comments rather than active code and remain documented as such.

### Still open before release

- Execute the two-pass physical iPhone matrix documented in
  `GEOFENCING_IMPLEMENTATION.md`: once before Apple Developer Program enrollment
  and again with enrolled signing/TestFlight afterward.
- Execute equivalent Android tests for background, recents swipe, Settings
  Force Stop followed by launch-time recovery, reboot, OEM battery controls,
  offline crossing, and restored connectivity.
- Android cannot execute while the app remains Force Stopped in Settings; the
  implemented recovery begins after the user manually launches it again.
- Confirm iOS relaunch behavior, timing, Background App Refresh dependency,
  wake-region radius, significant-change fallback, APNs, and offline retry on
  multiple physical devices.
- Remote migration parity, role-by-role RLS/RPC/Storage tests, production
  secrets, Android release signing, Apple signing/APNs, monitoring, backups,
  and incident readiness remain production gates.

### Documentation consolidation

The former `DEVELOPMENT_PROGRESS.md`, `SYSTEM_COMPLETION_AUDIT.md`, and
`MD_RECONCILIATION_CHANGELOG.md` were historical snapshots with overlapping and
outdated test totals. Their still-relevant release gaps are maintained here.
The former tripwire plan and mitigation files were consolidated into
`GEOFENCING_IMPLEMENTATION.md`.

> Historical baseline below was reviewed September 27, 2026. The September 30
> update above supersedes its test totals and geofencing conclusions.

## Requested product backlog — September 27, 2026

These items are the next product-policy and UX workstream. Existing partial
implementations must be audited and refined rather than counted complete merely
because a page or service exists.

### UI and operations follow-up — September 28, 2026

- [ ] **Fix duplicated “Bed” text on Profile** — High
  - The profile assignment summary can render a duplicated label such as
    “Bed Bed 1”. Normalize the stored bed label before presentation and ensure
    the UI adds “Bed” exactly once.
  - Acceptance: labels stored as `1`, `Bed 1`, or equivalent legacy values all
    render consistently without duplicated words on tenant, guardian, and staff
    profile surfaces.

- [ ] **Automatically generate cleaning schedules per bed** — High
  - Extend the existing bed-based cleaning module so each eligible/occupied bed
    receives a schedule automatically under one documented rotation rule rather
    than requiring staff to create every assignment manually.
  - Preserve manual review/override, avoid duplicate active schedules, handle
    assignment and occupancy changes, and show who/what generated each schedule.
  - Acceptance: creation, reassignment, vacancy, rotation, override, and
    idempotent regeneration are covered by service/database and UI tests.

- [ ] **Remove the map icon from the room dropdown** — Low
  - Use a neutral room/door icon only where an icon is still helpful. The room
    selector must not imply that choosing a room opens a geographic map.
  - Acceptance: the dropdown remains aligned and accessible on narrow and wide
    layouts, with no map icon in its field or options.

- [ ] **Fix the Cancel Request action** — High
  - Reproduce the failure on the affected request workflow, confirm that only
    cancellable states show an enabled action, persist cancellation through the
    protected backend path, and refresh the screen from authoritative data.
  - Acceptance: confirmation, success, permission denial, invalid state,
    network failure, repeated tap, and post-cancellation UI are tested; no local
    success is shown when the backend rejects the request.

- [ ] **Fix font rendering and joined/overlapping text** — High
  - Audit typography for incorrectly joined words, missing spacing, clipping,
    overlap, fallback glyphs, and inconsistent font weight/line height across
    web and mobile.
  - Acceptance: representative pages pass at supported breakpoints, 1.0–2.0x
    text scale, long names/content, and non-ASCII text without overlap or
    unreadable word joining.

- [ ] **Do not charge tenants a security deposit through Payments** — High
  - Current evidence: tenant calculations exclude `deposit` rows from amount
    due, next due, and overdue totals, but
    `generate_contract_billing_charges` still creates a deposit ledger charge
    during contract activation.
  - Required outcome: contract wording may retain a deposit field if legally
    required, but activation must not create a tenant-payable deposit and no
    payment page or report may ask the tenant to pay it.
  - Define non-destructive handling for existing deposit rows (void, archive,
    or reclassify; never silently delete paid history), then update the RPC,
    views, reports, UI, and activation/balance/legacy-data tests together.

- [ ] **Complete dynamic/responsive UI coverage across web and mobile** — High
  - Adaptive shells and narrow-screen tests exist, but not every route, dialog,
    data state, orientation, and text scale is covered.
  - Audit tenant, guardian, owner, and caretaker pages at 320/375/768/1024/1440
    px with loading/empty/error/long-data states; eliminate overflow, clipped
    actions, fixed-size assumptions, and unreachable navigation.

- [ ] **Improve all curfew experiences** — High
  - Consolidate status, next action, request history, approval stage, filters,
    empty/error states, and relevant gate context across tenant, guardian,
    owner, and caretaker pages.
  - Use plain workflow labels and keep curfew requests visibly distinct from
    live gate/geofence evidence.

- [ ] **Keep contracts visible throughout onboarding** — High
  - Current evidence: tenant draft lookup/generated-document preview, guardian
    read-only documents, and resident/guardian document RLS are implemented.
  - Required outcome: once management generates a contract, the tenant and an
    authorized linked guardian can open the latest version while it is draft,
    unsigned, or pending review. Show version/date/status and an explicit “not
    yet signed/final” label; do not require activation or completed onboarding.
  - Test draft, generated unsigned, tenant-signed pending review, verified,
    replaced version, unlinked guardian, and no-document states.

- [ ] **Implement profile editing backend and persistence** — High
  - Current evidence: `ProfileService` resolves room/link summaries and the
    profile UI mainly displays session/profile values; there is no complete
    self-service update workflow.
  - Define editable fields per role, validation, protected RPC/service, RLS and
    auditing, refresh/error behavior, and tests. Identity, role, and verification
    fields remain staff-controlled.

- [ ] **Improve owner/caretaker Payments UI** — Medium
  - Build on the existing metrics, filters, and responsive work: prioritize
    pending review, clarify charge/payment/adjustment terminology, expose receipt
    and audit context, reduce density, and keep common actions easy to reach.

- [ ] **Simplify Operations and merge overlapping staff pages** — High
  - The staff workspace/operations menu was recently reduced and room list/floor
    plan views are merged, but the remaining catalog is still too broad.
  - Inventory destinations by task; merge only pages sharing data and actions,
    remove duplicate entry points, and use tabs or progressive detail without
    producing one overloaded “everything” page.

- [ ] **Make owner/caretaker navigation intuitive on web and mobile** — High
  - Keep stable primary destinations, consistent labels/icons/order, clear
    current-location state, predictable back behavior, wide-layout breadcrumbs,
    grouped/searchable secondary tools, and role-appropriate quick actions.
  - Validate common end-to-end tasks separately with owner and caretaker roles.

## Current-build delta — September 27, 2026

### Curfew ownership and guardian presence alerts — September 28, 2026

- [x] Overnight leave now requires a linked guardian and the guardian's approve
  or reject action is final. Owners/caretakers retain read access and receive
  request/decision notifications, but the backend rejects staff attempts to
  decide an overnight request. Late-return requests remain staff-reviewed.
- [x] Guardian entry, exit, and outside-after-cutoff preferences are persisted
  through protected RPCs instead of static process memory.
- [x] `notify-geofence` sends linked-guardian FCM/in-app notifications for
  entered/exited events while enforcing each guardian's entry/exit switches.
- [x] `process-guardian-presence-alerts` creates a deduplicated daily alert and
  FCM push when a linked resident remains outside after the selected cutoff.
- [x] User-facing geofence wording now says “dormitory property,” “entered,” and
  “exited”; technical geometry code may still use “perimeter” internally.
- [x] Remote migration
  `202609280001_guardian_curfew_and_presence_preferences.sql` applied on
  September 28, 2026; guardian preference read/write RPCs are available.
- [ ] Deploy both notification functions, set `GUARDIAN_ALERT_CRON_SECRET`, and invoke
  `process-guardian-presence-alerts` every five minutes from the approved
  scheduler. Verify guardian/staff delivery on physical devices.

Changes completed after the earlier Markdown reconciliation:

- [x] Android and iOS native region events now act as wake-up hints. A fresh,
  accurate location is checked against the configured polygon, edge buffer, and
  official gate corridor before an IN/OUT transition is queued.
- [x] The official gate corridor is stored in `dorm_boundary_config`, is editable
  through an authorized RPC, and has versioned device configuration. The active
  corridor was narrowed to the centered 25% of the original Point 1–Point 2
  segment, with a minimum 3 m tolerance, for field testing.
- [x] FCM token registration now uses `register_current_push_device`, which binds
  the token to `auth.uid()` server-side instead of trusting a client-supplied
  user identifier.
- [x] Tenant onboarding received direct/resumable workflow, safety-gate,
  document-submission, electronic-signature, and audited billing-action work.
- [x] iOS tripwire startup now waits for Always authorization and handles location
  and region-monitoring failures as recoverable states.

These checks prove source-level behavior and automated regressions only. They do
not prove that migrations/functions are deployed, that APNs/FCM succeeds on real
devices, or that killed-app geofencing works reliably at the property.

> **Canonical status file.** Update this file when scope or implementation changes.  
> Last ownership update: 2026-09-26
> Owners: assign each open item to one of the three team members before work begins.  
> Detailed reference documents may explain behavior, but this file decides whether a feature is complete, deferred, or blocked.

## How to maintain this file

Every change that adds any of the following must update this tracker before merge:

- a native permission;
- a table, bucket, RPC, trigger, or Edge Function;
- a screen that reads or writes tenant/guardian/staff information;
- a background task, notification recipient, location feature, or external service;
- a new claim in the capstone paper or defense presentation.

Each open item must have:

- **Owner:** team member responsible, or `Unassigned`;
- **Target:** `Demo`, `Defense`, `Production`, or `Capstone 2`;
- **Due:** agreed date or `TBD`;
- **Acceptance:** an observable result or automated check—not “reviewed” or “looks correct.”

Status meanings:

- `[x]` resolved and verified;
- `[ ]` open;
- **Deferred** means deliberately excluded from the current claim, not silently incomplete.

Run the repository guardrails with:

```powershell
powershell -ExecutionPolicy Bypass -File tool/status_guardrails.ps1
```

The script is expected to fail while blocking items remain. A red result is a current gap, not a reason to weaken the check.

## Team ownership split — September 26, 2026

### Reserved for Jorj Dominic

Japle Ligaya must not independently implement or change these workstreams:

- FCM/push delivery, Firebase/APNs, notification delivery secrets, and physical push verification;
- tenant onboarding, contracts, requirements/signers, electronic signatures, activation gates, and contract-generated billing;
- geofencing, native tripwires, boundary geometry, gate-event classification, and employee-curfew integration with gate/geofence evaluation.

Jorj Dominic owns implementation, schema/RPC changes, deployment, physical-device validation, and final review for those three areas. Japle may report a defect in them but should hand it back instead of modifying their state machines.

### Assigned to Japle Ligaya

All remaining open application work is assigned to Japle, including shared UI cleanup, phone actions, feedback, device-binding demo treatment, non-geofence room/visitor/conduct/maintenance/retention work, CI scripts, Android release packaging, realtime verification, and operational-readiness documentation. Cross-cutting security or migration tests must explicitly exclude the three reserved areas or be coordinated with Jorj.

## UI improvement workstream — assigned to Japle Ligaya

These are presentation and navigation changes only. They must preserve the
existing Supabase records, role rules, status transitions, and audit history.
They must not change FCM, tenant onboarding/contracts, or geofencing.

### Tenant UI

- [ ] **UI-1: Put payment filters on one line**
  - Owner: Japle Ligaya
  - File: `lib/views/tenant/tenant_pages.dart` (`PaymentsPage`)
  - Change: Present All, Due, Pending, and Verified in one horizontally
    scrollable filter row instead of allowing the chips to wrap. Keep the sort
    control visually separate but in the same compact toolbar when width allows.
  - Acceptance: selected states and counts remain correct; the row does not
    overflow at 320 px width or 1.35x text scale; changing a filter still shows
    the correct records.

- [ ] **UI-2: Paginate the tenant payment records**
  - Owner: Japle Ligaya
  - File: `lib/views/tenant/tenant_pages.dart` (`PaymentsPage`)
  - Change: Initially render at most 10 matching records and provide an explicit
    `Load more` action for the next page. Reset to page 1 whenever filter or sort
    changes. Show the visible/total count and a clear end-of-list state.
  - Decision: use `Load more`, not automatic infinite scrolling. It is easier to
    understand, test, and use on mobile while preventing an unbounded card list.
  - Acceptance: no duplicate/skipped records; loading and empty states are
    distinct; all records remain reachable; payment actions still refresh the
    list without losing the selected filter.

- [ ] **UI-3: Standardize the three tenant report workflows**
  - Owner: Japle Ligaya
  - Files: `lib/views/tenant/tenant_pages.dart` (`TenantReportsHubPage`,
    `MaintenanceReportsPage`, `ConfidentialConcernPage`, and missed cleaning
    duty flow)
  - Change: Give Maintenance, Confidential Concern, and Missed Cleaning Duty the
    same card hierarchy: short purpose, privacy/audience note, primary action,
    status/history summary, and consistent empty/error/loading states. Remove
    duplicate entry cards and dead navigation, but keep all three record types
    and their permissions separate.
  - Acceptance: a tenant can identify which report to use, submit it, return to
    the hub, and see the resulting status/history; confidential information is
    not exposed in the other report pages; narrow-screen widget tests pass.

### Owner UI

- [ ] **UI-4: Reduce and merge Operations management areas**
  - Owner: Japle Ligaya
  - Files: `lib/views/owner/owner_pages.dart` (`OperationsHubPage`, categories,
    and `OperationsCategoryPage`) and `lib/views/owner/owner_shell.dart`
  - Change: Replace the long list of overlapping management areas with these
    grouped destinations: Residents; Rooms & Facilities; Billing & Payments;
    Reports & Cases; Access & Visitors; Communication. Existing focused pages
    remain reachable inside their group.
  - Boundary: navigation may point to onboarding/contracts or geofence screens,
    but Japle must not alter those reserved workflows.
  - Acceptance: no existing non-reserved workflow becomes unreachable; duplicate
    top-level shortcuts are removed; back navigation returns to the correct
    group; role guards are unchanged.

- [ ] **UI-5: Remove the dedicated Floor Plan destination**
  - Owner: Japle Ligaya
  - Files: `lib/views/owner/owner_pages.dart`,
    `lib/views/owner/room_monitoring_page.dart`, and
    `lib/views/owner/floor_plan_page.dart`
  - Change: Remove Floor Plan as its own management-area shortcut. Keep the
    interactive floor-plan map available from Room Monitoring under Rooms &
    Facilities. Do not delete room/floor data, map components, or maintenance
    location selection that reuse the floor plan.
  - Acceptance: there is one owner entry path for room monitoring/floor plan;
    full-screen map access still works from Room Monitoring; no orphan route or
    duplicate navigation label remains.

- [ ] **UI-6: Show the four Operations summary cards in one row**
  - Owner: Japle Ligaya
  - File: `lib/views/owner/owner_pages.dart` (`OperationsHubPage`)
  - Change: Present the four status containers as a single horizontal row. On a
    narrow device, keep one row through horizontal scrolling rather than
    shrinking text or returning to a 2×2 grid.
  - Acceptance: all four values are visible/reachable in one row, cards have
    consistent height, and there is no overflow at 320 px or enlarged text.

### UI workstream completion check

Before checking these items off, run `flutter analyze`, the focused tenant and
owner widget tests, and the full `flutter test` suite. Record screenshots at a
320 px phone width and a wide owner layout. UI completion does not prove remote
backend deployment; workflow verification remains tracked separately below.

## Written scope decision

### Capstone 1 — current defensible scope

CarmeLink Capstone 1 is a role-based dormitory management prototype covering authentication, resident/guardian/staff records, rooms and bed assignments, contracts and onboarding, billing and payment proof, maintenance, visitors, ordinary curfew requests, gate-event history, messaging, announcements, cleaning schedules, room inspections, conduct cases/appeals, and operational reports.

For geofencing, Capstone 1 may claim:

- foreground device location can be evaluated against the configured boundary;
- gate events are minimized to IN/OUT/UNAVAILABLE without storing raw coordinates;
- Android and iOS contain native circular tripwire prototypes;
- staff can enter explicitly identified manual observations.

Capstone 1 must **not** claim production-grade hybrid polygon tripwire enforcement until the polygon/circle mismatch is resolved and physically tested.

### Capstone 2 / explicitly deferred

- production-grade polygon-confirmed background geofencing on both platforms;
- employee-curfew profiles automatically changing gate classification;
- cryptographic/trusted-device binding and replacement workflow;
- automated retention deletion/anonymization;
- production incident monitoring, backup/restore operations, and load validation;
- any advanced analytics not already derived from operational records.

If the team chooses to implement one of these in Capstone 1, move it into the current scope and satisfy its acceptance criteria before making the claim.

## Current verification baseline

| Check | Last result | Date |
|---|---|---|
| Flutter analysis of changed Dart sources | Pass — no issues | 2026-09-30 |
| Focused geofence/platform/UI tests | Pass — 42 tests | 2026-09-30 |
| Android Kotlin compilation | Pass — `:app:compileDebugKotlin` | 2026-09-30 |
| Remote migration parity | Not verified | — |
| Remote role/RLS matrix | Not verified | — |
| Android physical-device suite | Not verified | — |
| iOS production build/device suite | Not verified | — |

## Resolved findings

### Japle merged-work reconciliation — September 27, 2026

The items below were rechecked against current `main` source, migrations, tests,
and Git history after earlier Japle commits were merged before every planning
file was updated. `[x]` here means the implementation is present in the
repository; remote/staging/security verification remains tracked separately
under **Must verify before production data** where applicable.

- [x] **Tenant maintenance CRUD and maintenance-photo workflow implemented**
  - Owner: Japle Ligaya
  - Evidence: `lib/services/maintenance_service.dart`, tenant maintenance pages,
    `20260909181703_tenant_maintenance_crud.sql`,
    `20260909195825_maintenance_photo_upload.sql`, and focused maintenance tests.
  - Remaining: live RLS/media-path verification is still open below.

- [x] **Visitor request, staff review/history, and confirmed scheduling policy implemented**
  - Owner: Japle Ligaya
  - Evidence: visitor service/UI, `VisitorPolicy`, visitor migrations, and server
    enforcement requiring at least one calendar day of lead time, the
    9:00 AM–9:00 PM window, same-day departure, approval, and arrival/departure
    logging.
  - Remaining: remote smoke/RLS verification and any separately approved visitor-ID
    requirement remain open.

- [x] **Room cleaning schedules and private missed-duty reporting implemented**
  - Owner: Japle Ligaya
  - Evidence: room-cleaning service/pages, policy tests, and
    `20260924050000_phase3a_room_cleaning.sql`.
  - Remaining: staging/RLS verification and any later-approved shared-area duty
    expansion remain separate.

- [x] **Monthly/follow-up room inspection workflow implemented**
  - Owner: Japle Ligaya
  - Evidence: room-inspection service/pages, policy tests, and
    `20260924060000_phase3b_room_inspections.sql` covering three-day written
    notice, findings, evidence, corrective actions, and follow-up inspections.
  - Remaining: move-in snapshots and move-out/final-inspection lifecycle work are
    separate scope items.

- [x] **Conduct cases, evidence, responses, warnings, history, and appeals implemented**
  - Owner: Japle Ligaya
  - Evidence: conduct services/pages plus `20260924070000_phase4a_conduct_cases.sql`
    and `20260924090000_phase4c_conduct_case_appeals.sql`.
  - Boundary: cases do not auto-create charges or auto-terminate tenancy.

- [x] **Retention settings/configuration implemented as non-destructive configuration**
  - Owner: Japle Ligaya
  - Evidence: retention settings page/service, policy tests, and
    `20260924100000_phase5a_retention_settings.sql`.
  - Boundary: automated deletion/anonymization remains deliberately disabled and
    stays open/deferred below.

- [x] **Tenant My Room and Guardian linked-tenant room/payment views use live records**
  - Owner: Japle Ligaya / shared application work
  - Evidence: `MyRoomPage`, `GuardianTenantInfoPage`, `GuardianPaymentStatusPage`,
    `RoomService`, and `GuardianService`, including no-assignment/no-link empty
    states.
  - Remaining: production relationship-isolation/RLS verification is still open.

- [x] **Tenant payment-proof upload with on-device OCR is integrated**
  - Owner: Japle Ligaya / shared application work
  - Evidence: `PaymentService`, `ReceiptOcrService`, Tenant payment-proof UI, and
    receipt OCR/payment widget tests. OCR values remain user-verifiable and are
    not treated as authoritative payment approval.

- [x] **Announcements, role-scoped messaging, reports/PDF infrastructure, and public/staff web source are implemented**
  - Owner: Japle Ligaya for non-reserved UI/application work
  - Evidence: announcement service/pages, messaging service/controller/pages,
    `DormitoryReportService`, report/analytics pages, and web/staff source/tests.
  - Remaining: push delivery, production session/deployment proof, Realtime/RLS,
    and financial reconciliation remain tracked separately.

- [x] **Production `MockData` dependency removed**
  - Owner: Japle Ligaya / cleanup work
  - Evidence: production mock-data module was removed and repository guardrails
    reject `MockData` dependencies in owned production pages.

- [x] **In-app touchscreen electronic lease signature and tenant live document status rows**
  - Owner: Jorj Dominic
  - Target: Defense / Demo
  - Completed: 2026-09-26
  - Result: Implemented in-app touch signature pad dialog (`SignaturePadDialog`) enabling tenants to sign their lease directly on phone with finger or stylus, exporting PNG bytes, and submitting to Supabase via `submit_tenant_electronic_signature` RPC and private storage. Document requirements (Tenant Valid ID, Parent/Guardian ID, Signed Lease Copy, On-Screen Signature) are rendered as individual, live color-coded status rows on both the Tenant Profile tab (`_TenantRequiredDocumentsSection`) and the Home Dashboard onboarding banner (`_TenantOnboardingBanner`). Completed post-onboarding screen (`_SuccessView`) directs tenants straight into document verification and e-signing.
  - Regression check: `signature_pad_dialog_test.dart` and full 421-test suite pass.

- [x] **Dormitory boundary configuration RPC implemented**
  - Owner: Jorj Dominic
  - Target: Demo and Defense
  - Completed: 2026-09-26
  - Result: Implemented `update_dorm_boundary_config` RPC in `supabase/migrations/202609250002_boundary_config_editable.sql` with owner/staff security definer authorization, coordinate bounds checking, and JSON polygon parsing.
  - Regression check: `tool/status_guardrails.ps1` boundary check passes.

- [x] **Onboarding safety gates and guardian-less curfew routing aligned**
  - Owner: Completed during workflow review
  - Target: Defense / Production
  - Completed: 2026-09-26
  - Result: Contract activation now requires complete emergency-contact name,
    phone, and relationship in both UI and database enforcement. Overnight leave
    requests use guardian-first review when a guardian is linked and otherwise
    route directly to mandatory staff review instead of stalling.
  - Regression check: `onboarding_safety_contract_test.dart` verifies the RPC,
    direct-insert revocation, activation guard, form validation, and cross-account
    QR recovery message.

- [x] **Application-usage tracking removed**
  - Owner: Completed during audit
  - Target: Demo / Defense / Production
  - Completed: 2026-09-25
  - Result: Deleted Flutter service, guardian UI, Android native channel, Android `PACKAGE_USAGE_STATS` permission, and related documentation claims.
  - Regression check: `status_guardrails.ps1` rejects usage-tracking symbols and permission strings.

- [x] **Unreachable mobile mock-data module removed**
  - Owner: Completed during audit
  - Target: Demo
  - Completed: 2026-09-25
  - Result: Deleted `lib/data/mock_data.dart`; production screens use services/controllers or explicit test injection.
  - Regression check: existing Phase 5B contract test and readiness script reject `MockData` dependencies in owned production pages.

- [x] **Unsafe scratch database script removed**
  - Owner: Completed during audit
  - Target: Production hygiene
  - Completed: 2026-09-25
  - Result: Removed tracked scratch script containing test credentials and live insert behavior.

- [x] **Unused poster assets and eager photo preloading removed**
  - Owner: Completed during audit
  - Target: Performance
  - Completed: 2026-09-25
  - Result: Removed two unreferenced poster images and changed startup to pre-cache only the logo.

## Recorded client decisions

- [x] **Rent follows the contract date**
  - Owner: Client / project team
  - Target: Defense / Production
  - Decided: 2026-09-26
  - Decision: Rent follows the signed contract schedule and is not delayed to a
    later physical move-in date. Occupancy metrics continue to use active room
    assignments rather than contracts.

- [x] **Official lease identifies the room, not the bed**
  - Owner: Client / project team
  - Target: Defense
  - Decided: 2026-09-26
  - Decision: A room assignment is required before generating the official
    lease. The PDF prints the room number and deliberately omits the bed label.

## Must fix before live demo

- [ ] **Task 1 (Assigned to Japle Ligaya): Connect header notification button to live NotificationsPage**
  - Owner: Japle Ligaya
  - Target: Demo and Presentation
  - Priority: High (Blocking `status_guardrails.ps1`)
  - File: `lib/core/widgets/common_widgets.dart` (around lines 646–648 and lines 861–920)
  - Issue: The shared header's `openNotifications()` routes to `_GlobalNotificationsPage`, which is hardcoded empty and states notifications are not connected, even though the full, live `NotificationsPage` exists in `lib/views/shared/notifications_page.dart`.
  - Action steps:
    1. In `lib/core/widgets/common_widgets.dart`, update `openNotifications()` to navigate to `NotificationsPage` (import `../../views/shared/notifications_page.dart`).
    2. Remove the obsolete `class _GlobalNotificationsPage` definition.
  - Acceptance: Tapping the notification bell in any shared header opens the live `NotificationsPage`; running `powershell -ExecutionPolicy Bypass -File tool/status_guardrails.ps1` passes the obsolete notification check with zero errors.

- [ ] **Task 2 (Assigned to Japle Ligaya): Wire emergency directory and tenant phone rows to phone dialer**
  - Owner: Japle Ligaya
  - Target: Demo
  - Priority: Medium
  - Files: `lib/views/owner/owner_pages.dart` (lines 729–733 and 815–818), `lib/views/shared/shared_views.dart`
  - Issue: Tapping tenant/guardian phone rows or the call button currently does not launch the dialer, or shows a placeholder.
  - Action steps:
    1. Import `package:url_launcher/url_launcher.dart`.
    2. Add an `onTap` or phone icon action calling `launchUrl(Uri.parse('tel:$cleanPhone'))` with error handling (`showAppSnackBar(context, 'Could not open phone dialer')` or clipboard copy fallback).
  - Acceptance: Tapping a phone number or Call button on a real phone opens the phone dialer with the number prefilled.

- [ ] **Task 3 (Assigned to Japle Ligaya): Clarify or hide nonfunctional Device Binding in Settings**
  - Owner: Japle Ligaya
  - Target: Demo and Defense
  - Priority: Medium
  - Files: `lib/views/shared/shared_views.dart` (around line 1255–1268 and line 1985–2007)
  - Issue: Settings displays "Device binding" with a "Bind trusted device" button that only triggers a snackbar stating native location and token services are not connected yet.
  - Action steps:
    1. Either badge the tile as `Capstone 2 (Planned)` with disabled action, or hide the tile from the tenant settings menu during Capstone 1.
    2. Ensure evaluators do not encounter dead-end buttons during the demo.
  - Acceptance: No broken or nonfunctional "Bind trusted device" action can be triggered during the demo.

- [ ] **Task 4 (Assigned to Japle Ligaya): Feedback form persistence or demo labeling**
  - Owner: Japle Ligaya
  - Target: Demo
  - Priority: Low
  - File: `lib/views/shared/shared_views.dart` (`FeedbackPage`, around line 1390)
  - Issue: Feedback submission collects UI fields but does not persist them to Supabase.
  - Action steps:
    1. Either add a simple `app_feedback` table insertion via Supabase client, or update the confirmation dialog/snackbar to explicitly state: "Thank you! Your feedback has been recorded for review."
  - Acceptance: Evaluators can submit feedback without encountering any crash or unexplained state.

- [ ] **Task 5 (Assigned to Japle Ligaya): Update branch check in `tool/phase5b_integration_readiness.ps1`**
  - Owner: Japle Ligaya
  - Target: Integration / CI
  - Priority: Medium
  - File: `tool/phase5b_integration_readiness.ps1` (lines 27–29)
  - Issue: Script currently checks `if ($branch -ne "japel")` and fails on `main`. Since `japel` has been merged into `main` via PR #5, running the readiness script on `main` throws an exit error.
  - Action steps:
    1. Update the check to allow both `main` and `japel` (`if ($branch -ne "japel" -and $branch -ne "main")`).
  - Acceptance: Running `powershell -ExecutionPolicy Bypass -File tool/phase5b_integration_readiness.ps1` succeeds when executed on the `main` branch.

- [ ] **Task 6 (Assigned to Jorj Dominic): Staging deployment & physical-device push verification**
  - Owner: Jorj Dominic
  - Target: Demo and Production
  - Priority: High
  - Action steps:
    1. Ensure all Supabase migrations (including `202609250002_boundary_config_editable.sql` and `202609260005_tenant_electronic_signature.sql`) are applied to the remote staging project.
    2. Deploy Supabase Edge Functions (`notify-message`, `notify-geofence`, `notifyNewAnnouncement`).
    3. Test push delivery, notification center sync, and receipt on physical Android phone (`Infinix X6731`).
  - Acceptance: Zero unhandled RPC errors in staging; push notifications appear in the notification drawer on device.

## Must resolve for defense claims

- [x] **Native polygon and gate-corridor confirmation implemented in source**
  - Owner: Jorj Dominic
  - Target: Defense
  - Due: TBD
  - Current state: Implemented on Android and iOS. Native circles wake the app;
    current location, polygon/edge-buffer state, direction change, and movement
    through the configured gate corridor determine whether an event is queued.
  - Remaining verification: physical tests must still cover polygon corners,
    edges, false wakeups, killed app, offline sync, sparse fixes, and both gate
    directions before this is described as production-proven.

- [ ] **Simulation is stored as a staff manual log**
  - Owner: Jorj Dominic
  - Target: Defense / data integrity
  - Due: TBD
  - Current state: Owner diagnostic “Simulate Crossing” creates a real manual gate event with simulation text in notes.
  - Decision: Remove from non-development builds, add a distinct test-only record type excluded from operational history, or prohibit use against production.
  - Acceptance: Production builds cannot create simulated operational events, and staging/test events are unambiguously separated from real history.

- [ ] **Employee-curfew profiles do not affect gate classification**
  - Owner: Jorj Dominic
  - Target: Defense wording; Capstone 2 implementation
  - Due: TBD
  - Current state: Profiles can be created/approved/viewed but the gate evaluator remains unchanged.
  - Acceptance for Capstone 1: paper/UI explicitly state “record/display only”; no claim says it prevents flags. Acceptance for implementation: server classification resolves an effective profile and has time/day/expiry/revocation tests.

- [ ] **Retention does not delete or anonymize records**
  - Owner: Japle Ligaya
  - Target: Defense wording; Capstone 2 implementation
  - Due: TBD
  - Current state: Settings and audit exist; enforcement is database-constrained to false and no cleanup job exists.
  - Acceptance for Capstone 1: ethics/paper describes proposed configuration only and automated disposal as future work. Acceptance for implementation: approved policy, dry run, scoped executor, audit, recovery strategy, and staging proof.

- [ ] **Guardian personal alert is not scheduled or persisted**
  - Owner: Japle Ligaya
  - Target: Defense wording
  - Due: TBD
  - Current state: Alert time is static process memory and resets on restart.
  - Acceptance: Describe it as an informational local preference only, or implement persistent preference plus scheduled notification and deduplication.

- [ ] **Contract PDF font lacks full Unicode support**
  - Owner: Jorj Dominic (tenant onboarding/contracts reserved scope)
  - Target: Defense quality / Production
  - Due: TBD
  - Current state: Tests pass but PDF package warns that Helvetica/Helvetica-Bold lack Unicode support.
  - Acceptance: Embed a licensed Unicode font and test names/addresses containing representative non-ASCII characters.

## Must verify before production data

- [ ] **Remote migrations match repository**
  - Owner: Japle Ligaya for non-reserved migrations; Jorj Dominic for FCM, onboarding/contracts, and geofencing migrations
  - Target: Production
  - Due: TBD
  - Acceptance: `supabase migration list` shows every required version synchronized; clean staging deployment succeeds; dry run reports no unexpected migrations.

- [ ] **Role/RLS/Storage negative-access matrix**
  - Owner: Japle Ligaya for non-reserved modules; Jorj Dominic reviews reserved-module coverage
  - Target: Production
  - Due: TBD
  - Acceptance: Automated tenant, guardian, caretaker, owner, and anonymous tests cover every business table, RPC, Edge Function, and private bucket; unauthorized reads/writes return no data or explicit denial.

- [ ] **Realtime publication and authorization**
  - Owner: Japle Ligaya
  - Target: Production
  - Due: TBD
  - Acceptance: Gate, message, conversation, and notification changes arrive for authorized users and never arrive for unauthorized users.

- [ ] **Edge Function secrets and exposure**
  - Owner: Jorj Dominic (FCM/secrets reserved scope)
  - Target: Production
  - Due: TBD
  - Acceptance: FCM/Cloudinary/Supabase secrets are present server-side, absent from clients/logs, rotated/documented, and `provision-test-users` is disabled or strongly restricted.

- [ ] **Android release configuration**
  - Owner: Japle Ligaya (release packaging only; FCM/geofence validation remains with Jorj)
  - Target: Production
  - Due: TBD
  - Current state: Release build uses debug signing.
  - Acceptance: Signed release/AAB uses protected production keystore, correct application ID/versioning, and installs/upgrades on a physical device.

- [ ] **iOS Firebase, APNs, signing, and background delivery**
  - Owner: Jorj Dominic (FCM/geofencing reserved scope)
  - Target: Production
  - Due: TBD
  - Current state: `GoogleService-Info.plist` and committed team configuration are absent; APNs entitlement says development; queued native geofence events rely on Flutter resuming.
  - Acceptance: Signed production/TestFlight build registers APNs/FCM, receives foreground/background/tap pushes, and has a documented/tested geofence delivery guarantee.

- [ ] **Secure native token storage**
  - Owner: Jorj Dominic (native geofence credential path)
  - Target: Production
  - Due: TBD
  - Current state: Android background worker stores Supabase access/refresh tokens in ordinary `SharedPreferences`.
  - Acceptance: Tokens use platform-protected storage or a safer scoped server design; logout/account switch removes credentials and queued cross-user events.

- [ ] **Physical geofence test matrix**
  - Owner: Jorj Dominic
  - Target: Production
  - Due: TBD
  - Acceptance: Android and iOS evidence covers enter/exit, boundary edge, permissions denied/revoked, GPS off, mock location, killed app, reboot, offline transition, token expiry, retry/deduplication, and battery restrictions.

- [ ] **Operational readiness**
  - Owner: Japle Ligaya
  - Target: Production
  - Due: TBD
  - Acceptance: Crash reporting, backend alerts, backups, restore drill, incident contacts, audit review, staging/production separation, and rollback/runbook exist and have named owners.

## Automated acceptance commands

Local non-destructive checks:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
powershell -ExecutionPolicy Bypass -File tool/status_guardrails.ps1
powershell -ExecutionPolicy Bypass -File tool/phase5b_integration_readiness.ps1 -SkipSupabase
```

Staging-only checks requiring explicit credentials and permission to create temporary records:

```powershell
powershell -ExecutionPolicy Bypass -File tool/contract_remote_smoke_test.ps1 `
  -ProjectUrl $env:CARMELINK_STAGING_URL `
  -PublishableKey $env:CARMELINK_STAGING_KEY `
  -TestPassword $env:CARMELINK_TEST_PASSWORD

powershell -ExecutionPolicy Bypass -File tool/visitor_remote_smoke_test.ps1 `
  -ProjectUrl $env:CARMELINK_STAGING_URL `
  -PublishableKey $env:CARMELINK_STAGING_KEY `
  -TestPassword $env:CARMELINK_TEST_PASSWORD
```

Do not run record-creating smoke tests against production.

## Team change log

Add one row before merging a scope-sensitive change.

| Date | Owner | Change | Data/permission impact | Tests/evidence | Status items updated |
|---|---|---|---|---|---|
| 2026-09-25 | Audit | Removed app-usage tracking | Removed Android special permission and local behavioral data access | Analyze, 381 tests, Android debug build | Usage tracking resolved |
| 2026-09-25 | Audit | Removed unreachable mock/scratch code and unused assets | Removed hardcoded scratch credential path; reduced bundle/startup image work | Analyze, tests, Android debug build | Cleanup resolved |
| 2026-09-25 | Audit | Completed core FCM module hooks and repaired post-merge UI tests | Added authorized recipient fan-out for core notification events; no new permission | Analyze and 410 tests | FCM/live-verification and documentation items updated |

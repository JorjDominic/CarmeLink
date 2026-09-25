# CarmeLink Living Status and Gap Tracker

> **Canonical status file.** Update this file when scope or implementation changes.  
> Last audited: 2026-09-25  
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
| `flutter analyze` | Pass — no issues | 2026-09-25 |
| `flutter test` | Pass — 410 tests | 2026-09-25 |
| `flutter build apk --debug` | Pass | 2026-09-25 |
| Remote migration parity | Not verified | — |
| Remote role/RLS matrix | Not verified | — |
| Android physical-device suite | Not verified | — |
| iOS production build/device suite | Not verified | — |

## Resolved findings

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

## Must fix before live demo

- [ ] **Android FCM implementation completed; staging delivery still needs proof**
  - Owner: Backend/mobile team
  - Target: Demo and Production
  - Due: TBD
  - Client state: Android Firebase file matches `com.carmelita.carmelink`; notification permission, channel, icon, token registration/refresh/revocation, foreground display, background handler, and tap routing are implemented.
  - Repository state (2026-09-25): The dispatcher supports role, multiple-user, tenant, and linked-guardian targets with caller authorization; current staff roles are used; announcement and feature lifecycle hooks are connected; and Android WorkManager invokes `notify-geofence` after recording a native background transition.
  - Covered event families: messages, announcements, gate/geofence, payments, utility bills, maintenance, visitors, curfew, conduct publication/appeals, and inspection completion.
  - Not yet covered comprehensively: confidential reports, contract/onboarding review, cleaning, inspection scheduling/findings, employee-curfew profile changes, guardian-link changes, room/residency changes, and contract-expiry reminders.
  - Remaining risk: Edge Functions and FCM secrets have not been deployed and exercised on physical devices in this audit, so production delivery is not yet proven.
  - Acceptance: Deploy corrected functions; register two physical Android devices; verify token rows; test foreground/background/terminated delivery and tap routing for message, gate, payment, maintenance, visitor, curfew, conduct, inspection, utility, and announcement events; confirm `push_sent_at` and zero unexpected `push_error` values.

- [ ] **Broken boundary editor**
  - Owner: Unassigned
  - Target: Demo and Defense
  - Due: TBD
  - Current state: Owner UI calls `update_dorm_boundary_config`, but `202609250002_boundary_config_editable.sql` is empty and no repository migration defines the RPC.
  - Decision: Either implement a role-authorized, validated RPC migration or remove/hide boundary editing and document the boundary as deployment-managed.
  - Acceptance: A clean local/staging migration creates the RPC and an owner can save/reload the boundary while tenant/guardian/anonymous calls fail; **or** no production route/call references the RPC.

- [ ] **Header notification button opens obsolete empty page**
  - Owner: Unassigned
  - Target: Demo
  - Due: TBD
  - Current state: Shared header opens `_GlobalNotificationsPage`, which always says notifications are disconnected, while the real `NotificationsPage` exists.
  - Acceptance: Every notification entry point opens the live notification list; no `_GlobalNotificationsPage` remains; widget test taps the header and finds live notification-page content.

- [ ] **Announcement push is implemented but needs staging verification**
  - Owner: Backend/mobile team
  - Target: Demo if push is demonstrated; otherwise Defense wording
  - Due: TBD
  - Current state: Announcement creation dispatches through `AppNotificationService.notifyNewAnnouncement` and records `fcm_sent` only after the Edge Function accepts the request.
  - Acceptance: Staging creation produces the intended recipient notification rows and device push for tenant, guardian, and all-resident audiences.

- [ ] **Device Binding button is nonfunctional**
  - Owner: Unassigned
  - Target: Demo
  - Due: TBD
  - Current state: Button displays a snackbar and creates no device binding.
  - Decision: Hide/remove from the demo build and defer to Capstone 2, unless the team explicitly brings it into scope.
  - Acceptance: No visible actionable Bind button remains in Capstone 1, or a complete bind/revoke/replace/audit workflow passes tests.

- [ ] **Feedback submission is UI-only**
  - Owner: Unassigned
  - Target: Demo
  - Due: TBD
  - Current state: Form does not create a durable record or external ticket.
  - Decision: Hide/remove the submission feature, label it explicitly as unavailable, or implement persistence.
  - Acceptance: The action creates a retrievable authorized record/ticket, or no enabled submission action is presented.

- [ ] **Emergency contact Call button is a placeholder**
  - Owner: Unassigned
  - Target: Demo
  - Due: TBD
  - Current state: Tapping Call shows a snackbar instead of opening the dialer.
  - Acceptance: Valid numbers launch a `tel:` action with failure handling, or the Call action is removed.

- [ ] **Remove stale mock/simulation statements from current documentation**
  - Owner: Unassigned
  - Target: Demo and Defense
  - Due: TBD
  - Current state: README and progress history contain statements that contradict currently live modules.
  - Acceptance: README current-state section matches code; historical notes are clearly labeled historical; `STATUS.md` is linked as the canonical current status.

## Must resolve for defense claims

- [ ] **Native circle bypasses polygon semantics**
  - Owner: Unassigned
  - Target: Defense
  - Due: TBD
  - Current state: Foreground checks support polygon geometry, but Android/iOS native monitors use a circle and directly queue IN/OUT. Android expands the native radius to at least 100 m.
  - Decision: Implement coordinate-aware polygon confirmation before recording native events, standardize the official model as circular, or explicitly present native polygon confirmation as Capstone 2.
  - Acceptance for a “hybrid polygon” claim: native-triggered records are confirmed against the same polygon/edge-buffer rules and physical tests cover polygon corners, edges, false wakeups, killed app, and offline sync.

- [ ] **Simulation is stored as a staff manual log**
  - Owner: Unassigned
  - Target: Defense / data integrity
  - Due: TBD
  - Current state: Owner diagnostic “Simulate Crossing” creates a real manual gate event with simulation text in notes.
  - Decision: Remove from non-development builds, add a distinct test-only record type excluded from operational history, or prohibit use against production.
  - Acceptance: Production builds cannot create simulated operational events, and staging/test events are unambiguously separated from real history.

- [ ] **Employee-curfew profiles do not affect gate classification**
  - Owner: Unassigned
  - Target: Defense wording; Capstone 2 implementation
  - Due: TBD
  - Current state: Profiles can be created/approved/viewed but the gate evaluator remains unchanged.
  - Acceptance for Capstone 1: paper/UI explicitly state “record/display only”; no claim says it prevents flags. Acceptance for implementation: server classification resolves an effective profile and has time/day/expiry/revocation tests.

- [ ] **Retention does not delete or anonymize records**
  - Owner: Unassigned
  - Target: Defense wording; Capstone 2 implementation
  - Due: TBD
  - Current state: Settings and audit exist; enforcement is database-constrained to false and no cleanup job exists.
  - Acceptance for Capstone 1: ethics/paper describes proposed configuration only and automated disposal as future work. Acceptance for implementation: approved policy, dry run, scoped executor, audit, recovery strategy, and staging proof.

- [ ] **Guardian personal alert is not scheduled or persisted**
  - Owner: Unassigned
  - Target: Defense wording
  - Due: TBD
  - Current state: Alert time is static process memory and resets on restart.
  - Acceptance: Describe it as an informational local preference only, or implement persistent preference plus scheduled notification and deduplication.

- [ ] **Contract PDF font lacks full Unicode support**
  - Owner: Unassigned
  - Target: Defense quality / Production
  - Due: TBD
  - Current state: Tests pass but PDF package warns that Helvetica/Helvetica-Bold lack Unicode support.
  - Acceptance: Embed a licensed Unicode font and test names/addresses containing representative non-ASCII characters.

## Must verify before production data

- [ ] **Remote migrations match repository**
  - Owner: Unassigned
  - Target: Production
  - Due: TBD
  - Acceptance: `supabase migration list` shows every required version synchronized; clean staging deployment succeeds; dry run reports no unexpected migrations.

- [ ] **Role/RLS/Storage negative-access matrix**
  - Owner: Unassigned
  - Target: Production
  - Due: TBD
  - Acceptance: Automated tenant, guardian, caretaker, owner, and anonymous tests cover every business table, RPC, Edge Function, and private bucket; unauthorized reads/writes return no data or explicit denial.

- [ ] **Realtime publication and authorization**
  - Owner: Unassigned
  - Target: Production
  - Due: TBD
  - Acceptance: Gate, message, conversation, and notification changes arrive for authorized users and never arrive for unauthorized users.

- [ ] **Edge Function secrets and exposure**
  - Owner: Unassigned
  - Target: Production
  - Due: TBD
  - Acceptance: FCM/Cloudinary/Supabase secrets are present server-side, absent from clients/logs, rotated/documented, and `provision-test-users` is disabled or strongly restricted.

- [ ] **Android release configuration**
  - Owner: Unassigned
  - Target: Production
  - Due: TBD
  - Current state: Release build uses debug signing.
  - Acceptance: Signed release/AAB uses protected production keystore, correct application ID/versioning, and installs/upgrades on a physical device.

- [ ] **iOS Firebase, APNs, signing, and background delivery**
  - Owner: Unassigned
  - Target: Production
  - Due: TBD
  - Current state: `GoogleService-Info.plist` and committed team configuration are absent; APNs entitlement says development; queued native geofence events rely on Flutter resuming.
  - Acceptance: Signed production/TestFlight build registers APNs/FCM, receives foreground/background/tap pushes, and has a documented/tested geofence delivery guarantee.

- [ ] **Secure native token storage**
  - Owner: Unassigned
  - Target: Production
  - Due: TBD
  - Current state: Android background worker stores Supabase access/refresh tokens in ordinary `SharedPreferences`.
  - Acceptance: Tokens use platform-protected storage or a safer scoped server design; logout/account switch removes credentials and queued cross-user events.

- [ ] **Physical geofence test matrix**
  - Owner: Unassigned
  - Target: Production
  - Due: TBD
  - Acceptance: Android and iOS evidence covers enter/exit, boundary edge, permissions denied/revoked, GPS off, mock location, killed app, reboot, offline transition, token expiry, retry/deduplication, and battery restrictions.

- [ ] **Operational readiness**
  - Owner: Unassigned
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

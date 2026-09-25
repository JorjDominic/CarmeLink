# CarmeLink Development Progress

Last updated: September 25, 2026

This file tracks development separately from the README. Page ownership is
divided between two developers to reduce merge conflicts.

## Current production-readiness assessment

Current estimates are **92% functional prototype**, **76% demo/staging
deployability**, **58% Android production readiness**, and **42% full
Android+iOS production readiness**. These estimates distinguish locally passing
code from remote deployment proof and physical-device validation.

Major remaining areas are notification preferences and secondary event hooks,
native tenant device binding/background location, feedback persistence,
release signing/security, real-device FCM and geofencing testing, remote
migration/RLS verification, and operational readiness. Android and iOS are both production mobile
targets; a feature is not release-complete until its platform-specific behavior
has either been validated on both or is explicitly tracked as blocked.

## Immediate agenda

### September 25, 2026 — Today's implementation agenda

Today's work resumes the tenant-onboarding workstream and prioritizes physical
mobile validation. Complete the items in the following order so defects found
in platform services are resolved before the onboarding release candidate is
declared ready. A checkbox may be marked complete only after its stated tests
pass; Android success does not imply iOS success.

#### 1. Geofencing testing and fixes

- [ ] Run the existing automated geofence, scheduler, polygon, hysteresis,
  retry/backoff, deduplication, and session-cleanup tests; record and fix every
  regression before physical-device testing.
- [ ] Validate foreground, background, app-resume, force-close/relaunch, device
  restart, and power-management behavior on a physical Android device.
- [ ] Validate the equivalent lifecycle on a physical iPhone, including iOS
  location authorization changes and background restrictions.
- [ ] Test daytime, pre-curfew, active-curfew, and curfew-sleep rescheduling and
  confirm that only one scheduled checker is active.
- [ ] Exercise denied/permanently-denied permission, disabled GPS, timeout,
  poor signal, offline queueing, restored connectivity, and restored-location
  recovery paths.
- [ ] Perform an on-site walk across every polygon edge in both directions;
  compare expected transitions with persisted gate events and confirm that the
  hysteresis band prevents boundary chatter.
- [ ] Fix all reproducible defects without persisting raw coordinates, weakening
  role isolation, or generating duplicate IN/OUT events.
- [ ] Re-run automated tests plus the Android/iOS physical-device matrix and
  document any platform limitation that cannot be fixed today.

#### 2. Firebase Cloud Messaging for Android and iOS

Implementation update — September 25, 2026: FlutterFire initialization, Android
Firebase registration, permission handling, foreground/background/terminated
message lifecycle, local foreground presentation, token refresh/revocation,
notification-tap routing, an RLS-protected device-token/notification schema,
and the protected `send-fcm-notification` Edge Function are implemented. The
Android debug APK builds successfully. Production delivery remains open until
the physical-device delivery matrix is verified. The Google service-account
credentials must be stored as protected Supabase secrets in each deployment.
Messages, gate events, announcements, payments/utilities, maintenance, visitors,
curfew, conduct/appeals, and inspection completion have connected dispatch paths.
After a message is persisted, a protected Edge Function
derives its authorized recipients, creates their notification rows, and sends a
data-minimized push that excludes the message text. Taps target the conversation,
and foreground alerts are suppressed while that conversation is open.
Geofence notifications are also connected for meaningful IN/OUT transitions,
curfew flags, native background transitions, and staff manual logs. They notify
management and linked guardians (plus the tenant for a manual log), suppress
unchanged repeated checks, and never include coordinates or raw distance. iOS
remains open pending its Firebase plist,
APNs key, Apple capabilities/signing, Codemagic build, and physical-iPhone test.
Firebase Analytics was intentionally not added; the Firebase foundation remains
compatible with adding it later.

- [x] Add and configure the Flutter/Firebase messaging dependencies without
  exposing Firebase, APNs, or server credentials in the client repository.
- [x] Configure the Android Firebase application, notification permission for
  supported Android versions, manifest/service requirements, notification
  channel, icons, and foreground/background/terminated handlers.
- [ ] Configure the iOS Firebase application, Push Notifications and Background
  Modes capabilities, APNs authentication in Firebase, permission prompts, and
  foreground/background/terminated handlers.
- [x] Add protected per-user/per-device FCM token registration, token refresh,
  revocation on sign-out/account switch, last-seen metadata, platform metadata,
  RLS, and cleanup of invalid tokens.
- [x] Connect persisted role-scoped message notification events to server-side FCM
  delivery; keep payloads data-minimized and make the database notification row
  the source of truth.
- [ ] Implement notification tap/deep-link routing to authorized records after
  cold start, warm start, and authenticated session restoration.
- [ ] Respect per-user delivery preferences while allowing policy-approved
  mandatory safety notifications; define foreground presentation and duplicate
  suppression behavior.
- [ ] Test delivery, token rotation, preference enforcement, deep links, denied
  permission, sign-out, and account switching on physical Android and iPhone
  devices. Record delivery failures without logging sensitive payload content.

#### 3. Complete and optimize the tenant onboarding workflow

- [ ] Audit the current invitation/QR, authentication, profile form, contract,
  requirement, signer, document, activation, billing, room/bed, guardian,
  trusted-device, and permission steps against the canonical workflow below.
- [ ] Provide one resumable onboarding checklist with a clear current step,
  completed/pending/rejected states, role ownership, next action, and safe return
  after sign-in, deep link, app restart, or temporary failure.
- [ ] Remove duplicate entry points and dead ends; route owners, caretakers, and
  tenants to the same server-derived onboarding state while showing only actions
  authorized for their role.
- [ ] Optimize network loading by avoiding duplicate reads, refreshing only
  affected records, preserving entered form data, and providing explicit
  loading, empty, error, retry, offline, and submission-in-progress states.
- [ ] Complete invitation expiry/revocation, email verification, permanent
  password, profile validation, required documents, independent signers,
  signed-copy review, activation prerequisites, and audit history. SMS remains
  explicitly blocked until a provider is approved.
- [ ] Verify that activation is enforced server-side, makes financial terms
  immutable, generates the correct deposit/rent charges once, and cannot be
  bypassed by client navigation or repeated submissions.
- [ ] Complete the post-activation handoff to initial payment, room/bed
  assignment, guardian linking when required, trusted-device setup, and required
  permissions without conflating their underlying records.
- [ ] Add unit, widget, integration, multi-account RLS, offline/retry, QR/deep
  link, and duplicate-submission tests; validate the full happy path and recovery
  paths on Android and iOS.

#### Definition of done for today's agenda

- [ ] `flutter analyze` reports no issues and the complete Flutter test suite
  passes after all fixes.
- [ ] Geofencing has recorded Android and iOS physical-device results, including
  the on-site boundary walk or a clearly documented external blocker.
- [ ] FCM sends and opens authorized test notifications on both physical Android
  and iPhone devices in foreground, background, and terminated states.
- [ ] A newly invited tenant can resume and complete every currently approved
  onboarding prerequisite without staff/client bypasses or duplicate financial
  records.
- [ ] Update this progress file with actual results, remaining blockers, test
  counts, and platform/device evidence before closing the workday.

### Approved additions — implementation gate

The following additions were approved on September 23, 2026. They are
requirements only at this point; existing checkmarks elsewhere in this file do
not mean these additions are implemented. Implementation must proceed one step
at a time, and **Step 1 must not begin until the project owner says `go` after
reviewing these Markdown updates**.

1. **[✓] Step 1 — Separate rent and utility billing (implemented September 23,
   2026).** Keep contract rent as a
   fixed, contract-derived charge. Let an authorized owner or caretaker enter
   each variable utility charge (for example, higher electricity usage) and
   its independent due date. Tenant, guardian, and staff views must distinguish
   charge category, amount, due date, balance, and payment allocation. A utility
   change must never modify the fixed rent or rewrite historical charges.
   **Enhancement completed September 23, 2026:** owner/caretaker users can apply
   an audited rent increase or decrease to eligible unpaid future rent from an
   effective date. The contract rate and historical charges remain immutable;
   the override records old/new rates, reason, actor, time, and per-charge
   adjustments.
   **Utility cart enhancement completed September 23, 2026:** staff can prepare
   multiple utility lines for an individual tenant, selected rooms, or all
   occupied rooms. Shared bills support equal-per-tenant and equal-per-room
   allocation, snapshot room/bed occupants, prevent duplicate scope/period
   billing, and issue every tenant allocation in one atomic transaction.
2. **Step 2 — Digital tenant onboarding and contract workflow.** Use a QR code
   to open a secure tenant-specific data-entry/onboarding flow and generate a
   versioned PDF based on the photographed official contract supplied by the
   client. Walk-in students may begin without a guardian present; guardian
   linking, ID verification, and signature remain independently resumable until
   the client defines which items block activation. Track tenant/employee
   identity fields, required photocopies and their three-signature verification,
   separate lessor/tenant/guardian/optional-witness signatures, document review,
   and audit history. Keep both signed-copy upload and on-screen signing planned,
   but do not treat electronic signing as a physical-process replacement until
   the client confirms it.
3. **Step 3 — Cleaning schedules by bed.** Add a privacy-conscious module that
   assigns cleaning duties to bed identifiers rather than publicly identifying
   roommates. Tenants can view the schedule relevant to their room/bed and
   privately report non-compliance. Owner/caretaker users manage schedules and
   restricted reports; reports and reporter identities must not be exposed to
   roommates.
4. **Step 4 — Advance visitor registration.** Require a visit request no later
   than the calendar day before the visit, capture only the visitor ID details
   needed by dormitory policy, and require staff approval before the visit.
   Store sensitive ID data privately with restricted access, audit logs, and a
   defined retention/deletion policy. Same-day requests are invalid unless a
   separately authorized emergency override is later approved as policy.
5. **Step 5 — Room and bed identifier rules.** Room identifiers are plain
   sequential numbers and must not use floor-style ranges such as `101–110` or
   `201–210`. Each room has beds `1` through `4`; odd identifiers (`1`, `3`)
   are upper bunks and even identifiers (`2`, `4`) are lower bunks. Enforce the
   mapping in validation, display labels, assignments, and migration checks.

The canonical acceptance criteria and data/security notes for these additions
are in **Approved Additions — September 23, 2026** in
`CARMELINK_FULL_SYSTEM_PLAN.md`.

### Official-contract review priority — September 23, 2026

The client-supplied three-page lease was reviewed before workflow changes. No
photographed clause is sufficient authority for an irreversible automated
penalty, deposit forfeiture, or eviction. Confirmed procedures and unresolved
policy choices are recorded in the full system plan.

1. [ ] Finish Step 1 UI, migration deployment, and focused rent/utility tests;
   add electricity/water usage inputs after calculation rules are confirmed.
2. [ ] Build secure QR/walk-in onboarding and a resumable Draft checklist.
3. [✓] Add tenant/guardian ID and three-signature photocopy verification.
4. [✓] Add independent lessor, tenant, guardian, and optional-witness signature
   states, immutable PDFs, the physical-upload path, and owner verification.
   Physical-upload verification is implemented; electronic signature capture
   remains intentionally open pending client approval.
5. [✓] Replace free status editing with prerequisite-aware activation; keep the
   guardian blocking rule configurable until the client decides it.
6. [ ] Add versioned policies/addenda for visitors, utilities, employee curfew,
   rent changes, and enforcement/review rules missing from the lease.
7. [ ] Enforce the one-calendar-day visitor request procedure, contractual
   9:00 AM–9:00 PM window, approval, and reception arrival/departure logging.
8. [ ] Add monthly inspections with three days' written notice, evidence,
   findings, corrective actions, and follow-up.
9. [ ] Add a move-in room-condition snapshot if the client approves it.
10. [ ] Complete restricted disciplinary records before rule-based penalties.
11. [ ] Add separately allocated penalty/damage charges linked to an approved
    incident, inspection, or assessment.
12. [ ] Implement cleaning schedules by bed with private reporting.
13. [ ] Add approved employee curfew profiles to gate/geofence evaluation.
14. [ ] Add 30-day move-out notice, final inspection, clearance, and closure.
15. [ ] Add itemized deposit deductions, 30-day refund tracking, refund proof,
    and separately approved shortfall charges.
16. [ ] Add formal termination/eviction cases; never auto-evict from an incident.
17. [ ] Configure sensitive-record retention after client and legal/privacy
    review.

### Consolidated modules and developer ownership

The numbered priorities are requirements, not instructions to create seventeen
separate navigation modules. Related screens may be merged into an existing
module, while security-sensitive records, status lifecycles, and financial
ledgers remain separate in the database.

> [!IMPORTANT]
> **The Leader Developer owns all workflow-related implementation.** This
> includes any feature that coordinates multiple roles/modules or controls a
> tenant lifecycle transition: account → onboarding → contract → documents →
> signatures → activation → billing → occupancy, as well as conduct decisions →
> charges → termination and move-out → inspection → deposit settlement. The
> groupmate must not independently change these workflow state machines,
> activation gates, cross-module RPCs, or shared status values without agreeing
> the contract with the Leader Developer first.

| Consolidated area | Priorities merged | Implementation owner | Boundary |
|---|---:|---|---|
| Contracts & Onboarding | 2–6 | **Leader Developer** | QR onboarding, required documents, signers, PDF versions, addenda, activation, and contract-to-billing/occupancy orchestration |
| Visitor Management | 7 | Groupmate | Extend the existing visitor module; approval-to-gate integration and shared status/RPC changes require Leader Developer review |
| Room Operations & Inspections | 8, 9, 12 | Groupmate | One inspection system for move-in, monthly, follow-up, and move-out; cleaning appears under Rooms |
| Conduct & Cases | 10, 16 | Groupmate, with Leader Developer integration | Incidents, evidence, responses, warnings, repeat history, and termination recommendation; Leader Developer owns cross-module decision transitions |
| Billing Consequences | 11 | **Leader Developer** | Converts only approved incidents/inspections into separate penalty or damage ledger charges |
| Curfew & Gate | 13 | Groupmate | Add employee curfew profiles inside the existing module; Leader Developer reviews gate-evaluator/status changes |
| Move-out & Settlement | 14, 15 | **Leader Developer** | Notice, final inspection coordination, clearance, deposit ledger, refund/shortfall, contract and occupancy closure |
| Security & Retention Settings | 17 | Groupmate, with Leader Developer review | Administrative retention configuration; destructive jobs and authorization rules require Leader Developer approval |

Recommended groupmate sequence:

1. Visitor Management (Priority 7) and its policy presentation from Priority 6.
2. Room Operations & Inspections (Priorities 8, 9, and 12).
3. Conduct & Cases records/UI (Priorities 10 and 16), stopping before financial
   charge creation or irreversible contract transitions.
4. Employee curfew profiles inside Curfew & Gate (Priority 13).
5. Retention-settings UI/configuration (Priority 17), without enabling deletion
   jobs until policy and Leader Developer review are complete.

The Leader Developer continues the implemented contract workflow and owns the
integration portions of Priorities 6, 10–11, and 14–16. Each developer should
use a separate feature branch and avoid editing the same migration or workflow
files simultaneously.

### Navigation simplification roadmap

The application should consolidate navigation and presentation without merging
security boundaries, audit histories, status lifecycles, or database records.
The target is about five primary tenant destinations and no more than six staff
management areas; individual workflows remain available as focused subpages.

| Consolidated module | Workflows presented together | Status / boundary |
|---|---|---|
| Reporting | Maintenance, confidential concerns, and missed cleaning-duty reports | [✓] Unified tenant entry point and staff report-management entry implemented; underlying records and permissions remain separate |
| Rooms & Facilities | Rooms/beds, floor plan, cleaning, inspections, and maintenance locations | [ ] Planned; inspection findings remain distinct from repair tasks and charges |
| Access & Curfew | Presence, gate history, geofencing, manual logs, curfew requests/exceptions, and employee schedules | [ ] Planned; gate events and curfew approvals remain separate audited records |
| Tenant Management | Directory, tenant details, room assignment, guardian links, emergency contacts, onboarding, and contract status | [ ] Planned as one tenant profile with focused sections |
| Billing & Payments | Charges, rent/utilities, payment submission/review, cash payments, invoices, and income/expenses | [ ] Planned; contracts and each financial ledger/category remain distinct |
| Onboarding & Accounts | Invitations/QR, identity, documents, signers, guardian linking, activation, and access | [ ] Planned; authorization and activation gates remain server-controlled |
| Communication Center | Messages, announcements, emergency alerts, notifications, and contacts | [ ] Planned; notification preferences stay in Settings |
| Conduct & Cases | Incidents, warnings, responses, appeals, repeat history, and termination recommendations | [ ] Partially consolidated; cases must not directly create charges or terminate tenancy |
| Profile & Settings | Profile, security, notification preferences, permissions, device binding, appearance, and feedback | [ ] Planned |
| Analytics | Occupancy, finance, maintenance, and operational trends | [✓] Renamed from Reports & Analytics so it is not confused with report submission and review |

Recommended navigation work order: Rooms & Facilities; Access & Curfew; Tenant
Management; Billing & Payments; Onboarding & Accounts; Communication Center;
then Profile & Settings. Consolidation changes should remove duplicate top-level
entries while retaining deep links to the original focused workflows.

### Merge rules that remain mandatory

- Merge policy/addendum screens into Contracts and Rules & Policies, but keep
  immutable signed contract versions separate from editable policy drafts.
- Merge advance-visitor features into Visitor Management; do not build a second
  visitor module. Keep visitor requests separate from actual gate events.
- Merge move-in/monthly/follow-up/move-out checks into one Room Inspections
  module using an inspection type. Keep resulting maintenance work orders,
  disciplinary cases, and damage charges as linked records rather than one row.
- Merge cleaning schedules into Room Operations. Keep private non-compliance
  reports restricted under Conduct/Reports.
- Merge incidents, violations, warnings, and termination review into Conduct &
  Cases. A verified case may request a charge, but must not directly mutate the
  payment ledger or auto-evict a tenant.
- Merge employee curfew schedules into Curfew & Gate rather than creating a new
  module.
- Merge move-out clearance and deposit computation into one workflow, while
  preserving the deposit ledger and ordinary payment ledger as distinct facts.
- Place retention controls under Security/Settings rather than daily navigation.

Never merge contract status with signature status, an incident with its charge,
an inspection with its repair task, a visitor request with a gate event, or rent
with utility/penalty/damage balances. Those distinctions are required for RLS,
auditability, correction, and payment allocation.

Progress update — September 24, 2026:

- [✓] Added staff-created, tenant-bound, expiring/revocable QR invitations with
  private opaque tokens and protected Supabase operations.
- [✓] Added Android/iOS `carmelink://onboarding` deep-link handling that waits
  for an authenticated tenant session before opening the invitation form.
- [✓] Added the tenant academic/employment and emergency-contact submission
  flow, invitation history, QR display, and completion state.
- [✓] Added a prerequisite-aware activation sheet using the currently enforced
  verified-email and verified-latest-signed-document requirements. QR data,
  guardian linking, and room/bed assignment remain visible follow-up checks
  until the client decides which must block activation.
- [✓] Deployed onboarding invitation and contract requirement/signer migrations
  to the linked Carmelita's Dormitory Supabase project on September 24, 2026;
  local/remote migration history matches and linked database lint reports no
  schema errors.
- [ ] Run authenticated owner/tenant/guardian/caretaker remote smoke tests for
  invitation ownership, requirement storage access, signer updates, and denied
  cross-role operations.
- [✓] Added tenant/guardian ID records, private PDF/image uploads and previews,
  three-signature/physical-copy checks, approve/reject history, and independent
  lessor/tenant/guardian/witness signature states. Guardian and witness remain
  configurable and optional by default.
- [✓] Expanded activation enforcement so verified email, the latest verified
  signed contract, every required document, and every required signer are all
  checked by the database as well as shown in the owner UI.
- [ ] Replace the temporary generated PDF layout with a clean source version of
  the client's official contract; electronic signature capture remains pending
  client confirmation.

### Canonical new-tenant workflow — deployed backend/current app implementation

This is the current end-to-end operating sequence for a newly accepted tenant.
Guardian and witness requirements are configurable per contract and remain
optional by default while the client policy is open. Electronic signature
capture is not yet represented as a substitute for the physical signed copy.

1. **Authorized staff creates the tenant account.** The account and profile are
   created separately from the contract so a failed/deferred contract never
   deletes the tenant identity. The tenant must request and verify the six-digit
   email code on first sign-in.
2. **Owner creates a Draft contract or defers it.** `Create contract now` opens
   a tenant-locked editor. The owner records the contract number, term, monthly
   rent, security deposit, and notes. A contract must begin as Draft; direct
   creation as Active is rejected by the database.
3. **Owner creates the QR invitation.** The system creates a random, tenant-bound
   token that expires after seven days and can be revoked. The QR contains only
   `carmelink://onboarding?token=...`; it contains no tenant personal data.
4. **Tenant scans the QR and signs in.** Android/iOS opens CarmeLink through the
   custom deep link. If the tenant is not signed in, the app retains the pending
   token and opens the form only after an authenticated tenant session exists.
   The backend rejects another tenant, guardian, staff member, expired token,
   revoked token, or reused token.
5. **Tenant submits onboarding data.** The tenant reviews the instructions and
   submits school/employer, course/program, year level, and required emergency
   contact information. Successful submission updates only that tenant's detail
   record and permanently completes the one-time invitation.
6. **Owner reviews required documents.** From Contract documents → Required
   documents & signers, the owner uploads/reviews the tenant school/employee ID
   and the signed verification photocopies. PDF/JPG/PNG files are stored in the
   private contract bucket with size, hash, uploader, timestamps, and review
   history. The photocopy requirement cannot be verified until staff confirms
   that the physical copy was received and all three signatures are present.
7. **Guardian requirement is decided for that contract.** Parent/guardian ID is
   optional by default so a walk-in student can continue. If the owner marks it
   required, a verified guardian ID becomes an activation prerequisite. The
   guardian account/link may be completed later under the configured policy.
8. **System generates the immutable contract PDF.** The generated version
   snapshots the Draft contract terms and includes lessor, tenant, guardian, and
   optional-witness signature lines. Any material Draft-term change invalidates
   the prior signature state and requires a new generated version.
9. **Parties sign the exact generated version.** The physical signed PDF/image
   is uploaded against the latest version only. The owner previews it and either
   verifies or rejects it with review notes. Rejected or replaced documents do
   not satisfy activation.
10. **Owner verifies signers independently.** Lessor and tenant are required by
    default. Guardian and witness are optional but may be made required per
    contract. Each party has an independent Pending/Signed/Verified/Rejected/
    Waived state, signer name, method, timestamps, and notes. A verified PDF does
    not by itself prove every required signer was verified.
11. **Owner opens Activate contract.** The sheet displays required and follow-up
    checks. Activation is enabled only when email, the latest signed PDF, all
    required documents, and every required signer are verified. QR completion,
    guardian linking, and room/bed assignment remain visible follow-up checks
    unless their corresponding per-contract requirement is enabled.
12. **Database rechecks activation.** Server triggers reject client bypasses,
    missing verified email, unverified signed PDF, missing required documents,
    or incomplete required signers. Successful activation makes financial terms
    immutable and generates the existing security-deposit and rent schedule.
13. **Initial payments are submitted and verified.** Tenant proof is allocated
    to the intended deposit/rent charges. Only staff-verified transactions reduce
    balances. Rent, electricity, water, penalties, and damages remain separate.
14. **Staff completes occupancy and relationships.** Room/bed assignment,
    guardian linking where applicable, trusted-device setup, and permissions are
    completed through the resumable onboarding checklist. Historical contract,
    document, signer, charge, and payment facts remain immutable/auditable.

Backend deployment status: migrations `202609240001` and `202609240002` are
deployed to Supabase project `iuplkgvitovzjbmtzpme`; local/remote migration
history matches and linked database lint reports no schema errors. Authenticated
multi-account RLS/storage smoke testing and real Android/iOS QR testing remain
release checks.

1. **Income and expense management** — add owner-only financial records,
   categories, validation, recurring/one-time entries, audit fields, summaries,
   and RLS. This remains the leading item in the broader product backlog, but
   the contract-review sequence above is the controlling priority for the
   tenant onboarding/lease workstream.
2. **Persistent notifications and preferences** — generate role-scoped events,
   read/unread state, deep links, per-user delivery settings, and FCM delivery.
   Android and iOS/APNs implementation and physical-device validation are both
   included in the September 25 immediate agenda.
3. **Disciplinary records** — restricted incident, notice, evidence, and history
   workflow.
4. **Live reports and analytics** — derive owner metrics from the completed
   operational and financial tables.
5. **Native device binding and geofence scheduling** — complete tenant device
   registration, revocation, audit history, and background checks.

> [!IMPORTANT]
> **The complete tenant onboarding workflow was resumed on September 25, 2026.**
> Mobile implementation, optimization, and validation are part of today's
> immediate agenda. Integration points that still depend on the group web app
> remain tracked dependencies; they do not justify removing the existing schema,
> security rules, resumable mobile workflow, or documented release checks.

The planned contracts module must synchronize through separate contract,
billing-charge, and payment-transaction records. Verified payment amounts and
exact transaction timestamps reduce charge balances; contract changes must not
overwrite historical charges or payment facts. See the full system plan's
**Contract, Billing, and Payment Synchronization** section.

## Workflow improvements

### Geofencing production validation

The boundary evaluator and adaptive interval calculations have automated test
coverage, but this does not prove that scheduled checks execute reliably on a
physical device. Production readiness also requires validating the timer and
operating-system background restrictions across supported platforms.

- [✓] Unit-test polygon/radius boundaries, hysteresis, permissions, failures, and adaptive interval calculations.
- [✓] Implement the actual recurring geofence check scheduler; interval recommendations alone are not a running timer.
- [ ] Test timer rescheduling at daytime, pre-curfew, active-curfew, and curfew-sleep transitions.
- [✓] Verify that only one timer is active and that logout, account changes, and disposal cancel it.
- [ ] Test foreground, background, app-resume, device-restart, and operating-system power-management behavior on physical Android and iOS devices.
- [ ] Test denied permission, permanently denied permission, disabled GPS, timeouts, poor signal, and restored-location recovery.
- [✓] Confirm duplicate checks do not create duplicate IN/OUT events and that retry/backoff behavior is bounded.
- [ ] Run an on-site inside/outside boundary walk test and compare recorded transitions with the configured dormitory polygon.

### Mobile-store approval and cross-platform release risk

Both **Google Play** and the **Apple App Store** are release targets. Current
planning estimates are risk indicators rather than guarantees: approximately
75% first-submission approval likelihood for Google Play and 55% for the Apple
App Store in the current state. After the release-readiness checklist below is
completed, the working estimates rise to about 90% and 80–85%, respectively.

The largest shared review risk is background location/geofencing. Google Play
requires background location to be demonstrably central to the app and may
require a declaration and review video. Apple also requires a clear purpose,
appropriate permission timing, accurate privacy disclosures, and reliable
on-device behavior. FCM itself is not a material approval risk when permission,
privacy, and notification behavior are implemented correctly.

- [ ] Publish an accurate privacy policy and complete Google Data Safety and Apple App Privacy disclosures.
- [ ] Provide in-app account deletion and the required web deletion-request route when in-app account creation is enabled.
- [ ] Prepare stable reviewer accounts/instructions for owner, caretaker, tenant, and guardian roles.
- [ ] Provide a reviewer-safe method or instructions for evaluating geofence behavior away from the dormitory.
- [ ] Document and justify background-location use; request only the minimum permission scope on each platform.
- [ ] Validate notifications, location, camera, photo access, deep links, sign-out, and account switching on physical Android and iOS devices.
- [ ] Remove mock data, test credentials, placeholders, broken actions, visible overflow, and incomplete metadata before submission.
- [ ] Produce signed Android App Bundle and iOS archive/TestFlight builds from the same release candidate.
- [ ] Complete any applicable Google Play closed-testing requirement before applying for production access.

### Account creation → contract — ACTIVE SEPTEMBER 25 WORKSTREAM

After an authorized owner or caretaker creates a **tenant** account, no
verification message is sent automatically. When the tenant attempts to sign
in, CarmeLink holds the account on a verification page. The tenant selects
**Send code** to request a six-digit email OTP; SMS verification remains on
hold. The account-creation success screen should then offer **Create contract
now** and **Do this later**.
All new account roles require email and mobile verification, while only tenant
accounts continue into contract onboarding.
Choosing the first action opens the live contract editor with the new tenant ID
prefilled and locked for the initial contract. Guardian, caretaker, and owner
accounts skip this step.

Account and contract creation remain separate transactions. A valid account is
not rolled back when contract entry is deferred or fails; the tenant remains
visible in the directory and the incomplete onboarding state can be resumed.
The contract may be saved as Draft while account verification is pending. The
workflow then generates a versioned printable PDF, records that signatures are
awaited, accepts a private upload of the scanned signed paper, and requires
owner verification before activation. Contract activation currently requires
verified email and a verified signed document. Mobile verification remains on
hold until an SMS provider is selected. Afterward, the guided workflow
continues to room/bed assignment and guardian linking.

Canonical end-to-end tenant onboarding order:

1. Create the tenant authentication account and protected profile.
2. Verify email and mobile number, then set a permanent password.
3. Offer **Create contract now** or **Do this later**.
4. Create a tenant-locked **Draft** contract with its financial terms, term,
   and recurring due day (the contract start day).
5. Generate the immutable PDF, collect signatures, and upload the signed copy.
6. Owner verifies the signed document; the contract remains Draft.
7. Owner activates the contract after the verification checklist passes.
8. Activation generates deposit and first-rent charges; future charges remain
   Upcoming until their due dates.
9. Tenant submits the required initial payment and staff verifies it. Only
   verified transaction amounts reduce the charge balance.
10. Assign the tenant's room and bed.
11. Create or confirm the guardian link when required.
12. Bind the tenant's trusted device and configure required device permissions.
13. Mark onboarding complete and unlock the permitted tenant workflows.

Contract lifecycle and document lifecycle remain separate: `draft -> active ->
expired/terminated` versus `not_generated -> awaiting_signature ->
pending_verification -> verified/rejected`. Device binding is tenant-only and
must not block staff-side account or Draft-contract preparation.

Implementation follow-up:

- [✓] Return the created tenant profile ID from the account-management flow.
- [✓] Create accounts without automatic email, then send and verify a
  six-digit email OTP only when the user selects **Send code**; SMS OTP is on
  hold pending provider selection.
- [✓] Expose Pending/Verified email state and independent On hold mobile state.
- [✓] Add `Create contract now` and `Do this later` success actions for owners.
- [✓] Open the contract editor with the tenant preselected and locked.
- [✓] Generate an immutable, versioned printable contract PDF.
- [✓] Upload the signed paper privately and record uploader/time/file metadata.
- [✓] Add owner signed-document verification before contract activation.
- [✓] Display an onboarding-incomplete indicator for tenants without contracts.
- [✓] Continue from signed-document verification to room/bed assignment and guardian linking.
- [ ] Replace free contract-status selection with a prerequisite-aware owner
  **Activate contract** action.
- [ ] Add initial-payment, room/bed, guardian, permanent-password,
  device-binding, and permission requirements to one resumable checklist.
- [ ] Prevent required room/bed assignment until configured initial charges are
  fully paid, while keeping guardian linking independently resumable.

## Status legend

- [✓] Completed and connected, or fully complete as a static feature
- [ ] Incomplete, including UI that still uses mock data
- **Live** — connected to Supabase
- **Mock** — uses local demonstration data or a simulated workflow

## Important core of the system

These modules should be completed before optional automation such as OCR,
geofencing or advanced analytics.

1. **Identity and access** — authentication, profiles, roles, verification, and RLS.
2. **People and relationships** — tenants, guardians, staff, and their verified links.
3. **Rooms and occupancy** — rooms, beds, assignments, vacancies, and contracts.
4. **Payments** — charges, balances, receipts, verification, and payment history.
5. **Maintenance** — submissions, locations, assignments, status, and resolution.
6. **Presence, curfew, and visitors** — auditable events and approval workflows.
7. **Communication** — announcements, notifications, and role-scoped messaging.
8. **Safety and privacy** — confidential reports, audit logs, retention, and permissions.

## Completed Milestones History

> **Sep 20, 2026 — Contract-to-Billing Synchronization:** Added separate
> immutable billing-charge and payment-transaction ledgers. Activating a
> contract idempotently generates its deposit and monthly rent schedule with
> frozen term snapshots. Only verified transactions reduce server-calculated
> balances; partial payments remain supported, and historical financial facts
> cannot be rewritten by later contract or review changes. Existing invoices
> and payment submissions are preserved through a ledger migration.

> **Sep 19, 2026 — Message Read Receipts:** Added server-timestamped `read_at`
> receipts, recipient-only read updates through a protected RPC, automatic read
> marking when a conversation is viewed, realtime receipt updates, and Sent/Read
> indicators for owner, caretaker, tenant, and guardian message views. Migration
> `202609190013` is deployed. Multi-account production testing remains.

> **Sep 19, 2026 — Signed Contract Document Workflow:** Added owner-side
> generation and sharing of versioned contract PDFs, immutable private storage
> for generated and signed copies, SHA-256 file metadata, signed-copy review,
> and activation guards requiring both verified tenant email and an
> owner-verified signed document. Migration `202609190010` is deployed. The
> complete Flutter suite passes at 186/186 tests, static analysis reports no
> issues, and the Android debug APK builds successfully.

> **Sep 19, 2026 — Contract Production Verification:** Added and ran a remote
> multi-role smoke test against the deployed Supabase project. It verifies
> owner create/read/update/delete, tenant/guardian/caretaker isolation across
> read/write/delete operations, invalid-date rejection, tenant-only contract
> association, and cleanup of the temporary record. The complete Flutter suite
> passes at 183/183 tests and static analysis reports no issues.

> **Sep 19, 2026 — Live Contract CRUD:** Added an owner-only Supabase contract
> register with create, read, update, and delete operations; tenant association,
> contract number, term, rent, deposit, lifecycle status, notes, search, and
> filters. Database constraints enforce valid dates, non-negative amounts,
> unique contract numbers, and one active contract per tenant. Migration
> `202609190007` and date-summary sync migration `202609190008` are deployed.
> Contract-to-billing synchronization was completed on Sep 20, 2026; contract
> edits never rewrite generated charges or payment history.

> **Sep 19, 2026 — Visitor Production Verification:** Added and ran a remote
> multi-account smoke test across tenant, guardian, owner, and caretaker
> identities. It verifies tenant submission and visibility, guardian isolation,
> blocked tenant approval, owner approval, caretaker arrival/departure, final
> completion, and three append-only audit events under deployed RLS policies.

> **Sep 19, 2026 — Production Data & Responsive Hardening:** Removed runtime
> `MockData` fallbacks from operational controllers, payment services,
> messaging, and shared notification views. Backend failures now remain visible
> instead of fabricating successful records. Added a 30-case responsive matrix
> spanning representative tenant, guardian, caretaker, and owner pages across
> narrow phone, landscape, tablet, desktop, and enlarged text; all cases pass.

> **Sep 19, 2026 — Visitor Workflow Database Hardening (Phase 1):** Added a
> controlled visitor lifecycle (`pending` → `approved`/`rejected`/`cancelled`
> → `arrived` → `completed`), protected staff/tenant transition RPC, reviewer
> metadata, append-only arrival/departure events, role-scoped RLS, audit-safe
> cancellation, indexes, and real-time publication. Visitor language now uses
> arrival, departure, and presence rather than implying gate staff or hardware.

> **Sep 19, 2026 — Live Visitor Workflow (Phase 2):** Replaced visitor mock
> data with Supabase-backed tenant and staff controllers, request submission,
> cancellation, approval/rejection, arrival/departure recording, role-visible
> history, loading/error states, and real-time refresh. Added visitor model and
> controller coverage; 150/150 tests pass.

> **Sep 19, 2026 — Visitor Scheduling & Contact Rules:** Added pending-request
> editing, visitor contact numbers, arrival/departure pickers, and an explicit
> no-overnight policy. PostgreSQL validates that departure follows arrival on
> the same Asia/Manila calendar date, while the app provides immediate matching
> validation and clearly communicates the dormitory rule.

> **Sep 19, 2026 — Owner Confidential Report Review:** Connected the owner-only
> confidential report register to Supabase with mandatory private decision
> notes, status workflow, protected RPCs, and an append-only audit trail for
> register access and status changes. Caretakers and guardians remain blocked.

> **Sep 19, 2026 — Tenant-only Device Binding:** Removed Device Binding from
> guardian, caretaker, and owner Settings views and added a tenant-only role
> guard to the page. Other roles cannot expose it through direct navigation.

> **Sep 19, 2026 — Owner-only Geofence Diagnostics:** Removed the Geofence Dev
> Dashboard from shared Settings and added a direct owner role guard. Shared
> Settings now contains only user-relevant privacy and permission controls.

> **Sep 19, 2026 — Feedback UI:** Added a shared Settings feedback screen for
> all roles with a 1–5 star rating, feedback categories, detailed comments,
> optional account context, validation, and an explicit UI-only disclosure.
> Backend persistence and staff review are intentionally deferred.

> **Sep 19, 2026 — Tenant Confidential Reports (Phase 1):** Tenants can submit
> validated confidential safety, rule, roommate, or other concerns and view
> only their own immutable submission history. Supabase RLS denies access to
> unrelated accounts. Owner/caretaker review is intentionally deferred until
> the next approved role phase.

> **Sep 19, 2026 — Secure Cloudinary Media Integration:** Maintenance evidence
> and payment receipts now use server-side authenticated Cloudinary uploads.
> Secrets remain in Supabase Edge Functions, database RLS authorizes each view,
> links expire after five minutes, uploads are optimized, and legacy Supabase
> Storage paths remain readable.

| Date | Module / Feature | Roles Covered | Summary & Verification |
|---|---|---|---|
| Sep 13, 2026 | **Auth & Role Routing** | All | Supabase session restore, `RoleGuard`, server-role routing, profile and password management. |
| Sep 14, 2026 | **Rooms & Bed Space Management** | Tenant, Caretaker, Owner | Live room/bed CRUD, assignments/transfers, occupant details, and 2D floor plan visualization merged into Room Monitoring. |
| Sep 15, 2026 | **Curfew & Overnight Leave System** | Tenant, Guardian, Staff | 'Late Return' and 'Overnight Leave' dual workflows, guardian endorsement, staff review with gate instructions, and real-time sync. |
| Sep 16, 2026 | **Maintenance Management System** | Tenant, Caretaker, Owner | Full lifecycle triage: report submission with 5MB photo and floor plan pin, triage queue, metric cards, `InteractiveViewer` zoom, mandatory resolution notes, and audit trail (`maintenance_staff_history`). 56/56 tests passing. |
| Sep 17, 2026 | **Cloudinary Media Architecture (Documented)** | All | Documented media CDN upgrade in system plan and progress tracking (`f_auto,q_auto`, dynamic thumbnails, mobile bandwidth offloading). |
| Sep 17, 2026 | **Tenant Payments & Upload Proof** | Tenant | Account summary, filter chips (All, Due, Pending, Verified), overdue indicators, receipt zoom inspection, GCash/Maya/Bank instructions, and 5MB proof submission with OCR auto-fill. 71/71 tests passing. |
| Sep 17, 2026 | **Owner & Caretaker Payment Verification & Invoicing** | Caretaker, Owner | Full staff payment suite: financial dashboard grid (Pending, Collected, Outstanding, Overdue), live search (tenant/room/title/ref), status chips, issue invoice modal dialog with category & due date, zoomable receipt inspection (`InteractiveViewer`), approve/reject with mandatory reasons, and cash payment recording. 86/86 tests passing. |
| Sep 17, 2026 | **Payments Overflow Audit & Layout Hardening** | Tenant, Guardian, Caretaker, Owner | Comprehensive overflow fixes across all payment pages: responsive `LayoutBuilder` for review card details & action buttons, `_RejectReasonSheet` scrollable maxHeight constraints with keyboard insets support, `_CreateInvoiceDialog` `isExpanded` dropdowns and responsive due date picker, `_TenantPaymentCard` full-width & stacked action buttons, and `_showReceiptDialog` constrained scrollable dialog. Verified with 7 dedicated narrow viewport (320px) and 1.35x font scale tests. 93/93 tests passing. |
| Sep 18, 2026 | **GPS Geofencing & Gate Monitoring** | Tenant, Guardian, Caretaker, Owner | Full geofencing & gate monitoring suite: on-device 50m geofence evaluation with ±3.0m hysteresis buffer, strict zero-coordinate persistence (data minimization), null direction on UNAVAILABLE, server-side curfew auto-flagging via RPC, intelligent curfew sleep battery optimization, staff manual log dialog with mandatory notes validation, and role-specific views across Owner, Caretaker, Tenant, and Guardian. 113/113 tests passing. |
| Sep 18, 2026 | **Full Application Permissions & System Settings Suite** | Tenant, Guardian, Caretaker, Owner | Configured complete manifest and plist permissions: Android (`INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `CAMERA`, `READ_EXTERNAL_STORAGE`, `READ_MEDIA_IMAGES`, `VIBRATE`), iOS (`NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`), and macOS client network entitlements. Wired native system settings triggers in `PrivacyPermissionsPage` and tenant location warning cards (`GeofenceService.openAppSettings()`, `GeofenceService.openLocationSettings()`). 115/115 tests passing. |
| Sep 18, 2026 | **Perimeter Polygon Geofencing & Dev Dashboard** | Tenant, Guardian, Caretaker, Owner | Refined geofence boundary check from circular 50m model to an isolated 4-point polygon model using on-site GPS measured coordinates (P1: `14.949435, 120.884892`; P2: `14.949252, 120.884822`; P3: `14.949350, 120.884520`; P4: `14.949547, 120.884542`). Preserved strict zero-coordinate persistence with ray-casting point-in-polygon and ±3.0m edge hysteresis. Created interactive `GeofenceDevDashboardPage` with 2D `CustomPainter` visualizer, coordinate test evaluator, and volatile in-memory test override panel. Database migration `202609180002_dorm_boundary_polygon.sql` added for perimeter config. 130/130 tests passing, 0 analyzer issues. |

## Core requirements by page

`[✓]` means the page's core requirement is live or complete. `[ ]` means the
page exists but its important backend workflow is unfinished.

### Authentication pages

- [✓] **Splash and Welcome** — initialize Supabase and restore the session.
- [✓] **Sign in** — authenticate credentials and route using the server role.
- [✓] **Change password** — reauthenticate and update Supabase credentials.
- [✓] **Forgot password** — manual **Send code**, six-digit recovery OTP,
  resend cooldown, verification, and password update are implemented.
- [ ] **Account onboarding** — invitation, permanent password, and required SMS verification.

### Tenant pages

- [ ] **Home** — live room, balance, maintenance, gate, and announcement summary.
- [✓] **My Room** — assigned room, bed, roommates, capacity, and utilities with live database sync and real-time refresh.
- [✓] **Payments** — charges, outstanding balance, due dates, filter chips, overdue badges, receipt inspection, and payment history.
- [✓] **Upload Payment Proof** — payment destination instructions, 5MB receipt attachment with interactive zoom, on-device OCR auto-capture, and live submission.
- [✓] **Reports Hub** — unified access to live maintenance, confidential, and
  missed cleaning-duty reporting; includes a report-type chooser, focused
  workflows, pull-to-refresh, and active issue alerts.
- [✓] **Maintenance Reports** — live tenant-owned reports with status filters (All, Pending, In Progress, Resolved, Cancelled), interactive details sheet, photo zoom, caretaker notes, and cancellation for pending reports.
- [✓] **Submit Maintenance** — validated category, urgency guidance, description, assigned room context, and photo attachment with 5MB validation.
  - **Cloudinary Integration** — authenticated uploads, optimized derivatives, RLS-authorized access, and offloaded Supabase media storage.
- [✓] **Maintenance Floor Plan** — interactive 2D floor plan map location picker integrated directly into report submission.
- [✓] **Announcements** — live audience-filtered notices from Supabase.
- [✓] **Messages and Conversation** — persisted, role-scoped real-time messaging; production multi-account testing remains.
- [✓] **Gate and Curfew** — verified IN/OUT events, curfew status, on-device geofence check-in, and presence timeline.
- [✓] **Curfew Exception (Tenant)** — differentiated request types ('Late Return' direct to caretaker vs 'Overnight Leave' with guardian endorsement), departure/return schedule pickers, status pills, cancellation of pending requests, and live Supabase real-time sync.
- [✓] **Visitor Request (current implementation)** — live visitor identity,
  purpose, schedule, review, contact details, pending edits, same-day-only
  arrival/departure scheduling, cancellation, visit status, and audit-safe
  real-time history. **Step 4 must replace same-day scheduling with prior-day
  registration and add protected visitor ID capture.**
- [✓] **Confidential Concern (Tenant Phase)** — restricted live submission and tenant-only history protected by RLS; staff review is deferred.
- [✓] **Rules and Policies** — maintained dormitory rules and safety guidance.

### Guardian pages

- [✓] **Home** — live linked-tenant, payment, and notice summary with real-time refresh.
- [✓] **Curfew Overview** — linked tenant's current status, overnight leave endorsements, and approved exceptions with live real-time sync.
- [✓] **Gate Activity** — verified presence and discrete gate activity for linked tenants only with isolated alert preferences.
- [✓] **Curfew Requests** — review overnight leave requests with parental remarks, endorse/decline actions, audit timestamps, and real-time Supabase sync.
- [✓] **Payment Status** — live read-only charges, balances, and verification status for linked tenants.
- [✓] **Announcements** — guardian-audience notices from Supabase with realtime subscription.
- [✓] **Messages and Conversation** — persistent real-time communication with authorized management; production multi-account testing remains.
- [ ] **Emergency and Safety Alerts** — urgent targeted alerts and acknowledgement.

### Caretaker pages

- [ ] **Tenants** — live directory and operational tenant information.
- [✓] **Rooms** — live room/bed CRUD, vacancies, bed occupant details (name, contact), bed reassignment/transfers across rooms, and unassignment.
- [✓] **Maintenance** — triage, assign staff, start work, update status, record resolution notes, inspect photos with tap-to-zoom (InteractiveViewer), floor plan overview integration, and audit trail.
- [✓] **Payment Verification & Invoicing** — staff payment review: financial dashboard metrics, proof verification, invoice generation, status filters, and cash payment recording.
- [✓] **Gate** — review live resident presence directory, discrete transition logs, and record authorized manual overrides.
- [✓] **Curfew & Exceptions** — review live late return and overnight leave requests, approve with gate instructions or reject with reason, real-time sync via Supabase table subscriptions.
- [✓] **Accounts** — CRUD limited to tenant and guardian accounts.
- [✓] **Profile** — authenticated caretaker identity and access level.

### Owner pages

- [ ] **Dashboard** — prioritized live occupancy, payment, maintenance, and gate metrics.
- [ ] **Tenants** — full tenant directory, relationships, assignments, and contracts.
- [ ] **Operations** — live grouped access to every management workflow.
- [✓] **Rooms** — live room and bed-space CRUD with assignment-aware occupancy, occupant tenant details (name, phone), inter-room bed transfer/reassignment, and assignment termination.
- [✓] **Floor Plan (Integrated)** — merged as an interactive 2D map view inside Room Monitoring (`RoomMonitoringPage`) with live Supabase occupancy and bed details, rather than an isolated standalone page.
- [✓] **Payments (Payment Verification & Invoicing)** — financial metrics (Pending, Collected, Outstanding, Overdue), tenant search & filter chips, invoice issuance modal with billing categories, receipt proof zoom, approve/reject actions with audit notes, and mark-as-paid for cash payments.
- [✓] **Maintenance** — live request triage, metric summary cards (Open, High Priority, In Progress, Resolved), search & status filtering, assign staff, record resolution details with mandatory notes validation, floor plan overview, photo zoom inspection, and audit history.
- [✓] **Gate and Manual Override** — auditable access decisions, 50m perimeter metrics, live presence directory, and staff manual log override.
- [✓] **Curfew Review** — live request list, guardian input status, staff approval with gate instructions or rejection with reasons, emergency staff override, real-time Supabase sync, and prioritized dashboard attention card.
- [✓] **Visitor Management** — live approve/reject, arrival/departure recording,
  role-scoped history, and append-only audit events.
- [✓] **Confidential Reports** — owner-only live review with mandatory notes, protected status decisions, and audit logging.
- [ ] **Announcements** — create, target, publish, and archive notices.
- [ ] **Messages** — persistent tenant and guardian conversations.
- [ ] **Contacts** — verified guardian and emergency contact directory.
- [✓] **Contracts** — live owner CRUD with tenant, dates, amounts, lifecycle,
  search/filtering, owner-only RLS, and historical records.
- [ ] **Income and Expenses** — validated financial records and owner-only RLS.
- [ ] **Disciplinary Records** — verified incidents, notices, and restricted history.
- [ ] **Reports and Analytics** — owner-only metrics generated from live records.
- [✓] **Accounts & Access** — full CRUD with server-enforced role permissions.
- [✓] **Guardian Links** — owner-only create, edit, primary selection, and removal using live data.
- [✓] **Profile** — authenticated owner identity and access level.

### Shared pages

- [✓] **Profile identity** — live name, email, phone, and server-controlled role.
- [ ] **Profile role details** — editable tenant and staff details with validation.
- [ ] **Notifications** — persisted read/unread, audience, type, and deep links.
- [✓] **Settings and Theme** — local appearance preference.
- [ ] **Notification Preferences** — persist preferences per authenticated account.
- [ ] **Privacy and Permissions** — connect actual device permission state.
- [ ] **Device Binding (Tenant only)** — tenant-only UI and route guard are complete; native registration, revocation, and audit history remain.
- [ ] **Verification Code** — secure expiring SMS OTP with retry and resend limits.
- [✓] **Dormitory Information** — static dormitory information and contact guidance.
- [✓] **Feedback UI** — Settings entry and validated feedback form completed; backend submission and staff review remain pending.

### Requirements applying to every live page

- [ ] Loading, empty, error, retry, and offline states.
- [ ] Server-side authorization for every read and mutation.
- [ ] Input validation on both Flutter and Supabase.
- [ ] Audit fields for sensitive creation, updates, approvals, and deletion.
- [✓] Responsive phone, tablet, and wide-screen matrix for representative critical pages.
- [ ] Unit, widget, integration, and role-access tests.
- [✓] No production page depends on `MockData`; test data is injected explicitly.

### Media Pipeline & Upgrades

**Implemented Sep 19, 2026:** Secure Cloudinary media storage is connected for
maintenance evidence and payment receipts. Assets use Cloudinary's
`authenticated` delivery type. Upload, URL, and delete operations run through
JWT-protected Supabase Edge Functions; existing database RLS authorizes every
view before a five-minute private-download URL is returned. JPG, PNG, and WEBP
uploads retain the 5 MB limit and receive incoming optimization plus eager
1200px and 320px derivatives. Legacy Supabase Storage paths remain supported.
User avatars are not yet part of the current upload workflow.

- [✓] **Cloudinary Media Storage & CDN Integration** *(implemented for maintenance evidence and payment receipts)*:
  - **Authenticated storage**: Maintenance evidence and payment receipts are private Cloudinary assets; avatars are not yet part of the upload workflow.
  - **Optimization**: Incoming images are limited to 2400px with automatic quality selection; 1200px and 320px eager derivatives are prepared.
  - **Protected delivery**: RLS-authorized Edge Functions return expiring private-download URLs instead of public asset URLs.
  - **Egress savings**: New binary uploads no longer consume Supabase Storage capacity or object-delivery bandwidth.
  - **Backward compatibility**: Existing private Supabase Storage paths remain readable while new rows store opaque Cloudinary references.

## Development handoff

Tenant and Guardian development can continue without waiting for the Owner or
Caretaker interfaces. The authentication, profile, relationship, room, bed,
assignment, and initial RLS foundations are already available.

### Developer 2 functions that are truly independent

These functions do not require a completed Owner/Caretaker page or an
owner-created operational record. Their database tables and RLS policies still
need to be agreed on before implementation.

#### Tenant

- [✓] Sign in, sign out, view authenticated profile, and change password.
- [✓] Use local theme/settings and view Rules and Dormitory Information.
- [ ] Edit only the tenant's permitted personal and emergency-contact fields.
- [ ] Create and view the tenant's own maintenance submissions in `Pending` state.
- [ ] Create, view, and cancel the tenant's own unreviewed visitor requests.
- [ ] Create, view, and cancel the tenant's own unreviewed curfew requests.
- [✓] Submit and view the tenant's own confidential concerns.
- [ ] Persist the tenant's own notification preferences.

#### Guardian

- [✓] Sign in, sign out, view authenticated profile, and change password.
- [✓] View the existing verified guardian-to-tenant relationship.
- [✓] Use local theme/settings and view Dormitory Information.
- [ ] Edit only the guardian's permitted personal contact fields.
- [✓] View curfew requests submitted by an already-linked tenant.
- [✓] Approve or reject those requests with remarks and a decision timestamp.
- [ ] Persist the guardian's own notification preferences.

The curfew workflow above depends on the Tenant and Guardian implementations,
but it does not require the Owner page. The request may remain
`Awaiting staff decision` after the guardian response.

### Functions that depend on Owner, Caretaker, or external system data

- [ ] Room, bed, roommate, occupancy, and contract display needs staff assignment data.
- [ ] Payment balances and history need owner-created charges and payment records.
- [ ] Payment verification needs an owner/caretaker decision.
- [ ] Maintenance assignment, progress, and completion need caretaker actions.
- [ ] Announcements and emergency alerts need staff-published content.
- [ ] Staff messaging needs a staff participant and response workflow.
- [ ] Gate activity needs verified geofence or manual staff records.
- [ ] Visitor requests need staff approval for a completed workflow.
- [✓] Curfew requests need a final staff decision for a completed workflow.
- [ ] Geofencing, OCR, and analytics need external services.

### Recommended independent implementation order

1. Permitted self-profile editing.
2. Tenant maintenance submission and own-history viewing.
3. Tenant curfew submission and Guardian approval/rejection.
4. Tenant visitor submission and cancellation.
5. Tenant confidential-concern submission.
6. Tenant and Guardian notification preferences.

### Shared contracts that must be agreed first

- [ ] Table and column names for payments, maintenance, announcements, curfew,
  visitors, messages, and notifications.
- [ ] Allowed status values and valid status transitions.
- [ ] Model and repository method names used by Flutter.
- [ ] Tenant ownership and guardian-link rules used by RLS.
- [ ] Storage bucket names and upload rules.
- [ ] Real-time subscription channels where required.

### File ownership during the handoff

Developer 1 owns:

- `lib/views/owner/`
- `lib/views/caretaker/`
- `lib/views/auth/`
- `lib/services/account_service.dart`
- `lib/views/shared/account_management_page.dart`
- `supabase/migrations/`
- `supabase/functions/`

Developer 2 owns:

- `lib/views/tenant/`
- `lib/views/guardian/`
- `lib/controllers/tenant_controller.dart`
- `lib/controllers/guardian_controller.dart`
- New tenant/guardian repositories and services agreed by both developers.

Shared files require coordination before editing:

- `lib/models/models.dart`
- `lib/app.dart`
- `lib/views/shared/`
- `lib/core/`
- `pubspec.yaml`

### Handoff rules

- [ ] Developer 2 works from a dedicated `feature/tenant-guardian-live-data` branch.
- [ ] Do not edit migrations `001` through `006`; create a new migration instead.
- [ ] Never place the Supabase service-role key in Flutter code or assets.
- [ ] Keep all role restrictions in RLS or protected server functions.
- [ ] Test changes using both tenant and guardian accounts.
- [ ] Confirm that each role is denied access to unrelated records.
- [ ] Update this progress file in the same pull request as each completed feature.

## Developer 1 — Owner, Caretaker, and foundation

Owned folders and files:

- `lib/views/owner/`
- `lib/views/caretaker/`
- `lib/views/auth/`
- `lib/core/`
- `lib/services/`
- `lib/controllers/session_controller.dart`
- `supabase/`

### Authentication and security

- [✓] Splash, welcome, sign-in, and forgot-password pages
- [✓] Show/hide-password toggle
- [✓] Supabase email/password login — **Live**
- [✓] Persistent session restoration — **Live**
- [✓] Server-controlled role lookup — **Live**
- [✓] Separate role routing for tenant, guardian, caretaker, and owner
- [✓] Protected profiles table and row-level security
- [✓] Explicit anonymous-access revocation and authenticated privileges
- [✓] Role guards around all four role workspaces
- [✓] Separate caretaker operational navigation
- [✓] Owner-only authorization helper for restricted future tables
- [✓] Live role-access checks for anonymous and authenticated accounts
- [✓] One test account for each role
- [✓] Connect password changes to Supabase Auth
- [ ] Configure and test password-recovery deep links end to end
- [✓] Display authenticated profile identity and live role relationships
- [✓] Add protected owner/caretaker account management
- [✓] Place owner account management under Operations and caretaker Accounts
- [✓] Deploy role-restricted server-side user creation
- [✓] Add full account CRUD: create, list, edit, recovery, and delete
- [✓] Verify account CRUD against Supabase with temporary-record cleanup
- [✓] Add owner-only guardian-to-tenant link management and RLS
- [✓] Send every new user a secure email invitation through Resend (deployment awaits the production API secret)
- [ ] Open onboarding from the invitation link and require a permanent password
- [ ] Require owners and caretakers to verify SMS during onboarding
- [ ] Require guardians to verify SMS before approving sensitive requests
- [ ] Require tenants to verify SMS before gate, visitor, and recovery actions
- [ ] Add SMS OTP expiration, retry limits, resend cooldown, and attempt limits (on hold)
- [✓] Store independent email and phone verification timestamps for security auditing
- [✓] Enforce verified email before contract activation; SMS enforcement is on hold
- [ ] Add recovery handling when a user cannot access their email or phone
- [ ] Add table-specific RLS as backend features are connected
- [ ] Complete production access-control testing

### Planned account verification flow

1. Authorized staff creates the account.
2. The user receives a secure email invitation.
3. The invitation opens onboarding and the user creates a permanent password.
4. SMS verification is requested according to the account role or sensitive action.
5. Required verification must succeed before protected access is granted.

| Role | SMS requirement |
|---|---|
| Owner | Required during onboarding |
| Caretaker | Required during onboarding |
| Guardian | Required before approving sensitive requests |
| Tenant | Required before gate, visitor, and account-recovery actions |

The email invitation verifies ownership of the email address. The SMS code
separately verifies the registered phone and is never placed inside the email
link.

### Owner and Caretaker pages

- [ ] Dashboard — UI implemented, **Mock**
- [ ] Tenant directory and tenant details — UI implemented, **Mock**
- [ ] Operations hub and category pages — UI implemented, **Mock**
- [ ] Room monitoring and interactive floor plan — UI implemented, **Mock**
- [ ] Payment verification — UI implemented, **Mock**
- [ ] Maintenance management and floor monitoring — UI implemented, **Mock**
- [ ] Gate monitoring and manual override — UI implemented, **Mock**
- [ ] Curfew monitoring and request review — UI implemented, **Mock**
- [✓] Visitor management — **Live**, RLS-tested multi-account workflow
- [✓] Confidential reports — owner-only live workflow with protected RPCs and audit logging
- [ ] Announcements — UI implemented, **Mock**
- [✓] Messaging and conversations — live Supabase persistence and realtime first iteration
- [ ] Emergency contacts — UI implemented, **Mock**
- [✓] Contracts — owner CRUD and lifecycle register, **Live**
- [ ] Finance, discipline, and analytics — UI implemented, **Mock**
- [✓] Guardian-to-tenant linking — owner management UI, **Live**

### Developer 1 next tasks

- [✓] Create core profile, room, bed-space, assignment, and guardian-link tables
- [✓] Add core foreign keys, validation, indexes, and RLS policies
- [✓] Separate tenant and staff role-specific information tables
- [✓] Apply tenant, guardian, caretaker, and owner policies to detail tables
- [✓] Create role-specific detail rows during secure account creation
- [ ] Design feature tables for payments, maintenance, gate, and visitors
- [ ] Connect tenants, rooms, payments, maintenance, gate, and visitors
- [ ] Apply operational staff and owner-only policies to every connected table
- [ ] Replace owner mock controllers with repositories/services
- [ ] Add loading, empty, offline, and backend-error states
- [ ] Verify owner actions are rejected for tenant and guardian accounts

## Developer 2 — Tenant, Guardian, and shared pages

Owned folders and files:

- `lib/views/tenant/`
- `lib/views/guardian/`
- `lib/views/shared/`
- `lib/controllers/tenant_controller.dart`
- `lib/controllers/guardian_controller.dart`

### Tenant pages

- [ ] Home/dashboard and My Room — UI implemented, **Mock**
- [ ] Payments and payment history — UI implemented, **Mock**
- [ ] Payment-proof upload — UI implemented, **Mock**
- [ ] Reports hub — UI implemented, **Mock**
- [ ] Maintenance list, submission, and floor plan — UI implemented, **Mock**
- [ ] Announcements — UI implemented, **Mock**
- [✓] Messages and conversation — live Supabase persistence and realtime first iteration
- [ ] Gate and curfew overview — UI implemented, **Mock**
- [ ] Curfew-exception request — UI implemented, **Mock**
- [✓] Visitor request — **Live**, same-day-only and audit-safe; approved Step 4
  prior-day registration and protected ID capture are not yet implemented
- [✓] Confidential concern — live tenant-only persistence and RLS
- [✓] Rules and policies

### Guardian pages

- [✓] Home/dashboard — live linked-tenant, room, and payment summary with realtime sync — **Live**
- [✓] Linked-tenant identity on Profile — **Live**
- [ ] Curfew overview and gate activity — UI implemented, **Mock**
- [ ] Curfew-request review — UI implemented, **Mock**
- [✓] Payment status — linked tenant charges and verification state — **Live**
- [✓] Announcements — guardian-audience notices from Supabase — **Live**
- [✓] Messages and conversation — live Supabase persistence and realtime first iteration
- [ ] Emergency and safety alerts — UI implemented, **Mock**

### Shared pages

- [✓] Profile with authenticated user information — **Live**
- [ ] Notifications — UI implemented, **Mock**
- [✓] Settings and theme selection — **Local state**
- [ ] Notification preferences — UI implemented, **Mock/local state**
- [ ] Privacy and permissions — UI implemented, **Mock/local state**
- [✓] Change password — **Live**
- [✓] Password recovery — manual **Send code**, six-digit email OTP, resend
  cooldown, verification, and recovered-password update are live
- [ ] Device binding and verification code — UI implemented, **Mock**
- [✓] Dormitory information

### Developer 2 next tasks

- [ ] Connect tenant data to tables prepared by Developer 1
- [ ] Connect guardian-to-tenant relationships
- [ ] Store payment proofs in Supabase Storage
- [ ] Persist visitor requests; maintenance, curfew, and confidential reports are live
- [✓] Connect announcements and real-time messaging
- [ ] Connect notification preferences
- [ ] Verify tenants can access only their own records
- [ ] Verify guardians can access only their linked tenant

## Shared integration tasks

- [✓] Standardize roles as `tenant`, `guardian`, `caretaker`, and `owner`
- [✓] Create and verify one test login for each role
- [ ] Agree on table, column, model, and storage-bucket names
- [ ] Test phone, tablet, and wide-screen layouts
- [ ] Add unit, widget, and integration tests
- [ ] Test session expiry, sign-out, recovery, and offline behavior
- [ ] Replace all mock data before production release
- [ ] Remove visible test credentials and test accounts before release
- [ ] Complete a final RLS and privacy audit

## Test accounts

Development only; remove before production.

| Role | Email |
|---|---|
| Tenant | `tenant@carmelita.test` |
| Guardian | `guardian@carmelita.test` |
| Caretaker | `caretaker@carmelita.test` |
| Owner | `owner@carmelita.test` |

The shared test password is intentionally shown only in the sign-in screen for
development convenience. Do not reuse it for real accounts.

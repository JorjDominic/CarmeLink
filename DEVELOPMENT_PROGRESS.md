# CarmeLink Development Progress

Last updated: September 13, 2026

This file tracks development separately from the README. Page ownership is
divided between two developers to reduce merge conflicts.

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
6. **Gate, curfew, and visitors** — auditable events and approval workflows.
7. **Communication** — announcements, notifications, and role-scoped messaging.
8. **Safety and privacy** — confidential reports, audit logs, retention, and permissions.

## Completed Milestones History

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
- [ ] **Forgot password** — complete and test recovery email deep links.
- [ ] **Account onboarding** — invitation, permanent password, and required SMS verification.

### Tenant pages

- [ ] **Home** — live room, balance, maintenance, gate, and announcement summary.
- [✓] **My Room** — assigned room, bed, roommates, capacity, and utilities with live database sync and real-time refresh.
- [✓] **Payments** — charges, outstanding balance, due dates, filter chips, overdue badges, receipt inspection, and payment history.
- [✓] **Upload Payment Proof** — payment destination instructions, 5MB receipt attachment with interactive zoom, on-device OCR auto-capture, and live submission.
- [✓] **Reports Hub** — live maintenance and confidential-report summaries with pull-to-refresh and active issue alerts.
- [✓] **Maintenance Reports** — live tenant-owned reports with status filters (All, Pending, In Progress, Resolved, Cancelled), interactive details sheet, photo zoom, caretaker notes, and cancellation for pending reports.
- [✓] **Submit Maintenance** — validated category, urgency guidance, description, assigned room context, and photo attachment with 5MB validation.
  - *Planned Media Upgrade*: **Cloudinary Integration** — dynamic compression (`f_auto,q_auto`), progressive loading, thumbnail transformations (`c_thumb`), and offloaded media bandwidth.
- [✓] **Maintenance Floor Plan** — interactive 2D floor plan map location picker integrated directly into report submission.
- [ ] **Announcements** — show only notices published for the tenant audience.
- [ ] **Messages and Conversation** — persisted, role-scoped real-time messaging.
- [✓] **Gate and Curfew** — verified IN/OUT events, curfew status, on-device geofence check-in, and presence timeline.
- [✓] **Curfew Exception (Tenant)** — differentiated request types ('Late Return' direct to caretaker vs 'Overnight Leave' with guardian endorsement), departure/return schedule pickers, status pills, cancellation of pending requests, and live Supabase real-time sync.
- [ ] **Visitor Request** — visitor identity, schedule, status, and audit history.
- [ ] **Confidential Concern** — encrypted/restricted submission visible only to authorized staff.
- [✓] **Rules and Policies** — maintained dormitory rules and safety guidance.

### Guardian pages

- [✓] **Home** — live linked-tenant, payment, and notice summary with real-time refresh.
- [✓] **Curfew Overview** — linked tenant's current status, overnight leave endorsements, and approved exceptions with live real-time sync.
- [✓] **Gate Activity** — verified presence and discrete gate activity for linked tenants only with isolated alert preferences.
- [✓] **Curfew Requests** — review overnight leave requests with parental remarks, endorse/decline actions, audit timestamps, and real-time Supabase sync.
- [✓] **Payment Status** — live read-only charges, balances, and verification status for linked tenants.
- [✓] **Announcements** — guardian-audience notices from Supabase with realtime subscription.
- [ ] **Messages and Conversation** — persistent communication with authorized staff.
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
- [ ] **Visitor Management** — approve, reject, and audit visitor access.
- [ ] **Confidential Reports** — owner-authorized access with audit logging.
- [ ] **Announcements** — create, target, publish, and archive notices.
- [ ] **Messages** — persistent tenant and guardian conversations.
- [ ] **Contacts** — verified guardian and emergency contact directory.
- [ ] **Contracts** — dates, renewal state, expiry alerts, and history.
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
- [ ] **Device Binding** — trusted-device registration, revocation, and audit history.
- [ ] **Verification Code** — secure expiring SMS OTP with retry and resend limits.
- [✓] **Dormitory Information** — static dormitory information and contact guidance.

### Requirements applying to every live page

- [ ] Loading, empty, error, retry, and offline states.
- [ ] Server-side authorization for every read and mutation.
- [ ] Input validation on both Flutter and Supabase.
- [ ] Audit fields for sensitive creation, updates, approvals, and deletion.
- [ ] Responsive phone, tablet, and wide-screen testing.
- [ ] Unit, widget, integration, and role-access tests.
- [ ] No production page may depend on `MockData`.

### Media Pipeline & Upgrades

- [ ] **Cloudinary Media Storage & CDN Integration** *(Planned Upgrade)*:
  - Migrate binary photo storage (maintenance evidence, payment proof receipts, user avatars) from direct Supabase storage buckets to **Cloudinary**.
  - **Dynamic optimization**: Automatic format delivery (`f_auto` to WebP/AVIF) and network-aware compression (`q_auto`).
  - **Dynamic transformations**: Responsive thumbnail cropping for cards and lists (`c_thumb,w_150,h_150`) alongside high-resolution deliveries for full-screen inspection.
  - **Egress & bandwidth savings**: Offloads binary file uploads directly from mobile devices, preserving database bandwidth and accelerating load times.
  - **Backward-compatible schema**: Store Cloudinary public IDs or secure URLs in `maintenance_reports.photo_path` without requiring breaking schema redesigns.

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
- [ ] Submit and view the tenant's own confidential concerns.
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
- [ ] Send every new user a secure email invitation
- [ ] Open onboarding from the invitation link and require a permanent password
- [ ] Require owners and caretakers to verify SMS during onboarding
- [ ] Require guardians to verify SMS before approving sensitive requests
- [ ] Require tenants to verify SMS before gate, visitor, and recovery actions
- [ ] Add OTP expiration, retry limits, resend cooldown, and attempt limits
- [ ] Store email and phone verification timestamps for security auditing
- [ ] Enforce verification requirements in RLS or protected server functions
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
- [ ] Visitor management — UI implemented, **Mock**
- [ ] Confidential reports — UI implemented, **Mock**
- [ ] Announcements — UI implemented, **Mock**
- [ ] Messaging and conversations — UI implemented, **Mock**
- [ ] Emergency contacts — UI implemented, **Mock**
- [ ] Contracts, finance, discipline, and analytics — UI implemented, **Mock**
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
- [ ] Messages and conversation — UI implemented, **Mock**
- [ ] Gate and curfew overview — UI implemented, **Mock**
- [ ] Curfew-exception request — UI implemented, **Mock**
- [ ] Visitor request — UI implemented, **Mock**
- [ ] Confidential concern — UI implemented, **Mock**
- [✓] Rules and policies

### Guardian pages

- [✓] Home/dashboard — live linked-tenant, room, and payment summary with realtime sync — **Live**
- [✓] Linked-tenant identity on Profile — **Live**
- [ ] Curfew overview and gate activity — UI implemented, **Mock**
- [ ] Curfew-request review — UI implemented, **Mock**
- [✓] Payment status — linked tenant charges and verification state — **Live**
- [✓] Announcements — guardian-audience notices from Supabase — **Live**
- [ ] Messages and conversation — UI implemented, **Mock**
- [ ] Emergency and safety alerts — UI implemented, **Mock**

### Shared pages

- [✓] Profile with authenticated user information — **Live**
- [ ] Notifications — UI implemented, **Mock**
- [✓] Settings and theme selection — **Local state**
- [ ] Notification preferences — UI implemented, **Mock/local state**
- [ ] Privacy and permissions — UI implemented, **Mock/local state**
- [✓] Change password — **Live**
- [ ] Password recovery — email request is live; deep-link flow needs testing
- [ ] Device binding and verification code — UI implemented, **Mock**
- [✓] Dormitory information

### Developer 2 next tasks

- [ ] Connect tenant data to tables prepared by Developer 1
- [ ] Connect guardian-to-tenant relationships
- [ ] Store payment proofs in Supabase Storage
- [ ] Persist maintenance, visitor, curfew, and confidential reports
- [ ] Connect announcements and real-time messaging
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

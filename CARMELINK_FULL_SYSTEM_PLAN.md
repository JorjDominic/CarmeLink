# CarmeLink — Full System Plan

## Proposed System: Carmelita's Dormitory Management System

CarmeLink is a role-based dormitory management platform for Carmelita's Dormitory. It is designed to centralize tenant records, guardian relationships, room and bed assignments, payments, maintenance, curfew and gate monitoring, visitor requests, announcements, messaging, safety reports, contracts, and administrative reporting in one system.

The current project already uses one shared Flutter codebase and one Supabase backend so every role works with the same protected data source rather than separate databases.

> **Implementation note:** The ZIP currently has live Supabase authentication, protected profiles and roles, account management, core rooms/bed spaces/tenant assignments, role-specific detail tables, and guardian-to-tenant links. Many operational pages are already designed but still use mock/demo data while their production backend tables and services are being completed.

---

# 1. Platforms and Technology Stack

## Client Applications

- **Flutter Mobile** — primary interface for tenants and guardians.
- **Flutter Web / responsive Flutter interface** — primary management interface for the owner and caretaker.
- **Flutter desktop targets** — project runners also exist for Windows, macOS, and Linux, although the main intended experiences are mobile and web/responsive administration.

## Backend

- **Supabase Auth** — sign-in, sessions, password changes, recovery, and identity management.
- **Supabase PostgreSQL** — central relational database.
- **Row Level Security (RLS)** — server-side role and record access restrictions.
- **Supabase Edge Functions** — protected administrative actions such as account creation and account management.
- **Supabase Storage** — planned for payment proofs, maintenance photos, incident evidence, and other uploads.
- **Supabase Realtime** — planned where live messages, notifications, gate events, and status updates are required.

## Current High-Level Architecture

```text
Flutter Mobile / Web
        │
        │ Supabase SDK / HTTPS / JSON
        ↓
Supabase Backend
├── Authentication
├── PostgreSQL Database
├── Row Level Security
├── Edge Functions
├── Storage
└── Realtime
```

The key design rule is to keep **one backend and one database** for all roles. Tenant, guardian, caretaker, and owner interfaces should never maintain separate copies of the same dormitory data.

---

# 2. User Roles

| Role | Primary Purpose | Main Access |
|---|---|---|
| **Owner** | Full dormitory administration | Accounts, tenants, rooms, finance, contracts, safety, reports, gate, maintenance, communication |
| **Caretaker** | Daily dormitory operations | Tenants, rooms, maintenance, gate, tenant/guardian accounts, operational communication |
| **Guardian** | Monitor and support a linked tenant | Linked tenant information, curfew, gate activity, payment status, requests, announcements, messages |
| **Tenant** | Resident self-service | Room information, payments, maintenance, gate/curfew, visitor requests, announcements, reports, messages |

## Role Separation

```text
Login
  ↓
Supabase Authentication
  ↓
Load protected profile
  ↓
Check server-controlled role
  ├── Owner      → Owner Workspace
  ├── Caretaker  → Caretaker Workspace
  ├── Guardian   → Guardian Workspace
  └── Tenant     → Tenant Workspace
```

Users do not choose their own role in the client. The role is stored in the protected `profiles` table and enforced by RLS and protected backend logic.

---


# Development Ownership — Two-Developer Split

CarmeLink development is divided between two developers so the Owner/Caretaker backend work and the Tenant/Guardian client work can progress in parallel with fewer merge conflicts.

## Developer 1 — Owner, Caretaker, Authentication, and Backend Foundation

**Primary responsibility:** server-side foundation, database design, security, Owner/Caretaker workflows, and protected administrative functions.

Owned areas:

- `lib/views/owner/`
- `lib/views/caretaker/`
- `lib/views/auth/`
- `lib/core/`
- `lib/services/`
- `lib/controllers/session_controller.dart`
- `lib/services/account_service.dart`
- `lib/views/shared/account_management_page.dart`
- `supabase/migrations/`
- `supabase/functions/`

Main system responsibilities:

- Authentication and session security
- Role routing and role guards
- Account creation and account management
- Owner-only guardian-to-tenant link management
- Database migrations and relational schema
- Row Level Security policies
- Owner dashboard and Operations Hub
- Caretaker operational pages
- Room/bed management and staff-side assignments
- Staff-side payment verification
- Staff-side maintenance management
- Gate monitoring and manual overrides
- Staff curfew decisions
- Visitor approvals
- Owner financial records, contracts, reports, and analytics
- Backend support for OCR, geofencing, gate devices, notifications, and other advanced integrations

## Developer 2 — Tenant, Guardian, and User-Facing Shared Pages

**Primary responsibility:** Tenant and Guardian workspaces plus shared end-user pages and the repositories/controllers needed to connect those pages to the agreed backend contracts.

Owned areas:

- `lib/views/tenant/`
- `lib/views/guardian/`
- `lib/views/shared/` except Developer 1-owned account-management components
- `lib/controllers/tenant_controller.dart`
- `lib/controllers/guardian_controller.dart`
- New Tenant/Guardian repositories and feature services agreed by both developers

Main system responsibilities:

- Tenant dashboard and My Room
- Tenant payments and payment-proof flow
- Tenant maintenance submission and history
- Tenant gate/curfew interface
- Tenant curfew exception requests
- Tenant visitor requests
- Tenant confidential concerns
- Tenant announcements and messaging
- Guardian dashboard and linked-tenant information
- Guardian curfew/gate monitoring
- Guardian request approval/rejection
- Guardian payment status
- Guardian announcements, messages, and emergency alerts
- Shared profile, settings, notifications, notification preferences, permissions, and dormitory-information pages
- Tenant/Guardian loading, empty, error, and offline states
- Client-side validation for Tenant/Guardian workflows

## Shared Files Requiring Coordination

The following files affect both development lanes and should not be edited independently without agreeing on the contract first:

- `lib/models/models.dart`
- `lib/app.dart`
- Shared routing/navigation definitions
- Shared theme/core contracts
- `pubspec.yaml`
- Any repository interface used by both management and resident roles

`lib/views/shared/` is primarily handled by Developer 2, but **account-management UI and any shared page that changes protected account/role behavior remain Developer 1-owned or require explicit coordination**.

## Backend Contract Rule

Developer 1 owns production migrations and RLS. Developer 2 should not create competing schemas for the same feature. Before connecting a feature, both developers agree on:

- Table and column names
- Allowed status values
- Valid status transitions
- Model/repository method names
- Storage bucket names and upload policies
- Realtime channels where needed
- Tenant ownership rules
- Guardian-to-tenant access rules

This allows Developer 2 to build against a stable contract while Developer 1 keeps database security centralized.

## Parallel Development Principle

```text
DEVELOPER 1                              DEVELOPER 2
Owner + Caretaker + Backend              Tenant + Guardian + Shared UX
        │                                         │
        ├── Defines schema/RLS/contracts ─────────┤
        │                                         ├── Connects user-facing pages
        ├── Builds staff workflows                ├── Builds resident/guardian workflows
        │                                         │
        └──────────── Integration + role tests ───┘
```

The Tenant and Guardian interfaces do not need to wait for every Owner/Caretaker page to be finished. They only need the relevant database contract, RLS rules, and test data for the feature being connected.

---

# 3. Authentication and Account Management

**Primary owner: Developer 1.** Developer 2 consumes the authenticated session and role/profile data in Tenant, Guardian, and shared user pages.

## Authentication Pages

- Splash screen
- Welcome/onboarding introduction
- Sign in
- Forgot password
- Change password
- Password recovery flow
- Verification-code interface
- Device-binding interface

## Account Provisioning Strategy

CarmeLink should not use open public registration because it contains private tenant, guardian, financial, and access information.

Recommended flow:

```text
Owner / Authorized Caretaker
        ↓
Create Account
        ↓
Protected Supabase Edge Function
        ↓
Create Supabase Auth User
        ↓
Create Profile + Role-Specific Record
        ↓
User receives invitation / temporary access
        ↓
User signs in and sets permanent password
```

## Account Permissions

| Action | Owner | Caretaker | Guardian | Tenant |
|---|---:|---:|---:|---:|
| Create tenant account | Yes | Yes | No | No |
| Create guardian account | Yes | Yes | No | No |
| Create caretaker account | Yes | No | No | No |
| Create owner account | Yes | No | No | No |
| Manage guardian links | Yes | No | No | No |
| Change own password | Yes | Yes | Yes | Yes |
| Change own role | No | No | No | No |

The current ZIP already contains live account-management services and protected Edge Functions for user creation and management.

---

# 4. Owner Web / Administrative Workspace

**Primary owner: Developer 1.**

## Main Navigation

```text
Dashboard
Tenants
Operations
Gate
Profile
```

The Owner workspace provides the broadest access in the system.

---

# 5. Owner Dashboard

**Primary owner: Developer 1.**

The dashboard should prioritize information requiring action rather than only showing raw statistics.

## Summary Cards

- Occupancy
- Pending payment reviews
- Open maintenance reports
- Gate alerts

## Priority Items

- Contracts nearing expiration
- Payment proofs awaiting verification
- Pending curfew decisions
- Flagged gate events
- Urgent maintenance concerns

## Recommended Expanded Metrics

- Total rooms
- Total bed spaces
- Occupied bed spaces
- Available bed spaces
- Total active tenants
- Pending payments
- Outstanding balance
- Monthly collected rent
- Active maintenance requests
- Tenants currently outside
- Late arrivals
- Pending visitor requests

---

# 6. Owner Operations Hub

**Primary owner: Developer 1.**

The actual project groups owner functions into focused categories rather than placing every management page in one long menu.

## A. Accounts & Access

### User Accounts

- Create accounts
- View accounts
- Edit permitted account details
- Send password recovery
- Delete accounts with confirmation
- Enforce role-specific creation permissions

### Guardian Links

- Link a guardian account to a tenant
- Store relationship type
- Select a primary guardian
- Prevent invalid guardian/tenant role combinations
- Allow several guardians for one tenant
- Allow only one primary guardian for each tenant

---

## B. Property

### Room Monitoring

- View rooms
- View floor
- View capacity
- View occupied bed count
- View available bed count
- View room status
- Open room information

### Interactive Administrative Floor Plan

- Ground-floor and second-floor layout
- Pan and zoom
- Dedicated zoom controls
- Reset view
- Search by room number
- Full-screen floor-plan view
- Occupancy mode
- Maintenance mode
- Room selection
- Room capacity and vacancy details
- Maintenance markers
- Shared spaces, corridors, stairs, and entrances

### Maintenance Management

- View pending requests
- View ongoing requests
- View completed requests
- Open request details
- Review category
- Review urgency
- Review exact location
- Review description
- Assign or update work
- Change status
- Add resolution notes

### System / Device Status

Planned monitoring for supporting gate and safety services:

- Camera status
- Recognition processor
- Geofence service
- Network/connectivity
- Other IoT or monitoring devices

---

## C. Tenants & Safety

### Curfew Monitoring

- View tenants currently outside
- View approved exceptions
- View late-arrival records
- Open curfew requests
- Review guardian response
- Make final staff decision

### Visitor Management

- View expected visitors
- Review visitor relationship
- Review visit schedule
- Approve visitor
- Reject visitor
- Maintain visitor status/history

### Confidential Reports

- Restricted owner/authorized-staff access
- Review tenant safety concerns
- Review roommate concerns
- Review rules-related concerns
- Change investigation/status information
- Maintain privacy and audit history

### Disciplinary Records

- Record verified violations
- Record issued notices
- Associate records with tenants
- Store date, details, action, and status
- Restrict access to authorized personnel

---

## D. Finance & Contracts

### Payment Verification

```text
Tenant Uploads Proof
        ↓
OCR / Receipt Extraction
        ↓
Pending Verification
        ↓
Owner / Caretaker Review
        ↓
Confirm or Correct Details
        ↓
Payment Status Updated
        ↓
Receipt / History Updated
```

Functions:

- Review submitted payment proof
- Review tenant identity
- Review amount
- Review reference number
- Approve payment
- Reject/correct payment
- Keep verification history

### Income & Expenses

- Collected rent
- Outstanding balances
- Penalties
- Utilities
- Operating expenses
- Monthly financial summaries

### Contract Expiry

- Contract start date
- Contract end date
- Expiring-soon alerts
- Renewal planning
- Move-out planning
- Contract history

### Reports & Analytics

- Occupancy
- Payment compliance
- Outstanding balances
- Maintenance status
- Curfew flags
- Gate activity
- Contract status
- Visitor activity
- Tenant records
- Operational summaries

Recommended export formats:

- PDF
- Excel
- CSV

---

## E. Communication

### Announcements

Owner/caretaker can publish:

- Rent reminders
- Maintenance schedules
- Water interruption notices
- Electricity interruption notices
- Dormitory rules
- Events
- Emergency notices
- General announcements

Announcements should support audience targeting such as:

- All users
- Tenants
- Guardians
- Staff
- Specific tenant/guardian groups when required

### Messages

- Tenant-to-staff conversation
- Guardian-to-staff conversation
- Message history
- Role-scoped access
- Planned real-time updates

### Contact Directory

- Guardian contacts
- Emergency contacts
- Dormitory office information
- Important internal contact information

---

# 7. Caretaker Workspace

**Primary owner: Developer 1.**

## Main Navigation

```text
Tenants
Rooms
Maintenance
Gate
Accounts
Profile
```

The Caretaker handles operational work without receiving the same unrestricted financial, analytics, role-administration, and owner-only controls as the Owner.

## Caretaker Functions

### Tenants

- View tenant directory
- Search tenants
- Review operational tenant information
- View room assignment
- View guardian contact
- View gate status
- Open relevant operational records

### Rooms

- View occupancy
- View vacancies
- View bed-space availability
- Assist with room/bed monitoring

### Maintenance

- Review requests
- Update status
- Assign/coordinate work
- Record completion information

### Gate

- Review gate events
- Review flagged events
- Record authorized manual override
- Check gate system status

### Accounts

Caretaker account management is intentionally restricted to:

- Tenant accounts
- Guardian accounts

Caretakers cannot create owner or caretaker accounts.

---

# 8. Tenant Mobile Application

**Primary owner: Developer 2.** Backend tables/RLS are supplied through contracts maintained by Developer 1.

## Main Navigation

```text
Home
Payments
Reports
Gate
Profile
```

The tenant interface should stay simpler than the staff interface and focus on resident self-service.

---

# 9. Tenant Home

**Primary owner: Developer 2.**

Recommended dashboard structure:

```text
Good afternoon, Anna
Room 204 • Bed 2 • Second Floor

Current Balance
Due Date
[ Upload Payment Proof ]

Gate Status
Inside / Outside
Curfew Time

Priority Items
- Rent due soon
- Maintenance update
- Curfew/visitor request status

Quick Actions
[ Payment ] [ Maintenance ]
[ Curfew ]  [ Visitor ]

Latest Announcement
```

## Home Information

- Current room and bed
- Outstanding balance
- Next due date
- Gate status
- Latest maintenance update
- Recent announcement
- Urgent items
- Quick actions

---

# 10. Tenant Room Information

**Primary owner: Developer 2.**

## My Room

- Room number
- Floor
- Bed space
- Room capacity
- Current occupancy
- Roommates
- Utility summary
- Room amenities

Room and bed information should come from the same central room assignment records used by staff.

---

# 11. Tenant Payments & Utilities

**Primary owner: Developer 2 for Tenant UI/integration; Developer 1 owns billing/payment schema and staff verification.**

## Features

- Current balance
- Due date
- Payment history
- Payment status
- Utility charges
- Receipt/reference information
- Upload payment proof

## Suggested Billing Status

- Paid
- Partially Paid
- Unpaid
- Overdue
- Pending Verification
- Rejected / Needs Correction

## Payment Proof Flow

```text
Open Payments
    ↓
Upload Receipt / Screenshot
    ↓
OCR Extracts Amount + Reference
    ↓
Tenant Reviews Extracted Details
    ↓
Submit
    ↓
Pending Staff Verification
    ↓
Approved / Rejected
```

OCR is currently represented as a simulated workflow in the ZIP and should not be considered a live production integration yet.

---

# 12. Tenant Reports Hub

**Primary owner: Developer 2.**

The tenant Reports section combines maintenance and private concern reporting.

## Reports Dashboard

- Maintenance report count
- Open requests
- High-priority requests
- Recent status changes
- Confidential concern access

---

# 13. Maintenance Workflow

**Split ownership:** Developer 2 owns Tenant submission/history UX; Developer 1 owns the production schema, RLS, staff assignment, progress, and completion workflow.

## Tenant Submission

```text
Maintenance Report
      ↓
Select Category
      ↓
Choose Urgency
      ↓
Select Exact Location
      ↓
Description
      ↓
Optional Photo
      ↓
Submit
      ↓
Pending
      ↓
Assigned / In Progress
      ↓
Completed
```

## Categories

- Electrical
- Plumbing
- Air-conditioning
- Furniture
- Internet
- Room damage
- Shared facility
- Other

## Maintenance Floor Plan

The tenant can use an interactive floor plan to identify the exact room or dormitory location connected to the report.

---

# 14. Gate and Curfew Module

**Split ownership:** Developer 2 owns Tenant/Guardian views and request UX; Developer 1 owns gate-event infrastructure, staff review, overrides, and backend enforcement.

This is one of the system's major safety and monitoring modules.

## Tenant Gate & Curfew Page

- Current Inside/Outside status
- Curfew time
- Late-record count
- Recent gate activity
- Verification method
- Curfew-exception access
- Visitor-request access

## Gate Event Model

Each verified gate event should contain:

- Tenant/person
- Direction: IN or OUT
- Date/time
- Verification source
- Event status
- Review state if flagged
- Staff notes if manually reviewed

## Planned Gate Verification

```text
Tenant Gate Activity
        ↓
Recognition / Gate Signal
        ↓
Geofence Cross-Check
        ↓
Create Gate Event
        ↓
Normal Event ─────→ Update Tenant Status
        │
        └── Flagged Event
                ↓
        Staff Review / Override
                ↓
           Audit Record
```

The current UI includes facial-recognition events, geofence cross-check status, device/service health, and manual override screens. These are product workflows in the current ZIP; their production hardware/geofencing integrations are still pending.

---

# 15. Curfew Exception Workflow

**Split ownership:** Developer 2 owns Tenant submission and Guardian decision UX; Developer 1 owns the shared schema/RLS and final Owner/Caretaker decision workflow.

```text
Tenant Creates Request
        ↓
Reason + Destination + Expected Return
        ↓
Guardian Reviews
        ↓
Guardian Approves / Rejects
        ↓
Owner / Caretaker Reviews
        ↓
Final Staff Decision
        ↓
Curfew Monitoring Uses Approved Exception
```

## Curfew Request Data

- Tenant
- Reason
- Destination
- Expected return
- Guardian status
- Guardian decision timestamp
- Guardian remarks
- Staff/owner status
- Staff decision timestamp
- Staff remarks
- Request status/history

---

# 16. Visitor Request Workflow

**Split ownership:** Developer 2 owns Tenant request/cancellation; Developer 1 owns schema/RLS and staff approval/audit workflow.

```text
Tenant Registers Visitor
        ↓
Visitor Name
Relationship
Schedule
Purpose / Notes
        ↓
Pending Review
        ↓
Owner / Caretaker
   ├── Approve
   └── Reject
        ↓
Visitor Status / History
```

Recommended visitor fields:

- Visitor name
- Contact number
- Relationship
- Tenant visited
- Visit date
- Expected time in
- Expected time out
- Purpose
- Approval status
- Actual time in/out when gate logging is available

---

# 17. Confidential Concern Reporting

**Split ownership:** Developer 2 owns Tenant submission/history; Developer 1 owns restricted staff access, audit logging, and server-side authorization.

Tenants can privately submit concerns involving:

- Safety
- Rules
- Roommates
- Harassment or misconduct
- Property issues
- Other sensitive concerns

## Workflow

```text
Tenant Submits Confidential Concern
        ↓
Restricted Storage
        ↓
Authorized Owner / Staff Review
        ↓
Investigation / Action
        ↓
Status Update
        ↓
Audit Trail
```

Access must be tightly controlled through RLS and server-side authorization. These reports should never appear in general tenant directories or unrestricted caretaker lists unless explicitly permitted by the final policy.

---

# 18. Announcements and Notifications

**Split ownership:** Developer 1 owns staff publishing/backend contracts; Developer 2 owns Tenant/Guardian consumption, notification preferences, and user-facing notification UX.

## Announcement Flow

```text
Owner / Caretaker Creates Notice
        ↓
Select Audience
        ↓
Publish
        ↓
Tenant / Guardian Receives Notice
        ↓
Notification + Announcement History
```

## Tenant Notification Types

- Rent due soon
- Rent overdue
- Payment approved/rejected
- Maintenance updated
- Curfew request updated
- Visitor request updated
- New announcement
- Gate alert when appropriate

## Guardian Notification Types

- Tenant curfew request
- Curfew approval/rejection status
- Gate or late-arrival alert
- Payment status
- Emergency/safety announcement
- General guardian notice

## Owner/Caretaker Notification Types

- New payment proof
- New maintenance request
- New visitor request
- New curfew request
- Guardian decision submitted
- Flagged gate event
- Contract nearing expiration
- Urgent confidential concern

---

# 19. Guardian Mobile Application

**Primary owner: Developer 2.**

## Main Navigation

```text
Home
Curfew
Requests
Messages
Profile
```

The Guardian role is read-focused and approval-focused. A guardian should only see tenants connected through a verified `guardian_tenant_links` record.

---

# 20. Guardian Home

**Primary owner: Developer 2.**

## Summary Information

- Linked tenant
- Current gate status
- Outstanding payment
- Pending curfew approvals
- Important notices

## Quick Links

- Tenant information
- Payment status
- Announcements
- Dormitory contact information

---

# 21. Guardian Tenant Information

**Primary owner: Developer 2.** Guardian-link data and RLS are maintained by Developer 1.

A verified guardian may view only permitted information for linked tenants.

Recommended visible fields:

- Tenant name
- Contact information
- Room
- Bed space
- Current assignment
- Relevant emergency information
- Current contract period when permitted

---

# 22. Guardian Curfew and Gate Activity

**Primary owner: Developer 2 for Guardian UX; Developer 1 supplies verified backend events and access policies.**

## Curfew Overview

- Current Inside/Outside status
- Curfew time
- Recent verified IN/OUT activity
- Approved exceptions
- Late records

## Gate Activity

- Date/time
- Direction
- Verification type
- Event status
- Recent activity history

The current page also contains a device-usage demonstration view. If retained, it should be justified by the study scope and privacy requirements; otherwise it can be removed to keep guardian monitoring focused on dormitory-related activity.

---

# 23. Guardian Request Approval

**Primary owner: Developer 2 for Guardian decision UX; Developer 1 owns schema/RLS and the final staff-decision stage.**

Guardians review curfew requests submitted by a linked tenant.

## Available Actions

- View reason
- View destination
- View expected return
- Approve
- Reject
- Add remarks

Guardian approval does not automatically have to become the final dormitory decision. The system can maintain a second owner/caretaker decision stage.

---

# 24. Guardian Payment Status

**Primary owner: Developer 2 for read-only Guardian UX; Developer 1 owns financial records and verification.**

Read-only functions:

- Current balance
- Due dates
- Payment history
- Verification status
- Outstanding amount

Guardians should not be able to modify payment records.

---

# 25. Guardian Communication

**Primary owner: Developer 2 for Guardian UX; shared messaging contracts are coordinated with Developer 1.**

- Guardian announcements
- Direct message with owner/caretaker
- Dormitory contact information
- Emergency and safety alerts

---

# 26. Shared Pages and Settings

**Primary owner: Developer 2 for normal end-user shared pages.** Account-management and protected role/account behavior remain Developer 1-owned.

All roles can use shared pages according to permission.

## Profile

- Name
- Email
- Phone
- Role
- Role-specific information
- Room or linked-tenant information where applicable

## Settings

- Theme
- Notification settings
- Privacy and permissions
- Password management
- Device binding
- Sign out

## Notification Preferences

Allow users to enable/disable non-critical notification categories while preserving mandatory security or emergency notices where required.

## Privacy & Permissions

Display and manage permissions used by features such as:

- Notifications
- Camera/photo upload
- Location/geofence
- Biometrics
- Device identity

## Device Binding

Planned policy:

- Trusted-device registration
- Device revocation
- Verification before sensitive actions
- Audit history

---

# 27. Room and Bed Assignment Model

**Primary backend owner: Developer 1.** Developer 2 consumes the resulting assignment data in Tenant/Guardian pages.

The current backend already separates rooms, bed spaces, and assignments.

```text
Room
  ↓
Bed Space
  ↓
Tenant Assignment
  ↓
Tenant
```

## Assignment Flow

```text
Owner / Authorized Staff
        ↓
Select Tenant
        ↓
Select Room
        ↓
Select Available Bed Space
        ↓
Validate Capacity and Availability
        ↓
Create Active Assignment
```

## Database Protections Already Represented

- A tenant can have only one active bed assignment.
- A bed space can have only one active tenant assignment.
- Room capacity cannot be exceeded by bed-space count.
- A room capacity cannot be lowered below its existing bed-space count.
- An occupied bed cannot be marked unavailable.
- Only an available bed can receive an active assignment.

---

# 28. Current Live Database Foundation

**Primary owner: Developer 1.**

The current Supabase migrations create these main database objects.

## Authentication / Identity

### `auth.users`

Managed by Supabase Auth.

### `profiles`

Core application identity.

Suggested/current fields:

```text
id
full_name
role
phone
created_at
```

Roles:

```text
tenant
guardian
caretaker
owner
```

### `tenant_details`

```text
profile_id
birth_date
address
school_name
course_or_program
year_level
emergency_contact_name
emergency_contact_phone
emergency_contact_relationship
contract_starts_on
contract_ends_on
created_at
updated_at
```

### `staff_details`

```text
profile_id
employee_code
position
hired_on
is_active
created_at
updated_at
```

---

## Property / Occupancy

### `rooms`

```text
id
room_number
floor
capacity
description
created_at
updated_at
```

### `bed_spaces`

```text
id
room_id
label
status
created_at
updated_at
```

Bed-space status:

```text
available
reserved
maintenance
unavailable
```

### `tenant_assignments`

```text
id
tenant_id
bed_space_id
starts_on
ends_on
status
created_at
updated_at
```

Assignment status:

```text
active
ended
cancelled
```

---

## Guardian Relationships

### `guardian_tenant_links`

```text
id
guardian_id
tenant_id
relationship
is_primary
created_at
```

Rules:

- Guardian ID must reference a guardian profile.
- Tenant ID must reference a tenant profile.
- A guardian cannot be linked to themselves.
- Duplicate guardian/tenant links are prevented.
- A tenant may have multiple guardians.
- Only one primary guardian is allowed per tenant.
- Owner-only management is enforced in the latest migration.

---

# 29. Planned Operational Database Structure

**Primary schema/migration owner: Developer 1.** Developer 2 integrates Tenant/Guardian pages only after these contracts are agreed.

The current migrations provide the foundation. The next production tables should be added as new migrations rather than forcing unrelated data into the existing core tables.

A recommended complete schema is:

```text
auth.users
profiles
tenant_details
staff_details

guardian_tenant_links

rooms
bed_spaces
tenant_assignments
rental_contracts

billing_cycles
billing_items
payments
payment_proofs
payment_verifications

maintenance_requests
maintenance_updates
maintenance_attachments

announcements
announcement_reads

conversations
conversation_members
messages

curfew_requests
curfew_decisions

gate_events
gate_event_reviews
manual_gate_overrides

visitor_requests
visitor_logs

confidential_reports
confidential_report_updates

disciplinary_records

notifications
notification_preferences

device_bindings
verification_events

system_devices
system_health_logs

audit_logs
```

---

# 30. Important Database Relationships

**Primary owner: Developer 1 for relational integrity and RLS; both developers must follow the same relationship contracts.**

## Occupancy

```text
profiles (Tenant)
      ↓
tenant_assignments
      ↓
bed_spaces
      ↓
rooms
```

## Guardian Relationship

```text
profiles (Guardian)
      ↓
guardian_tenant_links
      ↓
profiles (Tenant)
```

## Rental and Payment

```text
Tenant
  ↓
Rental Contract
  ↓
Billing Cycle
  ↓
Billing Items
  ↓
Payment
  ↓
Payment Proof
  ↓
Verification
```

## Maintenance

```text
Tenant
  ↓
Maintenance Request
  ↓
Room / Location
  ↓
Staff Assignment / Update
  ↓
Completion
```

## Curfew

```text
Tenant
  ↓
Curfew Request
  ↓
Guardian Decision
  ↓
Staff Decision
  ↓
Approved Exception
```

## Gate

```text
Tenant
  ↓
Gate Event
  ↓
Verification / Geofence Cross-Check
  ↓
Flag Review
  ↓
Manual Override / Audit if needed
```

---

# 31. Suggested Payment Database Design

**Primary owner: Developer 1.** Developer 2 consumes these records for Tenant and Guardian payment pages.

## `billing_cycles`

Represents a tenant's bill for a period.

```text
id
tenant_id
contract_id
billing_month
due_date
total_amount
paid_amount
balance
status
created_at
updated_at
```

## `billing_items`

```text
id
billing_cycle_id
type
label
amount
notes
```

Possible types:

- Rent
- Electricity
- Water
- WiFi
- Penalty
- Damage
- Discount
- Other

## `payments`

```text
id
tenant_id
billing_cycle_id
amount
payment_method
reference_number
paid_at
status
created_at
```

## `payment_proofs`

```text
id
payment_id
storage_path
ocr_amount
ocr_reference
ocr_raw_result
uploaded_at
```

## `payment_verifications`

```text
id
payment_id
reviewed_by
decision
remarks
reviewed_at
```

---

# 32. Suggested Maintenance Database Design

**Primary owner: Developer 1 for schema/RLS; Developer 2 connects Tenant-facing creation and history.**

## `maintenance_requests`

```text
id
tenant_id
room_id
category
urgency
location_text
description
status
assigned_staff_id
created_at
updated_at
completed_at
```

## `maintenance_attachments`

```text
id
maintenance_request_id
storage_path
uploaded_at
```

## `maintenance_updates`

```text
id
maintenance_request_id
author_id
old_status
new_status
notes
created_at
```

---

# 33. Suggested Curfew and Gate Database Design

**Primary owner: Developer 1 for schema/RLS; Developer 2 connects Tenant/Guardian request and review UX.**

## `curfew_requests`

```text
id
tenant_id
reason
destination
expected_return
status
created_at
cancelled_at
```

## `curfew_decisions`

```text
id
request_id
decided_by
decider_role
decision
remarks
decided_at
```

## `gate_events`

```text
id
tenant_id
direction
occurred_at
verification_method
recognition_confidence
geofence_result
status
source_device_id
created_at
```

## `gate_event_reviews`

```text
id
gate_event_id
reviewed_by
review_status
note
reviewed_at
```

## `manual_gate_overrides`

```text
id
tenant_id
performed_by
direction
reason
occurred_at
```

---

# 34. Suggested Visitor Database Design

**Primary owner: Developer 1 for schema/RLS; Developer 2 connects Tenant request UX.**

## `visitor_requests`

```text
id
tenant_id
visitor_name
contact_number
relationship
purpose
expected_time_in
expected_time_out
status
reviewed_by
reviewed_at
created_at
```

## `visitor_logs`

```text
id
visitor_request_id
actual_time_in
actual_time_out
recorded_by
notes
```

---

# 35. Suggested Communication Database Design

**Shared feature:** Developer 1 owns protected schema/publishing rules; Developer 2 owns Tenant/Guardian communication UX.

## `announcements`

```text
id
title
body
audience
published_by
published_at
expires_at
status
```

## `announcement_reads`

```text
announcement_id
profile_id
read_at
```

## `conversations`

```text
id
created_at
updated_at
```

## `conversation_members`

```text
conversation_id
profile_id
```

## `messages`

```text
id
conversation_id
sender_id
body
sent_at
read_at
```

---

# 36. Suggested Safety Database Design

**Shared feature:** Developer 1 owns restricted schema/RLS; Developer 2 owns Tenant submission UX where applicable.

## `confidential_reports`

```text
id
submitted_by
category
summary
details
status
created_at
updated_at
```

## `confidential_report_updates`

```text
id
report_id
author_id
status
notes
created_at
```

## `disciplinary_records`

```text
id
tenant_id
incident_type
description
evidence_path
action_taken
status
recorded_by
incident_at
created_at
```

---

# 37. Notifications Database Design

**Shared feature:** Developer 1 owns backend schema/policies; Developer 2 owns user-facing preferences and notification pages.

## `notifications`

```text
id
recipient_id
type
title
body
reference_type
reference_id
is_read
created_at
read_at
```

## `notification_preferences`

```text
profile_id
payment_updates
maintenance_updates
curfew_updates
gate_updates
announcements
messages
updated_at
```

---

# 38. Audit and Security Records

**Primary owner: Developer 1.**

## `audit_logs`

For sensitive actions, record:

```text
id
actor_id
action
entity_type
entity_id
old_values
new_values
ip_or_device_context
created_at
```

Important actions to audit:

- Account creation/deletion
- Role-sensitive account changes
- Guardian linking/unlinking
- Room assignment changes
- Payment verification
- Curfew decisions
- Visitor decisions
- Gate overrides
- Confidential-report access/update
- Contract changes
- Financial adjustments

---

# 39. Row Level Security Plan

**Primary implementation owner: Developer 1.** Both developers must test that Tenant and Guardian accounts are denied unrelated records.

RLS must remain the final authority even if Flutter hides buttons.

## Tenant

Tenant may access:

- Own profile
- Own tenant details
- Own assignment/room information
- Own payments
- Own maintenance requests
- Own curfew requests
- Own visitor requests
- Own gate history
- Own confidential concerns
- Allowed announcements
- Own conversations and notifications

Tenant must not access:

- Other tenants' private data
- Guardian-only decisions unrelated to the tenant
- Staff-only financial summaries
- Full gate monitoring
- Account administration
- Confidential reports from other tenants

## Guardian

Guardian may access:

- Own profile
- Verified linked tenant information
- Linked tenant payment status
- Linked tenant curfew requests
- Linked tenant permitted gate activity
- Guardian announcements
- Own messages and notifications

Guardian must not access unrelated tenants.

## Caretaker

Caretaker may access operational data necessary for:

- Tenant operations
- Rooms
- Maintenance
- Gate
- Visitor handling
- Curfew operations
- Tenant/guardian account management

Caretaker should be restricted from owner-only finance, analytics, role administration, and other sensitive owner functions unless explicitly authorized.

## Owner

Owner receives the broadest operational access, including:

- User administration
- Guardian relationship management
- Rooms and occupancy
- Payments and finance
- Contracts
- Safety records
- Reports and analytics
- Audit review

---

# 40. Current Flutter Project Architecture

The ZIP currently uses this structure:

```text
lib/
├── main.dart
├── app.dart
│
├── controllers/
│   ├── guardian_controller.dart
│   ├── owner_controller.dart
│   ├── session_controller.dart
│   ├── tenant_controller.dart
│   └── theme_controller.dart
│
├── core/
│   ├── config/
│   │   └── supabase_config.dart
│   ├── constants/
│   ├── responsive/
│   ├── theme/
│   └── widgets/
│
├── data/
│   └── mock_data.dart
│
├── models/
│   └── models.dart
│
├── services/
│   ├── account_service.dart
│   ├── auth_service.dart
│   ├── guardian_link_service.dart
│   ├── profile_service.dart
│   └── usage_stats_service.dart
│
└── views/
    ├── auth/
    ├── caretaker/
    ├── guardian/
    ├── owner/
    ├── shared/
    ├── tenant/
    └── widgets/
```

This structure is workable for the current project, but as more backend modules become live, the project should gradually move toward feature-based repositories/services to avoid oversized page and controller files.

---

# 41. Recommended Flutter Architecture Going Forward

```text
lib/
├── main.dart
├── app.dart
│
├── core/
│   ├── config/
│   ├── constants/
│   ├── error/
│   ├── network/
│   ├── responsive/
│   ├── routing/
│   ├── theme/
│   └── widgets/
│
├── features/
│   ├── auth/
│   ├── accounts/
│   ├── profiles/
│   ├── guardians/
│   ├── rooms/
│   ├── assignments/
│   ├── payments/
│   ├── maintenance/
│   ├── gate/
│   ├── curfew/
│   ├── visitors/
│   ├── announcements/
│   ├── messaging/
│   ├── confidential_reports/
│   ├── contracts/
│   ├── finance/
│   ├── notifications/
│   └── reports/
│
└── shared/
    ├── models/
    ├── repositories/
    ├── services/
    └── widgets/
```

Each feature can contain:

```text
feature/
├── models/
├── repositories/
├── services/
├── controllers/
├── pages/
└── widgets/
```

This is a future refactor recommendation. It is not necessary to reorganize every current file before connecting the next backend feature.

---

# 42. Backend Access Pattern

**Developer 1 owns backend/security contracts. Developer 2 owns Tenant/Guardian repositories that consume those contracts.**

Because the current system uses Supabase, the preferred architecture is:

```text
Flutter UI
   ↓
Controller / State
   ↓
Repository or Service
   ↓
Supabase Client
   ├── Auth
   ├── PostgreSQL / PostgREST
   ├── Edge Functions
   ├── Storage
   └── Realtime
```

Administrative actions that require elevated privileges must use protected server-side functions and must never expose the Supabase service-role key inside Flutter.

---

# 43. Existing Protected Backend Functions

**Primary owner: Developer 1.**

The ZIP contains Edge Functions for account administration.

## `create-user`

Purpose:

- Server-side account creation
- Role validation
- Creation of matching application records

## `manage-user`

Purpose:

- List/manage authorized accounts
- Update permitted account information
- Send password recovery
- Delete accounts under protected rules

Additional Edge Functions should be added only when a task genuinely requires trusted server-side execution. Ordinary role-scoped CRUD can use Supabase tables with strong RLS.

---

# 44. Major External / Advanced Integrations

**Split ownership:** Developer 1 owns backend/service integration and protected functions; Developer 2 connects the resulting Tenant/Guardian user experience where required.

These are represented by pages or workflows in the current app but should be treated as separate production integrations.

## OCR

Purpose:

- Read uploaded payment receipts
- Extract amount/reference
- Reduce staff encoding work

The tenant must review extracted details and staff must still verify the payment.

## Geofencing

Purpose:

- Cross-check whether a tenant's registered device is within/outside the dormitory boundary
- Support curfew and gate-event verification

Geofencing should be treated as supporting evidence rather than perfect proof of the tenant's physical presence.

## Facial Recognition / Gate Camera

Purpose:

- Identify or assist in verifying IN/OUT events
- Flag mismatches for manual review

It requires explicit privacy, consent, retention, security, accuracy, and fallback policies before production use.

## IoT / Gate Device Monitoring

Purpose:

- Show camera/service health
- Detect device/connectivity failures
- Help staff distinguish a real gate anomaly from a system outage

## Biometrics / Trusted Device

Purpose:

- Add protection for sensitive account actions
- Bind a tenant account to an approved device where required

---

# 45. Core System Workflows

## A. Tenant Onboarding

```text
Staff Creates Account
      ↓
Tenant Receives Access
      ↓
Tenant Completes Verification
      ↓
Tenant Details Created
      ↓
Room / Bed Assigned
      ↓
Guardian Linked
      ↓
Contract Activated
      ↓
Tenant Dashboard Becomes Fully Active
```

## B. Monthly Billing

```text
Active Contract
      ↓
Generate Monthly Charges
      ↓
Tenant Sees Balance
      ↓
Payment Submitted
      ↓
Proof Reviewed
      ↓
Payment Approved
      ↓
Balance Updated
      ↓
Receipt / History Stored
```

## C. Maintenance

```text
Tenant Reports Issue
      ↓
Staff Reviews Priority
      ↓
Assign / Start Work
      ↓
Status Updates
      ↓
Completion
      ↓
History Preserved
```

## D. Curfew

```text
Gate OUT Event
      ↓
Tenant Outside
      ↓
Check Curfew / Exception
      ↓
Normal Return ───────────────→ Close Activity
      │
      └── Late / Unverified
              ↓
          Flag Event
              ↓
          Staff Review
```

## E. Curfew Exception

```text
Tenant Request
      ↓
Guardian Decision
      ↓
Staff Decision
      ↓
Approved Exception
      ↓
Used by Curfew Monitoring
```

## F. Visitor

```text
Tenant Request
      ↓
Staff Review
      ↓
Approved Visitor
      ↓
Arrival / Departure Log
      ↓
Visit History
```

---

# 46. Reports

**Primary owner: Developer 1 for Owner reports and export services.** Developer 2 may expose role-scoped summaries to Tenant/Guardian pages.

## Owner Reports

- Occupancy report
- Vacancy report
- Tenant report
- Room utilization
- Payment collection report
- Outstanding balances
- Revenue report
- Expense report
- Maintenance report
- Curfew report
- Gate activity report
- Visitor report
- Contract expiry report
- Confidential/safety summary with restricted detail
- Disciplinary report
- Account/audit report

## Export

- PDF
- Excel
- CSV

Sensitive reports should respect role and privacy restrictions even during export.

---

# 47. Search, Filtering, and Usability

Management pages should support filters such as:

- Tenant name
- Room
- Floor
- Occupancy
- Payment status
- Maintenance status
- Maintenance urgency
- Curfew status
- Date range
- Visitor status
- Contract expiry range

Recommended UI principles already reflected in the project:

- Compact role-specific navigation
- Bottom navigation on smaller screens
- Side navigation on wider screens
- Group owner operations into categories
- Prioritize urgent/actionable information
- Avoid exposing controls irrelevant to the current role

---

# 48. Error, Offline, and Empty States

**Shared responsibility:** each developer implements these states inside the pages and services they own.

Every production-backed page should explicitly handle:

- Loading
- Empty data
- Network error
- Authentication expiry
- Permission denied
- Invalid server response
- Retry
- Offline state where practical
- Upload failure
- Duplicate submission
- Validation error

No page should silently fall back to mock data in production.

---

# 49. Validation Rules

**Shared responsibility:** Developer 1 enforces server/database validation; each developer enforces appropriate client-side validation in owned pages.

## Accounts

- Valid email
- Strong password
- Valid role
- Role cannot be self-assigned
- Required phone/contact fields as defined by role

## Rooms

- Unique room number
- Capacity greater than zero
- Bed count cannot exceed capacity

## Assignments

- Tenant must exist and have tenant role
- Bed must be available
- One active bed per tenant
- One active tenant per bed

## Guardian Links

- Guardian must have guardian role
- Tenant must have tenant role
- Prevent duplicate link
- Only one primary guardian per tenant

## Payments

- Amount greater than zero
- Valid billing reference
- Duplicate reference checks where applicable
- Staff verification before final status

## Maintenance

- Required category
- Required location
- Required description
- Valid urgency/status transition

## Curfew

- Expected return must be logically valid
- Only linked guardian can provide guardian decision
- Only authorized staff can make final staff decision

## Visitors

- Required visitor identity
- Valid visit schedule
- Tenant owns request
- Staff owns approval decision

---

# 50. Security Requirements

**Primary backend owner: Developer 1; verification responsibility: both developers.**

- Keep RLS enabled on all private tables.
- Never rely on Flutter UI hiding as the only authorization layer.
- Never expose the Supabase service-role key in the client.
- Use protected Edge Functions for privileged account actions.
- Validate all sensitive writes server-side.
- Restrict confidential reports to authorized roles.
- Audit high-risk changes.
- Use secure Storage policies for uploaded receipts/photos.
- Use signed or protected file access where needed.
- Limit guardian access strictly to verified linked tenants.
- Prevent tenants from reading other tenants' data.
- Prevent caretakers from accessing owner-only functions unless explicitly allowed.
- Remove development/test accounts before production.
- Define data retention and deletion policies for gate images, facial data, reports, and audit logs.

---

# 51. Privacy Requirements

**Shared responsibility.** Developer 1 enforces protected access and retention controls; Developer 2 must avoid exposing sensitive Tenant/Guardian data in client UI.

Special attention is required for:

- Tenant personal information
- Guardian information
- Emergency contacts
- Location/geofence data
- Gate activity
- Facial-recognition images/templates
- Confidential concerns
- Disciplinary records
- Payment receipts
- Device-binding identifiers

The production system should use the minimum data necessary for each function and define who can access it, why it is collected, and how long it is retained.

---

# 52. Development Phases — Two-Developer Parallel Plan

The phases below follow the current ZIP and the ownership model in `DEVELOPMENT_PROGRESS.md`. They are not meant to force both developers to finish one entire phase before moving. The goal is to expose a stable backend contract from Developer 1, then let Developer 2 connect the matching Tenant/Guardian workflow in parallel.

## Phase 1 — Foundation, Authentication, and Security

### Developer 1

Already substantially implemented:

- [✓] Flutter/Supabase foundation
- [✓] Supabase email/password authentication
- [✓] Persistent session restoration
- [✓] Protected profiles and server-controlled roles
- [✓] Owner, Caretaker, Guardian, and Tenant role routing
- [✓] Role guards and initial RLS
- [✓] Protected account creation/management Edge Functions
- [✓] Owner/Caretaker account-management UI
- [✓] Guardian-to-tenant link management

Remaining:

- [ ] Complete and test password-recovery deep links
- [ ] Finish invitation/onboarding flow
- [ ] Finalize SMS/OTP policy if retained
- [ ] Add verification timestamps and retry/expiry controls where required
- [ ] Complete production access-control tests
- [ ] Keep all production role restrictions in RLS/protected server functions

### Developer 2

- [✓] Consume authenticated profile/session in Tenant and Guardian workspaces
- [✓] Shared profile identity
- [✓] Change password
- [✓] Local settings/theme
- [ ] Add permitted self-profile editing for Tenant and Guardian
- [ ] Connect notification preferences to authenticated accounts
- [ ] Add complete loading/error/offline states to owned shared pages

### Integration checkpoint

Both developers verify one test account for each role and confirm that Tenant/Guardian sessions cannot open Owner/Caretaker data or actions.

---

## Phase 2 — People, Rooms, Occupancy, and Relationships

### Developer 1

Current backend foundation:

- [✓] `profiles`
- [✓] `tenant_details`
- [✓] `staff_details`
- [✓] `rooms`
- [✓] `bed_spaces`
- [✓] `tenant_assignments`
- [✓] `guardian_tenant_links`

Next work:

- [ ] Replace Owner/Caretaker mock tenant directory with live records
- [ ] Replace mock room monitoring with live rooms and bed spaces
- [ ] Build room/bed CRUD and assignment management
- [ ] Add contract/rental-history model
- [ ] Expose stable repository/service contracts for room and linked-tenant reads

### Developer 2

- [ ] Connect Tenant `My Room` to the active assignment
- [ ] Show bed, room, roommates, capacity, and permitted utility information
- [ ] Connect Guardian `Tenant Information` to verified links only
- [ ] Add proper empty states when a Tenant has no assignment or a Guardian has no active link

### Integration checkpoint

Verify that a Tenant can read only their own assignment and a Guardian can read only linked Tenant information. Owner/Caretaker remain the only roles that can manage occupancy.

---

## Phase 3 — Billing and Payments

### Developer 1

Build the production financial backend and management workflow:

- [ ] Rental contracts
- [ ] Billing cycles
- [ ] Billing items
- [ ] Utilities
- [ ] Penalties and discounts
- [ ] Partial-payment support
- [ ] Payment records
- [ ] Payment-proof metadata
- [ ] Payment verification history
- [ ] Owner/Caretaker payment review
- [ ] Audit trail for corrections and decisions
- [ ] Dashboard payment metrics

### Developer 2

After the payment contract is frozen:

- [ ] Connect Tenant current bill and outstanding balance
- [ ] Connect Tenant payment history
- [ ] Upload payment proof to the agreed Storage bucket
- [ ] Display verification status and receipt information
- [ ] Connect Guardian read-only payment status for linked Tenants
- [ ] Handle rejected, partial, overdue, and pending-verification states

### Integration checkpoint

Test the full flow:

```text
Owner creates charge
      ↓
Tenant sees balance
      ↓
Tenant uploads payment proof
      ↓
Owner/Caretaker verifies
      ↓
Tenant and Guardian see updated status
```

---

## Phase 4 — Maintenance and Property Operations

### Developer 1

- [ ] Create maintenance request schema, attachments, updates, assignment, and resolution tables
- [ ] Apply Tenant ownership and staff-management RLS
- [ ] Connect Owner/Caretaker maintenance queues
- [ ] Connect staff assignment, status changes, and resolution notes
- [ ] Connect floor-plan monitoring and maintenance markers
- [ ] Add dashboard maintenance metrics

### Developer 2

This lane can begin as soon as the minimal request schema/RLS contract is ready; it does not need to wait for the full Owner/Caretaker maintenance UI.

- [ ] Submit Tenant maintenance requests
- [ ] Save category, urgency, description, room/location, and attachments
- [ ] Show the Tenant's own request history
- [ ] Show `Pending`, `Assigned`, `In Progress`, `Completed`, and other agreed statuses
- [ ] Connect the Tenant maintenance floor-plan location selector
- [ ] Add cancellation/edit rules only for states permitted by the shared contract

### Integration checkpoint

A Tenant-created `Pending` request must appear in the Owner/Caretaker queue without exposing other tenants' private reports to the submitting Tenant.

---

## Phase 5 — Curfew Requests, Gate Events, and Visitors

### Developer 1

- [ ] Create `curfew_requests`, guardian decisions, and staff decisions
- [ ] Create gate event/review/override tables
- [ ] Create visitor request/log tables
- [ ] Apply role-specific RLS and status transitions
- [ ] Connect Owner/Caretaker curfew review
- [ ] Connect Gate monitoring and manual override
- [ ] Connect staff visitor approval/rejection
- [ ] Add audit timestamps and decision identities

### Developer 2

The request workflows can be developed before advanced camera/geofence automation.

- [ ] Tenant creates/views/cancels unreviewed curfew requests
- [ ] Guardian views requests from an already-linked Tenant
- [ ] Guardian approves/rejects with remarks and timestamp
- [ ] Show `Awaiting staff decision` after Guardian approval when applicable
- [ ] Tenant creates/views/cancels unreviewed visitor requests
- [ ] Connect Tenant Gate & Curfew overview to verified events
- [ ] Connect Guardian Curfew Overview and Gate Activity to linked-Tenant events only

### Integration checkpoint

```text
Tenant curfew request
       ↓
Guardian decision
       ↓
Owner/Caretaker final decision
       ↓
Tenant + Guardian see final result
```

Manual/test gate events should be proven first. Camera, facial recognition, and geofence automation are later enhancements, not prerequisites for this workflow.

---

## Phase 6 — Communication, Notifications, and Safety

### Developer 1

- [ ] Create announcement and audience-targeting backend
- [ ] Connect Owner/Caretaker announcement publishing
- [ ] Create protected conversation/message contracts
- [ ] Create notification records and delivery triggers
- [ ] Create confidential-report tables with strict staff-only access
- [ ] Create disciplinary-record backend
- [ ] Add audit logging for sensitive staff access/actions

### Developer 2

- [ ] Connect Tenant/Guardian announcements
- [ ] Connect Tenant/Guardian conversations and message history
- [ ] Connect notifications and deep links
- [ ] Persist Tenant/Guardian notification preferences
- [ ] Submit Tenant confidential concerns
- [ ] Show only the submitting Tenant's permitted confidential-report state/history
- [ ] Connect Guardian emergency/safety alerts where the backend audience permits it

### Integration checkpoint

Test announcement audiences, conversation membership, notification ownership, and confidential-report denial rules across all roles.

---

## Phase 7 — Advanced Verification and Automation

These features come only after the core manual workflows are reliable.

### Developer 1

- [ ] OCR/payment extraction backend
- [ ] Geofence event/service integration
- [ ] Gate camera/facial-recognition integration
- [ ] IoT/device health monitoring
- [ ] Trusted-device backend
- [ ] SMS verification service if retained
- [ ] Push-notification backend
- [ ] Manual fallback and failure logging for every automation

### Developer 2

- [ ] Integrate OCR results into the Tenant payment-proof experience without treating OCR as authoritative
- [ ] Display geofence/gate verification state to Tenant/Guardian only when permitted
- [ ] Connect verification/device-binding pages
- [ ] Handle unavailable, denied-permission, timeout, and fallback states
- [ ] Keep the normal request/payment/gate flows usable when automation fails

### Integration checkpoint

No automated result should bypass RLS, staff authority, audit logging, or the manual fallback path.

---

## Phase 8 — Finance, Contracts, Reports, and Analytics

### Developer 1

Primary phase owner:

- [ ] Income records
- [ ] Expense records
- [ ] Contract expiry and renewal workflow
- [ ] Occupancy analytics
- [ ] Payment compliance analytics
- [ ] Maintenance analytics
- [ ] Curfew/gate analytics
- [ ] Visitor analytics
- [ ] Owner dashboard metrics
- [ ] PDF export
- [ ] Excel export
- [ ] CSV export

### Developer 2

Supporting user-facing work:

- [ ] Ensure Tenant/Guardian summary cards use the same live records and status definitions
- [ ] Expose only role-appropriate history/summary views
- [ ] Add navigation/deep links from notifications into the correct record

---

## Phase 9 — Testing and Production Hardening

### Developer 1

- [ ] RLS/access-control tests for every production table
- [ ] Edge Function tests
- [ ] Owner/Caretaker integration tests
- [ ] Storage policy tests
- [ ] Audit-log verification
- [ ] Backup/recovery plan
- [ ] Security and privacy review
- [ ] Remove development-only provisioning paths and test accounts

### Developer 2

- [ ] Tenant widget/integration tests
- [ ] Guardian widget/integration tests
- [ ] Shared-page tests
- [ ] Offline/network/error-state tests
- [ ] Phone/tablet/wide-screen tests for owned interfaces
- [ ] Verify no owned production page depends on `MockData`

### Joint final tests

- [ ] Full Tenant → Guardian → Caretaker/Owner workflow tests
- [ ] Session expiry and sign-out
- [ ] Password recovery
- [ ] Permission denial
- [ ] File upload failures
- [ ] Realtime reconnection
- [ ] Cross-role privacy checks
- [ ] Performance and release build validation

---

# 53. Recommended Two-Developer Implementation Priority

The order below minimizes blocking and merge conflicts.

## Developer 1 Priority

```text
1. Finish authentication recovery/onboarding/security
2. Freeze shared table/model/status conventions
3. Finish live rooms + assignments management
4. Create maintenance request schema/RLS
5. Create curfew + visitor schema/RLS
6. Create billing + payment schema/RLS
7. Create announcements/messages/notifications schema/RLS
8. Connect Owner/Caretaker operational pages
9. Add confidential/safety/disciplinary backend
10. Add contracts + owner finance + analytics
11. Add advanced automation services
12. Complete RLS/security/production testing
```

## Developer 2 Priority

The first items are intentionally features that can proceed with minimal dependence on completed Owner/Caretaker pages.

```text
1. Permitted Tenant/Guardian self-profile editing
2. Tenant maintenance submission + own history
3. Tenant curfew submission + Guardian approval/rejection
4. Tenant visitor submission + cancellation
5. Tenant confidential-concern submission
6. Tenant/Guardian notification preferences
7. My Room + linked-Tenant information
8. Tenant payments + proof upload + Guardian payment status
9. Announcements + messaging + notifications
10. Gate/curfew live event views
11. Advanced verification UX
12. Tenant/Guardian production testing and MockData removal
```

## Shared Integration Checkpoints

```text
A. Auth/Profile contract
B. Rooms/Assignments contract
C. Maintenance contract
D. Curfew/Visitor contract
E. Billing/Payments contract
F. Messaging/Notifications contract
G. Advanced integrations
H. Final cross-role testing
```

At each checkpoint, Developer 1 supplies or confirms the backend contract and RLS behavior before Developer 2 merges the corresponding live-data integration.

---

# 54. Current ZIP Status Summary by Developer

## Developer 1 — Live / Connected

- [✓] Supabase initialization
- [✓] Supabase email/password authentication
- [✓] Session restoration
- [✓] Protected role lookup
- [✓] Four-role routing and guards
- [✓] Change-password backend support
- [✓] Protected `profiles`
- [✓] `tenant_details`
- [✓] `staff_details`
- [✓] Core `rooms`
- [✓] Core `bed_spaces`
- [✓] Core `tenant_assignments`
- [✓] `guardian_tenant_links`
- [✓] Owner/Caretaker account management
- [✓] Owner-only guardian-link management
- [✓] RLS foundation
- [✓] Server-side user-management functions

## Developer 1 — UI Exists but Operational Backend Is Mostly Mock

- [ ] Owner dashboard metrics
- [ ] Owner/Caretaker tenant operational data
- [ ] Room monitoring and management data
- [ ] Interactive floor-plan operational records
- [ ] Payment verification
- [ ] Maintenance management
- [ ] Gate monitoring/manual override
- [ ] Curfew staff review
- [ ] Visitor approval
- [ ] Confidential-report management
- [ ] Staff announcements
- [ ] Staff messaging
- [ ] Contract expiry
- [ ] Income/expenses
- [ ] Disciplinary records
- [ ] Reports/analytics
- [ ] Device/service monitoring

## Developer 2 — Live / Complete

- [✓] Tenant/Guardian sign-in through shared authentication
- [✓] Tenant/Guardian authenticated profile identity
- [✓] Guardian linked-tenant identity on Profile
- [✓] Change password
- [✓] Settings/theme local state
- [✓] Rules and policies
- [✓] Dormitory information

## Developer 2 — UI Exists but Mostly Mock / Local

- [ ] Tenant dashboard and My Room
- [ ] Tenant payments/history
- [ ] Payment-proof upload/OCR flow
- [ ] Tenant reports hub
- [ ] Tenant maintenance submission/history/floor plan
- [ ] Tenant announcements
- [ ] Tenant messages
- [ ] Tenant gate/curfew
- [ ] Tenant curfew exceptions
- [ ] Tenant visitor requests
- [ ] Tenant confidential concerns
- [ ] Guardian dashboard
- [ ] Guardian curfew/gate activity
- [ ] Guardian curfew review
- [ ] Guardian payment status
- [ ] Guardian announcements/messages
- [ ] Guardian emergency/safety alerts
- [ ] Notifications
- [ ] Notification preferences persistence
- [ ] Privacy/permission state
- [ ] Device binding/verification code

A feature should be called **fully implemented** only when its persistence, authorization, validation, error handling, role isolation, and required tests are connected—not merely because its UI exists.

---

# 55. Branch, Handoff, and Merge Rules

To keep two developers productive without repeatedly editing the same files:

- Developer 1 remains the owner of Supabase migrations and Edge Functions.
- Developer 2 should use a dedicated Tenant/Guardian feature branch such as `feature/tenant-guardian-live-data`.
- Existing applied migrations should not be rewritten; create a new migration for changes.
- Never place the Supabase service-role key in Flutter code, assets, or client configuration.
- All role restrictions must be enforced server-side through RLS or protected functions, not only hidden in UI.
- Shared model/status changes must be agreed before either developer integrates them.
- Each pull request should update implementation/progress documentation for completed features.
- Developer 2 must test with both Tenant and Guardian accounts.
- Developer 1 must test Owner/Caretaker actions and explicitly verify that Tenant/Guardian accounts are denied the same protected operations.
- Cross-role workflows should be merged only after both ends use the same status values and database contract.

### Recommended Git ownership pattern

```text
Developer 1 branches
├── feature/backend-<module>
├── feature/owner-<module>
└── feature/caretaker-<module>

Developer 2 branches
├── feature/tenant-<module>
├── feature/guardian-<module>
└── feature/shared-user-<module>

Integration
└── Pull request → main/development branch after contract + role tests
```

---

# 56. Final System Scope

The complete CarmeLink system should provide one coordinated workflow for four parties while preserving the two-developer ownership split during implementation:

```text
DEVELOPER 1
OWNER
Full administration, finance, safety, reports, accounts
        │
CARETAKER
Daily tenant, room, maintenance, gate, and account operations
        │
        ├──────────── Shared Supabase backend + RLS ────────────┐
        │                                                       │
DEVELOPER 2                                                     │
TENANT                                                          │
Payments, room, maintenance, gate/curfew, visitors, reports     │
        │                                                       │
GUARDIAN                                                        │
Linked-tenant monitoring, approvals, payment status, messages ──┘
```

All four roles connect to the same protected Supabase backend and relational database.

The implementation principle is:

> **Developer 1 owns the management side and backend/security foundation; Developer 2 owns the Tenant/Guardian user side; both integrate through agreed database, RLS, model, and status contracts.**

The system principle remains:

> **One Flutter system, one backend, one relational database, strict role-based access, and one source of truth for tenant, room, payment, maintenance, gate, curfew, visitor, guardian, and communication records.**

Advanced features such as OCR, geofencing, facial recognition, IoT monitoring, and biometrics should support the core dormitory workflows rather than replace them.

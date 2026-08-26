# CarmeLink

CarmeLink is a Flutter dormitory-management app for Carmelita's Dormitory. It gives tenants, guardians, and dormitory staff role-specific tools for payments, maintenance, gate activity, curfew, visitors, announcements, and communication.

This README is a guide to every user-facing page currently implemented in the app.

## Contents

- [Getting started](#getting-started)
- [Demo sign-in](#demo-sign-in)
- [Navigation](#navigation)
- [Authentication pages](#authentication-pages)
- [Tenant pages](#tenant-pages)
- [Guardian pages](#guardian-pages)
- [Owner and caretaker pages](#owner-and-caretaker-pages)
- [Shared pages](#shared-pages)
- [Project structure](#project-structure)
- [Implementation status](#implementation-status)

## Getting started

### Requirements

- Flutter with Dart `>=3.3.0 <4.0.0`
- A configured Flutter device, emulator, browser, or desktop target

### Run and check the app

```bash
flutter pub get
flutter run
```

```bash
flutter analyze
flutter test
```

## Demo sign-in

The current build uses mock authentication. Enter any non-empty password and use the email to choose a role:

| Role | Example email | Result |
|---|---|---|
| Owner / Caretaker | `owner@example.com` | Opens the staff workspace |
| Guardian | `guardian@example.com` | Opens the guardian workspace |
| Tenant | `tenant@example.com` | Opens the tenant workspace |

Emails containing `owner` or `caretaker` become staff accounts. Emails containing `guardian` or `parent` become guardian accounts. All other non-empty emails become tenant accounts.

Most records are local demo data. Form submissions, messages, approvals, and status changes demonstrate the intended experience but are not production-backed persistence.

## Navigation

CarmeLink selects a workspace after sign-in. Compact screens use bottom navigation; wider screens show the same five destinations in side navigation.

| Tenant | Guardian | Owner / Caretaker |
|---|---|---|
| Home | Home | Dashboard |
| Payments | Curfew | Tenants |
| Reports | Requests | Operations |
| Gate | Messages | Gate |
| Profile | Profile | Profile |

Cards, shortcuts, and action buttons open the supporting pages described below.

## Authentication pages

### Splash

Displays the CarmeLink brand while the authentication experience loads.

### Welcome

Introduces Carmelita's Dormitory and the app's role-based experience, then leads to sign-in.

### Sign in

Accepts an email and password, validates that both are present, and opens the appropriate role workspace. It also links to password recovery.

### Reset password

Accepts a valid email address and simulates sending account-recovery instructions.

## Tenant pages

### Main navigation

#### Home

Summarizes room assignment, amount due, gate status, urgent items, the latest maintenance issue, and a recent announcement. Quick actions open payment-proof upload, maintenance reporting, curfew exceptions, and visitor registration.

#### Payments & utilities

Shows the outstanding balance, next due date, and payment history. **Upload proof** starts receipt submission.

#### Reports

Combines maintenance and confidential reporting. It summarizes report counts, shows recent maintenance progress, and links to both reporting workflows.

#### Gate & curfew

Shows whether the tenant is inside or outside, curfew time, late-record count, and recent verified gate activity. It links to curfew-exception and visitor requests.

#### Profile

Shows the tenant's contact information and room assignment, with access to Settings.

### Supporting pages

#### My room

Presents the room number, floor, bed space, occupancy, utilities, and amenities.

#### Upload payment proof

Guides the tenant through selecting a receipt, simulating OCR extraction, reviewing the amount and reference, and sending the proof for staff verification.

#### Maintenance reports

Lists submitted issues and progress, with counts for open and high-priority work. **Report issue** opens a new submission.

#### Submit maintenance report

Collects the issue category, urgency, exact location, and description. The floor-plan helper can identify the location.

#### Interactive floor plan

Provides a visual selector for attaching a precise dormitory location to a maintenance issue.

#### Confidential concern

Privately collects safety, rules, or roommate concerns, explains restricted access, and shows previously submitted confidential reports.

#### Announcements

Lists dormitory notices and reminders for tenants.

#### Messages

Shows available contacts. Selecting the caretaker opens a conversation.

#### Tenant conversation

Displays message history with the owner/caretaker and includes a demo message composer.

#### Curfew exception

Collects the reason, destination, and return information for an exception and indicates that guardian confirmation is required.

#### Visitor request

Registers an expected visitor's name, relationship, and schedule for review.

#### Rules & policies

Provides a quick reference for curfew, payment, safety, and access rules.

## Guardian pages

### Main navigation

#### Home

Summarizes the linked tenant's gate status, outstanding payment, pending approvals, and notices. Quick links open tenant information, payments, announcements, and contact details.

#### Curfew

Shows the linked tenant's current curfew status and recent verified IN/OUT activity.

#### Requests

Lists curfew exceptions needing guardian input. Review the reason, destination, and return time, then approve or reject in the demo workflow.

#### Messages

Shows dormitory contacts and opens a direct caretaker conversation.

#### Profile

Displays guardian details and the linked tenant, with access to Settings.

### Supporting pages

#### Tenant information

Provides the linked tenant's identity, contact, and room-assignment details.

#### Gate activity

Shows daily device usage and detailed, verified gate events.

#### Payment status

Shows the linked tenant's balance, due dates, and payment-verification state.

#### Announcements

Lists notices relevant to guardians.

#### Guardian conversation

Displays caretaker message history and a demo message composer.

#### Dormitory contact info

Provides office hours, dormitory contacts, and emergency details.

## Owner and caretaker pages

### Main navigation

#### Dashboard

Prioritizes daily operations. It summarizes occupancy, pending payment reviews, maintenance, and gate alerts, then highlights expiring contracts and flagged events.

#### Tenants

Provides a searchable tenant directory. Selecting a tenant opens their full record.

#### Operations

Is the staff control center. Search and filter shortcuts to room, payment, maintenance, curfew, visitor, announcement, messaging, contact, system, finance, discipline, and analytics tools.

#### Gate monitoring

Displays facial-recognition events with geofence checks, service health, and alerts. Staff can review flags or open a manual override.

#### Profile

Shows staff contact details, access level, management shortcuts, and Settings.

### Tenant and room management

#### Tenant details

Shows room, phone, guardian contact, payment state, and gate status for one tenant, with links to payment verification, gate logs, and confidential reports.

#### Room monitoring

Displays a visual room board and occupied/available bed counts for vacancy monitoring.

#### Contract expiry alerts

Highlights contracts ending soon for renewal or move-out planning. Live contract data still requires backend integration.

#### Disciplinary records

Is the intended record of verified violations and issued notices by tenant. It currently shows a demo empty state.

### Payments and reporting

#### Payment review

Lists receipt submissions awaiting verification. Staff compare OCR-extracted tenant, amount, and reference details, then confirm or correct the status.

#### Expense & income summary

Shows collected rent, outstanding balances, and penalties for the current monthly snapshot. Full financial data requires a backend.

#### Reports & analytics

Summarizes occupancy, payment compliance, open maintenance, and curfew flags. Detailed analytics require backend integration.

### Maintenance

#### Maintenance management

Lists pending, ongoing, and completed reports. Selecting one opens its details and controls.

#### Maintenance details

Shows category, urgency, location, description, creation date, and status, and provides demo workflow updates.

#### Floor plan monitoring

Maps active maintenance concerns to dormitory locations.

### Gate, curfew, and visitors

#### Manual gate override

Records an authorized manual gate action, affected person, and reason for an audit trail.

#### Curfew monitoring

Summarizes tenants outside, approved exceptions, and late arrivals and links to request review.

#### Curfew request review

Shows each reason, destination, guardian response, and return time and allows the staff decision.

#### Visitor management

Lists expected visitors, relationships, schedules, and permission states for staff approval or rejection.

### Communication, safety, and systems

#### Confidential reports

Provides an authorized-only view of sensitive tenant concerns.

#### Announcements

Lets staff create and publish notices and view earlier announcements.

#### Messages

Lists tenant and guardian conversations.

#### Owner conversation

Displays a selected conversation, participant role, history, and message composer.

#### Dormitory contact directory

Lists guardian and emergency contacts for internal reference.

#### System status

Shows camera, recognition processor, and connectivity health for gate-monitoring equipment.

## Shared pages

#### Notifications

Displays payment, gate, maintenance, and request updates ranked by urgency.

#### Settings

Centralizes theme, notifications, privacy, password, trusted-device, and sign-out controls.

#### Notification preferences

Enables or disables categories of app updates.

#### Privacy and permissions

Shows and controls the device permissions used by CarmeLink workflows.

#### Change password

Validates the credential fields and demonstrates a password update.

#### Device binding

Explains the one-tenant-account, one-trusted-device policy and provides device/biometric setup.

#### Verification code

Accepts a one-time code for account or device verification.

#### Dormitory information

Introduces Carmelita's Dormitory and lists its type, room setup, and location.

## Project structure

```text
lib/
├── app.dart                 # Bootstrap, theme, and role routing
├── controllers/             # Session, theme, and role state
├── core/                    # Constants, responsive layout, theme, widgets
├── data/mock_data.dart      # Local demonstration records
├── models/models.dart       # Models and enums
├── services/                # Mock authentication and usage statistics
└── views/
    ├── auth/                # Entry and recovery pages
    ├── guardian/            # Guardian shell and pages
    ├── owner/               # Staff shell and pages
    ├── shared/              # Profile, settings, notifications
    └── tenant/              # Tenant shell and pages
```

Branding, photos, and the custom font are in `assets/`. Platform runners are included for Android, iOS, web, Windows, macOS, and Linux.

## Implementation status

- Authentication uses `MockAuthService`, not production authentication.
- Operational records primarily come from `lib/data/mock_data.dart` and in-memory controllers.
- Supabase is included as a dependency and configuration scaffold, but the documented demo workflows should not be assumed to persist remotely.
- OCR, facial recognition, geofencing, biometrics, device binding, and IoT monitoring are simulated product workflows/status interfaces pending production integrations.
- Some finance, contract, discipline, and analytics pages explicitly mark where backend data is required.

Before release, connect secured backend services, enforce server-side role permissions, add persistent uploads and messaging, test device permissions, and replace demo records with validated live data.

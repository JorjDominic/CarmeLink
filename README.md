# CarmeLink

CarmeLink is a Flutter dormitory-management app for Carmelita's Dormitory. It gives tenants, guardians, and dormitory staff role-specific tools for payments, maintenance, gate activity, curfew, visitors, announcements, and communication.

This README is a guide to every user-facing page currently implemented in the app.
Development assignments and completion status are tracked separately in
[`DEVELOPMENT_PROGRESS.md`](DEVELOPMENT_PROGRESS.md).

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
- [Recommended account provisioning](#recommended-account-provisioning)
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

## Test sign-in

The app uses Supabase Auth and loads authorization roles from the protected
`public.profiles` table. After running the migration and one-time provisioner,
use these development accounts:

| Role | Example email | Result |
|---|---|---|
| Owner | `owner@carmelita.test` | Opens the full administration workspace |
| Caretaker | `caretaker@carmelita.test` | Opens the operational workspace |
| Guardian | `guardian@carmelita.test` | Opens the guardian workspace |
| Tenant | `tenant@carmelita.test` | Opens the tenant workspace |

All four accounts initially use `CarmeLinkTest123!`. Remove the test users and
the provisioning function before production. A user cannot select or update
their own role from the client.

Most records are local demo data. Form submissions, messages, approvals, and status changes demonstrate the intended experience but are not production-backed persistence.

## Navigation

CarmeLink selects a workspace after sign-in. Compact screens use bottom navigation; wider screens show the same five destinations in side navigation.

| Tenant | Guardian | Caretaker | Owner |
|---|---|---|---|
| Home | Home | Tenants | Dashboard |
| Payments | Curfew | Rooms | Tenants |
| Reports | Requests | Maintenance | Operations |
| Gate | Messages | Gate | Gate |
| Profile | Profile | Profile | Profile |

Cards, shortcuts, and action buttons open the supporting pages described below.
Messages and Notifications are also available from the role menu with consistent outlined navigation icons.

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

Prioritizes daily operations. A compact four-card status row summarizes occupancy, pending payment reviews, maintenance, and gate alerts, then highlights expiring contracts and flagged events.

#### Tenants

Provides a searchable tenant directory. Selecting a tenant opens their full record.

#### Operations

Is the compact staff control center. Instead of presenting every tool in one long list, it groups related work into four searchable management areas:

- **Property** — rooms, the interactive floor plan, maintenance, and system status
- **Tenants & Safety** — curfew, visitors, confidential reports, and disciplinary records; the tenant directory remains a primary navigation destination
- **Finance & Contracts** — payment review, income and expenses, contract expiry, and analytics
- **Communication** — announcements, messages, and important contacts

Selecting an area opens a focused page containing its related pages. Each management card includes a short description, its connected-page count, and a live pending-work count when applicable. Searches match both category names and the tools within them. Admins can use the visible `+` button beside **Quick access** to add or remove any Operations tool. Urgent Dashboard shortcuts still open their corresponding tools directly.

#### Gate monitoring

Displays facial-recognition events with geofence checks, service health, and alerts. Staff can review flags or open a manual override.

#### Profile

Shows staff contact details, access level, management shortcuts, and Settings.

### Tenant and room management

#### Tenant details

Shows room, phone, guardian contact, payment state, and gate status for one tenant, with links to payment verification, gate logs, and confidential reports.

#### Room monitoring

Displays a visual room board and occupied/available bed counts for vacancy monitoring.

#### Interactive admin floor plan

Provides a sample two-dimensional layout for the ground and second floors. Staff can:

- Switch between floors
- Pan, pinch to zoom, use dedicated zoom controls, or reset the view
- Search for a room number and open a full-screen map
- Switch between occupancy and maintenance display modes
- Select a room to inspect its capacity, occupancy, availability, and description
- View open-maintenance markers on affected rooms
- Use a bottom detail sheet on phones or a side detail panel on wider screens
- Distinguish available rooms, full rooms, corridors, shared spaces, stairs, and entrances

The floor plan currently uses demonstration room positions. Occupancy and maintenance status come from the same owner data used by room monitoring and maintenance management, keeping the administrative views consistent. Persistent property records still require backend integration.

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
    ├── owner/               # Staff shell, grouped operations, and floor plan
    ├── shared/              # Profile, settings, notifications
    └── tenant/              # Tenant shell and pages
```

Branding, photos, and the custom font are in `assets/`. Platform runners are included for Android, iOS, web, Windows, macOS, and Linux.

## Recommended account provisioning

CarmeLink should not offer public registration. Dormitory accounts provide access to private tenant, guardian, payment, and gate information, so account creation should remain under staff control.

### Create the first owner account

The recommended first-time setup is:

1. Open **Supabase Dashboard → Authentication → Users → Add user**.
2. Create the first owner account with a temporary password, or send an invitation to the owner's email address.
3. Copy the Auth user's generated UUID.
4. Use the Supabase SQL Editor to add a matching record to the application's `public.profiles` table with the `owner` role.
5. Sign in as the owner and require a password change if a temporary password was used.
6. Keep public sign-up disabled.

Do not manually insert the login into `auth.users`. Supabase manages that schema and expects internal authentication and identity fields to be created through its Dashboard or Auth API. SQL should be used for the application's profile, role, and dormitory records after the Auth user exists.

An example application-profile record is:

```sql
insert into public.profiles (
  id,
  full_name,
  role,
  phone
)
values (
  'PASTE-AUTH-USER-UUID-HERE',
  'Carmelita Admin',
  'owner',
  '+63 917 000 0001'
);
```

The exact columns must match the final database schema. The profile ID should reference `auth.users.id` and use `on delete cascade`.

### Create later accounts from CarmeLink

After the first owner exists, add an **Account Management** area to the Owner/Caretaker workspace. The recommended workflow is:

1. An authorized staff member enters the new user's information.
2. The Flutter app calls a protected Supabase Edge Function.
3. The Edge Function uses the server-side Auth Admin API to create or invite the user.
4. The function creates the matching profile and tenant, guardian, or staff record.
5. The new user follows the invitation link or signs in with a temporary password.
6. On first sign-in, the user sets a new password and may bind a trusted device.

The Supabase secret/service-role key must only exist in a trusted server environment such as an Edge Function. It must never be included in the Flutter source, app assets, or client configuration.

Recommended permissions:

| Role | Create tenants | Create guardians | Create caretakers | Create owners |
|---|---:|---:|---:|---:|
| Owner | Yes | Yes | Yes | Restricted |
| Caretaker | Yes | Yes | No | No |
| Tenant | No | No | No | No |
| Guardian | No | No | No | No |

Authentication accounts and dormitory profiles should remain separate but linked by the Auth user UUID. This lets authentication credentials change without affecting room assignments, contracts, payment records, or guardian relationships.

For implementation details, see the official [Supabase user invitation guide](https://supabase.com/docs/guides/auth/users) and [Admin create-user documentation](https://supabase.com/docs/reference/javascript/auth-admin-createuser).

## Implementation status

- Authentication uses Supabase Auth. Role routing is based on a protected
  profile record rather than email text or client metadata.
- Operational records primarily come from `lib/data/mock_data.dart` and in-memory controllers.
- Supabase is included as a dependency and configuration scaffold, but the documented demo workflows should not be assumed to persist remotely.
- OCR, facial recognition, geofencing, biometrics, device binding, and IoT monitoring are simulated product workflows/status interfaces pending production integrations.
- Some finance, contract, discipline, and analytics pages explicitly mark where backend data is required.

Before release, connect secured backend services, enforce server-side role permissions, add persistent uploads and messaging, test device permissions, and replace demo records with validated live data.

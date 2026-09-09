# CarmeLink Development Progress

Last updated: September 7, 2026

This file tracks development separately from the README. Page ownership is
divided between two developers to reduce merge conflicts.

## Status legend

- [x] UI/page implemented
- [ ] Not yet completed
- **Live** — connected to Supabase
- **Mock** — uses local demonstration data or a simulated workflow

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

- [x] Splash, welcome, sign-in, and forgot-password pages
- [x] Show/hide-password toggle
- [x] Supabase email/password login — **Live**
- [x] Persistent session restoration — **Live**
- [x] Server-controlled role lookup — **Live**
- [x] Separate role routing for tenant, guardian, caretaker, and owner
- [x] Protected profiles table and row-level security
- [x] Explicit anonymous-access revocation and authenticated privileges
- [x] Role guards around all four role workspaces
- [x] Separate caretaker operational navigation
- [x] Owner-only authorization helper for restricted future tables
- [x] Live role-access checks for anonymous and authenticated accounts
- [x] One test account for each role
- [ ] Complete password-recovery redirect/deep-link flow
- [ ] Add table-specific RLS as backend features are connected
- [ ] Complete production access-control testing

### Owner and Caretaker pages

- [x] Dashboard — **Mock**
- [x] Tenant directory and tenant details — **Mock**
- [x] Operations hub and category pages — **Mock**
- [x] Room monitoring and interactive floor plan — **Mock**
- [x] Payment verification — **Mock**
- [x] Maintenance management and floor monitoring — **Mock**
- [x] Gate monitoring and manual override — **Mock**
- [x] Curfew monitoring and request review — **Mock**
- [x] Visitor management — **Mock**
- [x] Confidential reports — **Mock**
- [x] Announcements — **Mock**
- [x] Messaging and conversations — **Mock**
- [x] Emergency contacts and system status — **Mock**
- [x] Contracts, finance, discipline, and analytics — **Mock**

### Developer 1 next tasks

- [x] Create core profile, room, bed-space, assignment, and guardian-link tables
- [x] Add core foreign keys, validation, indexes, and RLS policies
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

- [x] Home/dashboard and My Room — **Mock**
- [x] Payments and payment history — **Mock**
- [x] Payment-proof upload — **Mock**
- [x] Reports hub — **Mock**
- [x] Maintenance list, submission, and floor plan — **Mock**
- [x] Announcements — **Mock**
- [x] Messages and conversation — **Mock**
- [x] Gate and curfew overview — **Mock**
- [x] Curfew-exception request — **Mock**
- [x] Visitor request — **Mock**
- [x] Confidential concern — **Mock**
- [x] Rules and policies

### Guardian pages

- [x] Home/dashboard and linked-tenant information — **Mock**
- [x] Curfew overview and gate activity — **Mock**
- [x] Curfew-request review — **Mock**
- [x] Payment status — **Mock**
- [x] Announcements — **Mock**
- [x] Messages and conversation — **Mock**
- [x] Emergency and safety alerts — **Mock**

### Shared pages

- [x] Profile, notifications, and settings
- [x] Notification preferences — **Mock/local state**
- [x] Privacy and permissions — **Mock/local state**
- [x] Change-password UI — connection still required
- [x] Device binding and verification code — **Mock**
- [x] Dormitory information

### Developer 2 next tasks

- [ ] Connect tenant data to tables prepared by Developer 1
- [ ] Connect guardian-to-tenant relationships
- [ ] Store payment proofs in Supabase Storage
- [ ] Persist maintenance, visitor, curfew, and confidential reports
- [ ] Connect announcements and real-time messaging
- [ ] Connect password changes and notification preferences
- [ ] Verify tenants can access only their own records
- [ ] Verify guardians can access only their linked tenant

## Shared integration tasks

- [x] Standardize roles as `tenant`, `guardian`, `caretaker`, and `owner`
- [x] Create and verify one test login for each role
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

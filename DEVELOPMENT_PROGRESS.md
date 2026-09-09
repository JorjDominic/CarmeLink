# CarmeLink Development Progress

Last updated: September 7, 2026

This file tracks development separately from the README. Page ownership is
divided between two developers to reduce merge conflicts.

## Status legend

- [✓] Completed and connected, or fully complete as a static feature
- [ ] Incomplete, including UI that still uses mock data
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
- [ ] Add table-specific RLS as backend features are connected
- [ ] Complete production access-control testing

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
- [ ] Emergency contacts and system status — UI implemented, **Mock**
- [ ] Contracts, finance, discipline, and analytics — UI implemented, **Mock**

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

- [ ] Home/dashboard — UI implemented, **Mock**
- [✓] Linked-tenant identity on Profile — **Live**
- [ ] Curfew overview and gate activity — UI implemented, **Mock**
- [ ] Curfew-request review — UI implemented, **Mock**
- [ ] Payment status — UI implemented, **Mock**
- [ ] Announcements — UI implemented, **Mock**
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

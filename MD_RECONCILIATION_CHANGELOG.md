# CarmeLink Markdown Reconciliation — September 27, 2026

Original audited base: `main` at `13b5b28` (`MD file updated`)

Current recheck: `main` at `514d116` on September 27, 2026.

## Current-build recheck

The following later commits/features were reconciled into the maintained docs:

- Android/iOS native polygon and official-gate crossing confirmation
- Editable/versioned gate-corridor configuration and 75% corridor reduction
- Authenticated-user FCM token claim RPC
- Direct/resumable tenant onboarding, safety gates, document submission,
  touchscreen signature, and audited billing actions
- iOS permission timing and recoverable native location error handling
- Local verification refreshed to zero analyzer issues and 427 passing tests

The recheck also confirms that the obsolete shared-header notification page,
device-binding placeholder, feedback persistence, phone launcher placeholder,
branch-locked readiness script, remote security matrix, release signing, and
physical-device verification remain open.

## Purpose

Earlier Japle Ligaya commits were merged into `main` before every planning/status
Markdown file was updated. These four files were reconciled against the current
source tree, migrations, tests, and Git history.

A checked item in this reconciliation means the corresponding implementation is
present in repository source/history. It does **not** automatically mean remote
Supabase deployment, RLS/Storage/Realtime production verification, physical-device
verification, or release hardening has passed.

## Files updated

- `STATUS.md`
- `DEVELOPMENT_PROGRESS.md`
- `SYSTEM_COMPLETION_AUDIT.md`
- `CARMELINK_FULL_SYSTEM_PLAN.md`

## Source-confirmed work marked complete

- Tenant maintenance CRUD, photos, history, floor-plan location, pending edit/cancel
- Visitor request/review/history and confirmed advance scheduling/visiting-hours policy
- Bed-based cleaning schedules and private missed-duty reporting
- Monthly/follow-up room inspections with notice, evidence, findings, corrective actions
- Conduct cases, evidence, responses, warnings, history, and appeals
- Non-destructive retention settings/configuration
- Tenant My Room live assignment/roommate/capacity/utility views
- Guardian linked-tenant room/payment views and empty states
- Tenant billing/payment history and payment-proof submission
- On-device receipt OCR integrated into payment-proof UX
- Tenant/Guardian announcements
- Role-scoped persistent messaging
- Reports/PDF infrastructure and source-level web/staff surfaces
- Representative responsive layout testing
- Removal of production `MockData` dependencies
- Existing curfew/gate user-facing views were marked source-live in older Developer 2 checklists, while current ownership remains reserved to Jorj

## Intentionally left open

- `STATUS.md` Tasks 1–5
- `STATUS.md` UI-1–UI-6
- Move-out / settlement end-to-end workflow
- Tenant/Guardian permitted self-profile editing
- Persisted notification preferences
- In-app notification deep-link navigation
- Guardian emergency/personal alert persistence/scheduling
- Device binding production behavior
- Remote migration/RLS/RPC/Storage/Realtime/staging verification
- Android production signing/AAB and operational readiness
- Automated retention deletion/anonymization (explicitly deferred / disabled)
- Any separately approved visitor protected-ID requirement

## Ownership boundary preserved

The reconciliation does not reassign or modify Jorj Dominic's reserved workstreams:

- FCM / push delivery / Firebase / APNs
- Tenant onboarding / contracts / signatures / activation / contract-generated billing
- Geofencing / native tripwires / gate evaluation / curfew-gate integration

## Validation performed

- Reconstructed the uploaded Git bundle
- Reviewed current `main` source and Git history
- Cross-checked relevant Flutter services/pages, Supabase migrations, tests, and tooling
- `git diff --check` passes for the Markdown changes

Flutter analysis and the complete test suite were rerun on September 27, 2026
and passed (427 tests). Live Supabase checks and physical-device tests were not
run and remain separate verification tasks where the trackers say so.

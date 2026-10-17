# Phase 6 staging and physical-device acceptance checklist

Date: 17 October 2026 (Asia/Manila). **Every checkbox below remains pending.** This is a separate manual checklist, not evidence that device/staging acceptance was completed. Use synthetic accounts and disposable bills in a dedicated staging project. Do not scan a test QR with real funds or use real tenant balances.

For every run, record tester/date, platform/OS/browser/device, app version/commit, staging project, synthetic record IDs, expected/actual result and screenshots/logs. Redact tokens, signatures, secrets and personal data. Record a failure separately from an unavailable environment; retain evidence for failed checks.

## Environment and upgrade gate

- [ ] Verify a database backup restores successfully into an isolated environment; separately verify private Storage/Cloudinary media recovery.
- [ ] Replay the full migration chain in a clean disposable Supabase stack. Upgrade a staging dataset with existing signed contracts, paid/partial bills, deposits, reports and evidence. Apply pending 202610160001–009 in order.
- [ ] Compare historical values/IDs/snapshots and row counts before/after; inspect view fields/RPC signatures, RLS, Storage policies and PostgREST schema reload.
- [ ] Configure staging-only Supabase, private media, email, cron and notification dependencies securely. Confirm no client contains service-role, provider-secret or Cloudinary-secret credentials.
- [ ] Pin both Flutter Supabase defines to staging. Exercise offline startup and expired session recovery without accidentally contacting production.
- [ ] Configure PayMongo sandbox and staging project pinning. Register synthetic sample bills explicitly; confirm production/test isolation. Record actual provider callback delivery evidence.

## Owner and Caretaker

- [ ] Owner: create/edit/archive/restore a synthetic tenant and guardian, link/unlink the intended accounts, and test authorized account administration/email/password reset without broadening Caretaker permissions.
- [ ] Owner: create/rename/archive/restore maintenance/common-area/concern/conduct/charge choices. New forms reflect updates; archived options disappear; old records retain historical labels. Validate Other/specify.
- [ ] Owner: create default-four-bed and custom-capacity rooms; grow capacity, safely shrink free beds, reject occupied/reserved/history-breaking decreases, duplicate IDs and unauthorized writes. Archive/restore without losing identities.
- [ ] Owner: prepare Solo, Exclusive Shared and Standard Shared contracts. Confirm physical capacity versus contractual reservation, exact-cent shares and preserved individual rates when another Standard Shared tenant joins.
- [ ] Complete draft → PDF → tenant/lessor signatures → verification → activation → assignment/reservation → individual billing. Missing/stale/unverified/deleted documents block activation. Verify supported renewal and blocked unsupported amendments.
- [ ] Open the same room in two staff sessions and repeat the conflicting reservation/activation/capacity scenarios through the actual API. Verify one valid result and a clear refresh/retry response, with no partial records.
- [ ] Caretaker: complete permitted tenant/maintenance/payment duties; reject Owner-only structure/configuration/charge/publication operations using direct API attempts as well as UI navigation.
- [ ] Both staff roles: review maintenance status/evidence/history and confidential concern destinations. Internal notes remain absent from tenant/guardian data responses and notifications.
- [ ] Both staff roles: issue warnings, recommend termination review, decide appeals, resolve and dismiss permitted cases. Verify actor/time/history and stale-update rejection; a recommendation must not automatically terminate a contract.
- [ ] Review financial filters, search, pending proofs, verified/rejected history, utility/additional charges and receipt history. Confirm Billing remains reachable separately from proof review.
- [ ] Owner: submit Other charge with specification/reason; interrupt/retry the save and confirm one charge and notification. Reject unauthorized roles and changes to an existing retry request.
- [ ] Export filtered financial and executive PDFs. Check chronological ordering across years, undated rows, partial payments, deposits, test-credit exclusion, totals, long names and typography. Inspect actual printouts where supported.

## Tenant and Guardian

- [ ] Tenant: login/logout/relaunch/password recovery, profile changes and expired-session handling. Switch between two synthetic accounts and confirm cached data does not cross accounts.
- [ ] Tenant: view/sign only the intended contract; confirm assigned room/bed and rent match the approved immutable terms. New roommates must not reprice prior invoices.
- [ ] Tenant: upload manual proof with supported screenshot formats; exercise OCR-assistance success/failure without automatic acceptance based solely on OCR. Review rejection/correction and partial-payment balances.
- [ ] Tenant: create/edit maintenance report with default incident date, immutable server submission time, current category/location, Other/specify and photo. Test an archived choice between form opening and save.
- [ ] Tenant: submit a confidential concern and inspect its authorized staff destination/history. An unrelated tenant and unlinked guardian must not read it or its private attachments.
- [ ] Tenant: read a published conduct case, submit explanation, inspect only authorized official responses/evidence and submit an eligible appeal. Recorded allegations/warnings alone must not count as confirmed violations.
- [ ] Guardian: login and verify only authorized linked-tenant information, curfew/leave approvals and permitted notifications. Attempt unrelated-tenant IDs directly in API requests and media URL requests.
- [ ] Tenant and Guardian: display only an approved agreement for the correct audience, review full text and explicitly accept. Verify server user/time/version, retry behavior, new-version refresh and immutable previous acceptance. Do not publish placeholder legal text.

## PayMongo, receipt persistence and network failures

- [ ] Create a supported synthetic checkout through the app. Complete a real **provider sandbox** transaction and capture the signed callback, authenticated provider confirmation, verified allocation and generated TEST receipt.
- [ ] Verify matching tenant/bill/reference/amount/currency/environment across receipt, payment history and staff ledger. Reopen the app and confirm the persisted state; test device closure before the callback and reconciliation after reopening.
- [ ] Exercise failed, cancelled and expired requests, delayed/out-of-order/duplicate callbacks, invalid/stale signatures, unknown references and mismatched provider facts. No invalid input may credit a bill.
- [ ] Process the same callback concurrently through actual staging functions. Confirm one allocation/receipt and correct notifications, including retries after a provider timeout.
- [ ] Inject failure after a committed proof/staff-payment/contract/photo write but before the client receives the reply. Refresh to recover the saved record and usable evidence. A confirmed rejection may clean up detached uploads; an unknown outcome must not delete saved evidence.
- [ ] Verify the deployed media-delete endpoint rejects own-folder files still attached to payment/report records and foreign-folder files. Detached cleanup is permitted only to the authorized uploader. Test database lookup failure and actual attach/delete race behavior without using production evidence.
- [ ] Inject receipt creation failure after legitimate verification. Payment remains verified; later receipt recovery retains canonical numbering and clearly identifies recovered versus original snapshot details.
- [ ] Interrupt initial form submission, uploads, mode switching and checkout. Refresh before resubmitting uncertain operations; verify intended deduplication and actionable loading/errors. Record any duplicate initial-report behavior separately.
- [ ] Print/download manual and sandbox receipts. Verify numbering, partial balance, original reference, tenant/bill, received/verified dates and unmistakable TEST labeling; do not characterize these as tax-compliant receipts.

## Android physical device

- [ ] Install the staging build on supported Android versions. Check back navigation, forms, keyboard/insets, dialogs, search and small-screen scrolling.
- [ ] Exercise camera/gallery/file selection, denied/limited/revoked permissions, large/invalid files, cancellation and failed-upload recovery.
- [ ] Exercise notification permission, foreground/background/terminated delivery, unread count, Mark All as Read, deep links and duplicate suppression. Register late after initially having no device token.
- [ ] Verify location permission escalation, disabled GPS, reduced/unavailable location, backgrounding, force closure and reboot. Check entry/exit review and approved curfew exceptions/late returns with guardian notifications.
- [ ] Verify unreliable geofence observations cannot automatically confirm a violation. Check offline event queue/reconnection without duplicate presence events.
- [ ] Open sandbox checkout and PDFs; test print/share, app switching and reopening after payment confirmation. Inspect distribution signing before any store upload.

## iOS / TestFlight

- [ ] Build on macOS/Xcode, validate bundle ID, provisioning/certificate, privacy purpose strings, background modes and final signed production APNs entitlement. Verify Codemagic signing inputs without exposing them.
- [ ] Test iPhone/iPad navigation, safe areas, keyboards, camera/photo/file permissions including limited photo access, document/PDF export and printing.
- [ ] Verify notification permission and APNs/FCM delivery foreground/background/terminated, deep links and initial launch from a notification.
- [ ] Test location authorization changes, backgrounding, closure/relaunch, queued events and offline reconnection. Check the actual platform limitations rather than assuming Android behavior applies.
- [ ] Complete sandbox checkout while switching apps and reopening; verify persistent receipt/balance and reconciliation. Complete an approved TestFlight acceptance run before production approval.

## Web and release sign-off

- [ ] Authenticate Owner and Caretaker on staging in supported browsers. Verify public-to-staff navigation, browser back/forward, reload/session restore, search/filter state and unauthorized role/route access.
- [ ] Check phone/tablet/desktop tables/forms, long names, dark mode, keyboard navigation, document upload, proof review and PDF printing/download.
- [ ] Open two browser sessions and a mobile client; verify realtime room/payment/report/notification refresh without duplicating writes or switching the active account's data.
- [ ] Verify notification recipients, unread counters, Mark All as Read, record-specific deep links and inaccessible/deleted destinations for all four roles.
- [ ] Confirm approved retention remains configuration-only and no automated deletion is enabled. Keep unapproved legal gates and roommate amendments blocked.
- [ ] Record live-payment verification requirements separately from sandbox evidence; any live activation requires explicit authorization and its own controlled checks.
- [ ] Resolve actual defects, document environment gaps and obtain staging acceptance. Verify backup/rollback/forward-fix procedures and signed artifacts, then request a separate production release approval. Do not deploy from this checklist automatically.

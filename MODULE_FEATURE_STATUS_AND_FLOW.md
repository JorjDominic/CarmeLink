# CarmeLink Module and Feature Status

> Snapshot/reference only. Use [`STATUS.md`](STATUS.md) for current completion decisions and gap ownership.

> Repository state reviewed: September 25, 2026  
> Status is based on reachable Flutter code, services/controllers, Supabase migrations and Edge Functions, native Android/iOS code, static analysis, tests, and build results. Remote deployment is not assumed merely because SQL exists locally.

## Status legend

- **Implemented** — normal code path and persistence exist; still requires production deployment verification.
- **Implemented, verify live** — code is substantially complete, but remote RLS/secrets/Realtime/Storage or physical devices must be checked.
- **Partial** — useful behavior exists, but an important path is missing, inconsistent, or intentionally deferred.
- **Placeholder/local only** — visible UI or local behavior exists without the promised durable backend operation.
- **Removed/out of scope** — intentionally absent and should not be presented as a feature.

## Shared architecture

| Module | State | How it currently works | Data/backend | Remaining work |
|---|---|---|---|---|
| App bootstrap | Implemented | Initializes Flutter, tries Supabase for five seconds, initializes push support, renders the app, then restores the session asynchronously. | Supabase client, Firebase | Confirm failure UX under real outages. |
| Session routing | Implemented | `SessionController` restores Auth and profile state. `app.dart` prioritizes password recovery and email verification, then selects tenant, guardian, caretaker, or owner shell. | Auth + `profiles` | Live redirect and invalid-profile tests. |
| Role guards | Implemented | UI routes check `UserRole`; backend RLS/RPC authorization is expected to independently enforce access. | `profiles.role`, helper SQL functions | Complete negative-role staging matrix. |
| Controllers/state | Implemented | Role controllers cache screen state, expose loading/error flags, call services, replace changed records, and notify listeners. | All domain services | Controllers are not persistence; confirm no screen treats cached state as authoritative. |
| Shared models | Implemented | `models.dart` parses Supabase JSON into typed client records and supplies status/date/display helpers. | Database row contracts | Keep synchronized with final deployed columns/status values. |
| Connectivity banner | Implemented | Watches device network state and displays a banner. It does not prove Supabase reachability. | `connectivity_plus` | Optional real backend health check. |
| Theme/responsive shell | Implemented | Shared Material theme, light/dark/system selection, phone/tablet/web navigation, role destinations, accessibility layouts. | Local UI state | Theme preference is not persisted across process restarts. |

## Authentication and identity

| Feature | State | Current processing flow | Remaining risk/gap |
|---|---|---|---|
| Sign in | Implemented, verify live | Supabase Auth verifies credentials; app loads matching `profiles` row and maps its role; session controller registers push token and starts tenant services where applicable. | Missing/mismatched profile prevents correct routing; test all roles remotely. |
| Session restore/sign out | Implemented | Restores Auth session on startup. Sign-out stops geofence scheduling, revokes current push token where possible, signs out, and clears role controllers. | Validate token cleanup during offline logout and forced account deletion. |
| Email verification | Implemented, verify live | OTP verification/resend uses Supabase Auth; profile verification timestamp is synchronized where possible. | Confirm templates, SMTP provider, expiry, rate limits, and deployed redirect URLs. |
| Password recovery/change | Implemented, verify live | Recovery email/deep link or OTP establishes recovery mode; user sets a new password. Ordinary changes require current-password reauthentication. | Test web/mobile redirects and expired/reused codes. |
| Staff account management | Implemented, verify live | Staff UI calls `create-user` and `manage-user` Edge Functions for Auth/profile creation, updates, resend/reset, and deletion. | Verify role authorization and partial-failure cleanup in deployed functions. |
| Profile display | Implemented | Reads current profile plus role-specific relationship labels such as room or linked tenant. | Profile editing depth varies by role; validate exposed personal fields. |
| App-usage tracking | Removed/out of scope | No service, permission, native channel, or guardian display remains. | Must remain absent from scope, privacy materials, and future builds unless formally approved. |

## Rooms, beds, tenants, and guardians

| Feature | State | Current processing flow | Remaining risk/gap |
|---|---|---|---|
| Room directory | Implemented, verify live | Reads `rooms`, `bed_spaces`, and active `tenant_assignments`; assembles room occupancy in the service. | Verify concurrent assignment/capacity behavior. |
| Room creation/edit/deletion | Implemented, verify live | Creation calls `create_room_with_four_beds`; updates/deletes use protected table operations. | Confirm RLS and deletion restrictions with occupied rooms. |
| Bed management | Implemented, verify live | Staff creates/updates/deletes bed spaces; database validations protect capacity/status. | Confirm active assignments block destructive changes. |
| Tenant assignment | Implemented, verify live | `assign_tenant_bed` and `end_tenant_assignment` atomically change active occupancy. | Run simultaneous assignment tests. |
| Tenant directory/details | Implemented | Combines profiles, tenant details, assignments, guardian links, and contract summaries. Staff can search/filter and open details. | Some onboarding badges are feature-flagged off in owner pages. |
| Tenant room view | Implemented | `get_my_room_details` returns assigned room, bed, roommates, and room metadata. | Verify tenants cannot request unrelated tenant IDs. |
| Guardian links | Implemented, verify live | Staff creates/updates/deletes guardian-tenant links; primary selection clears competing primary links. | Verify removed links immediately revoke all related reads. |
| Guardian tenant overview | Implemented | Guardian service loads only linked residents and enriches them with room, payment, curfew, and gate summaries. | Full live relationship/RLS testing required. |

## Contracts and onboarding

| Feature | State | Current processing flow | Remaining risk/gap |
|---|---|---|---|
| Contract CRUD | Implemented, verify live | Owner creates/updates/deletes `tenant_contracts`; database validates tenant/date/state relationships. | Execute remote contract smoke test. |
| Onboarding invitation | Implemented, verify live | Staff creates opaque invitation; authenticated tenant claims token through RPC and submits personal/onboarding data. | Confirm expiry, single use, and cross-account denial. |
| Requirements checklist | Implemented, verify live | Contract creation initializes requirement rows. Files are submitted and reviewed through RPC-controlled states. | Confirm private bucket policies and required-document activation block. |
| Signers | Implemented, verify live | Tracks tenant/owner/guardian/witness requirements and verified/waived state. | Verify independent signer identity and no client-side bypass. |
| Contract PDF generation | Implemented | Client generates official lease PDF bytes and supports print/preview. | Bundled Helvetica warnings indicate limited Unicode support; embed a Unicode font if names may require it. |
| Generated/signed documents | Implemented, verify live | Uploads versioned files to private Storage, registers metadata, reviews signed files, and guards deletion. | Confirm bucket policies, one-pair rules, and cleanup after failed registration. |
| Activation and date sync | Implemented, verify live | Triggers enforce verification/onboarding, synchronize active dates into tenant details, and initiate billing. | Prove activation is idempotent and generates rent exactly once. |

## Billing, payments, and finance

| Feature | State | Current processing flow | Remaining risk/gap |
|---|---|---|---|
| Contract billing | Implemented, verify live | Active contracts generate `billing_charges`; later synchronization covers upcoming charges. | Reconcile charges through contract edits/renewals. |
| Tenant payment list | Implemented | Tenant reads own charges/transactions and derived balances/statuses. | Confirm legacy `payments` versus current transaction model is consistently handled. |
| Payment-proof submission | Implemented, verify live | Tenant selects/captures receipt, reviews data, uploads media, then calls `submit_payment_transaction`. Failed registration attempts media cleanup. | Test large files, retries, duplicate references, and offline interruption. |
| Receipt OCR | Implemented as assistance | Google ML Kit runs on-device and suggests amount, method, and reference. User reviews before submission. | Not authoritative; accuracy must not be claimed as verification. |
| Payment verification | Implemented, verify live | Staff lists pending/all transactions and calls `review_payment_transaction`; backend protects tenant and ledger fields. | Run financial authorization and double-review tests. |
| Utility charge | Implemented, verify live | Staff creates single charges or sends cart JSON to transactional batch RPC with allocations. | Verify rounding, occupant snapshots, and rollback on one invalid item. |
| Rent override | Implemented, verify live | Audited RPC creates future rate override/adjustment rather than rewriting prior ledger facts. | Verify effective-date and contract interactions. |
| Finance summary | Implemented | Owner summaries and PDF reports aggregate controller payment data. | Reconcile report totals against backend ledger before production use. |

## Maintenance and media

| Feature | State | Current processing flow | Remaining risk/gap |
|---|---|---|---|
| Tenant maintenance CRUD | Implemented, verify live | Tenant creates, edits, lists, and cancels allowed reports; tenant ID comes from Auth. | Verify state-based mutation guards and ownership. |
| Maintenance photos | Implemented, verify live | Selected/captured image uploads before row finalization; failed database write triggers best-effort cleanup. Authorized URL is created for display. | Confirm whether each deployed path uses Supabase Storage or protected Cloudinary consistently. |
| Staff maintenance workflow | Implemented, verify live | Staff lists joined report/tenant/room data and updates allowed status/notes through RPC. History records changes. | Confirm transitions and audit rows remotely. |
| Secure media service | Implemented, verify live | Edge Functions upload, authorize URLs, and delete protected Cloudinary images after checking the referenced record. | Confirm secrets, expiry, reference mapping, and delete authorization. |
| Interactive floor plan | Implemented | Used to select/display maintenance locations and monitor room issues. | Location labels must remain consistent with room identifiers. |

## Visitors and curfew

| Feature | State | Current processing flow | Remaining risk/gap |
|---|---|---|---|
| Visitor request | Implemented, verify live | Tenant submits visitor/contact/purpose and same-day schedule fields. Client policy gives feedback; database triggers enforce policy. | Run visitor remote smoke test against staging. |
| Visitor staff review | Implemented, verify live | Staff calls transition RPC for approval/rejection/arrival/departure/cancellation/completion. | Confirm every transition and role combination. |
| Visitor history | Implemented | Reads append-style `visitor_events` with actor/note/timestamps. | Ensure clients cannot modify history. |
| Tenant curfew request | Implemented, verify live | Tenant submits destination, reason, departure, and expected return; may cancel permitted states. | Validate Manila timezone and overlapping requests. |
| Guardian endorsement | Implemented, verify live | Linked guardian lists allowed requests and approves/rejects guardian stage. | Confirm primary/linked guardian rules. |
| Staff curfew decision | Implemented, verify live | Staff reviews requests reaching staff stage and records decision/notes. | Confirm sequencing cannot be bypassed. |
| Employee curfew profiles | Implemented but integration-limited | Staff records recurring work schedules and approves/revokes them; tenant can view approved effective profiles. | UI explicitly states gate/geofence evaluator integration is still under review; do not claim profiles currently change gate classification. |

## Gate presence and geofencing

| Feature | State | Current processing flow | Remaining risk/gap |
|---|---|---|---|
| Gate timeline/current state | Implemented, verify live | `gate_events` is append-only. Trigger copies newest direction/time to `tenant_details`. Staff, tenant, and guardian read permitted history. | Confirm direct writes are revoked and summary matches latest event. |
| Foreground GPS check | Implemented | Requests location, rejects disabled/denied/mock/stale/inaccurate readings, evaluates polygon or circle with edge buffer, then records result through RPC. | Physical-device accuracy testing remains. |
| Staff manual log | Implemented, verify live | Staff supplies tenant, direction, and mandatory notes to `record_staff_manual_log`. | Confirm caller role/target role and audit values. |
| Boundary read | Implemented | Loads newest active `dorm_boundary_config` and updates in-memory calculations; failure retains prior/default geometry. | Confirm production coordinates are real approved points. |
| Boundary editing | Broken/incomplete | Owner UI calls `update_dorm_boundary_config`. Intended migration file is empty and no SQL definition exists locally. | Implement secure RPC migration or remove editor. |
| Android native tripwire | Implemented, verify physically | Google circular geofence queues IN/OUT, WorkManager uploads through RPC, refreshes tokens, retries network failure, and restores after reboot/update. | Circle expands to at least 100 m; tokens are in ordinary preferences; OEM battery behavior needs testing. |
| iOS native tripwire | Partial | Core Location circular region/significant changes queue events; Flutter drains them when running. | No native background uploader; register reports success before authorization/monitor confirmation. |
| Polygon parity | Partial | Foreground Dart supports polygon; native Android/iOS adapters monitor a circle and directly queue circular transitions. | Choose one official model or add coordinate-aware polygon confirmation. |
| Geofence notifications | Implemented, verify live | Stored event invokes `notify-geofence`, resolves staff/guardians, inserts app notifications, and attempts FCM. | Validate recipients, deduplication, secrets, and killed-app delivery. |

## Messaging, announcements, and notifications

| Feature | State | Current processing flow | Remaining risk/gap |
|---|---|---|---|
| Conversation creation | Implemented, verify live | Service gets/creates tenant-management, guardian-management, or staff conversations according to role/relationship. | Verify unique relationships and unauthorized UUID access. |
| Chat messaging | Implemented, verify live | Loads ordered messages, inserts sender/body, updates conversation summary by trigger, subscribes to message changes. | Multi-device ordering, reconnect, and RLS tests. |
| Read receipts | Implemented, verify live | RPC advances caller-specific read state; UI maps outgoing delivery/read metadata. | Confirm one participant cannot alter another's marker. |
| Message push | Implemented, verify live | After insert, `notify-message` selects valid recipients, creates in-app rows, sends FCM, and revokes invalid tokens. | Confirm recipient logic for staff channels and active-chat suppression. |
| Announcement board | Implemented | Staff creates/edits/pins/deletes; tenants/guardians filter visible audience; service caches results for 30 seconds. | Verify audience RLS, not only client filtering. |
| Announcement push | Placeholder/no-op | Announcement is saved, but `_dispatchFCMNotificationIfConfigured` contains no dispatch. | Route through `notifyNewAnnouncement`/Edge Function and mark outcome. |
| Live notification center | Implemented, verify live | `NotificationsPage` streams/fetches recipient rows and supports mark-one/mark-all read. Push taps route to messages or notification center. | Live FCM/APNs and route tests. |
| Header notification shortcut | Broken/inconsistent | A shared header opens `_GlobalNotificationsPage`, whose list is hardcoded empty and says service is disconnected. | Replace it with the real `NotificationsPage`. |
| Notification preferences | Local/partial | UI stores toggles only in widget/process state; it does not persist server preferences or control fan-out. | Add durable per-user preferences and enforce them during dispatch, or label as local UI. |
| Guardian personal alert time | Local/partial | Static in-memory time defaults to 9 PM; helper checks if linked tenant is outside after cutoff. | Resets on restart and does not schedule an OS alert. |
| Emergency/safety alerts | Partial | Guardian-facing information/presence pages exist; persistent emergency alert automation is not a distinct completed backend workflow. | Define triggers, recipients, acknowledgement, and escalation if in scope. |

## Cleaning, inspections, conduct, and governance

| Feature | State | Current processing flow | Remaining risk/gap |
|---|---|---|---|
| Cleaning schedules | Implemented, verify live | Staff sets bed/weekday schedule; tenant RPC resolves current room schedule. | Assignment changes and roommate visibility tests. |
| Cleaning noncompliance | Implemented, verify live | Tenant/staff submit/read/update reports under RPC rules; history records staff actions. | Confirm tenant reporting scope and audit immutability. |
| Room inspections | Implemented, verify live | Staff creates/starts/completes/cancels inspection and manages findings through RPC state machine. Tenants read current-room records. | Verify completion constraints and tenant privacy. |
| Inspection evidence | Implemented, verify live | Staff uploads to private bucket then registers metadata; failed registration removes file. | Bucket path/MIME/size/delete tests. |
| Conduct cases | Implemented, verify live | Staff drafts/publishes/reviews cases; tenant reads own published cases and submits response; events form audit trail. | Confirm drafts and other tenants remain invisible. |
| Warnings/termination recommendation | Implemented, verify live | Staff RPCs issue warning or recommend review without directly mutating financial/contract state. | Policy acceptance and role tests. |
| Conduct evidence | Implemented, verify live | Protected upload plus evidence metadata registration. | Storage and access verification. |
| Appeals | Implemented, verify live | Tenant submits/withdraws within eligible state/window; staff begins review and decides. | Server-time deadline and repeat-decision tests. |
| Retention settings | Implemented as configuration | Staff records proposed days/review status; event table audits changes. | `enforcement_enabled` is constrained false. |
| Retention deletion/anonymization | Not implemented | No purge, archive, anonymization, cron, or scheduled executor exists. | Must be future work or separately designed/reviewed before claiming disposal. |

## Reports and secondary staff features

| Feature | State | Current processing flow | Remaining risk/gap |
|---|---|---|---|
| Financial PDF | Implemented | Aggregates payment/charge data available to caller and generates printable PDF locally. | Reconcile totals and embed Unicode fonts. |
| Occupancy roster PDF | Implemented | Uses tenant/room/assignment data to generate roster. | Verify privacy and current-assignment filtering. |
| Maintenance PDF | Implemented | Formats maintenance records/statuses into report. | Confirm date/status scope. |
| Curfew/gate PDF | Implemented | Formats curfew and gate history returned to staff. | Validate timezone and sensitive notes. |
| Executive overview PDF | Implemented | Combines module summaries into local printable report. | Verify every metric against authoritative queries. |
| Reports/analytics dashboard | Implemented with operational data | Shows occupancy/payment/maintenance/security summaries and offers report generation. | No separate analytics warehouse; labels should not imply predictive analytics. |
| Emergency contact directory | Partial | Displays guardian/resident contact data from tenant directory. | Call button is a snackbar placeholder; use `url_launcher` or remove it. |
| Contract-expiry alerts | Partial | Page aliases the contracts page rather than providing a dedicated automated alert process. | Add expiry query/notification schedule if required. |
| Disciplinary records | Implemented through conduct module | Routes to conduct case pages/services. | Same conduct production checks apply. |

## Settings and informational features

| Feature | State | Current processing flow | Remaining risk/gap |
|---|---|---|---|
| Appearance | Implemented locally | Changes runtime theme among system/light/dark. | Persist preference if required. |
| Privacy and permissions | Implemented as OS/settings UI | Displays permission states and opens platform app settings. | Keep descriptions synchronized with actual manifest/plist permissions. |
| Change password | Implemented | Calls Auth service with recovery or current-password flow. | Live Auth configuration tests. |
| Feedback form | Placeholder/local only | Collects UI fields and discloses that submission is not persisted. | Add backend/email/ticket integration or remove from production navigation. |
| Device binding | Placeholder | Tenant-only page shows intent and a nonfunctional bind action. | Define device record, proof, revocation, replacement, and audit—or remove. |
| Dormitory information/rules | Implemented as static content | Displays app/property/rule information from client constants/pages. | Establish owner and update process for policy text. |

## Web application

| Feature | State | Current processing flow | Remaining risk/gap |
|---|---|---|---|
| Public landing site | Implemented | Responsive branded content, gallery/lightbox, location/map, external links, and motion accessibility. | Confirm final content, domains, privacy links, and deployment entry point. |
| Staff web authentication | Implemented, verify live | Initializes same Supabase project, restores session, checks staff role, and routes to workspace. | Test redirects and non-staff denial on deployed domain. |
| Staff web workspace | Implemented | Reuses live owner/caretaker modules within web-responsive shell and quick panels. | Browser Storage/download/push limitations need deployment testing. |
| Local staff preview/demo | Implemented intentionally as demo | Separate entry point and in-memory demo store; clearly labels that changes are local. | Never deploy this entry point as the authenticated production portal. |

## Native platform and release state

| Platform item | State | Current behavior | Remaining risk/gap |
|---|---|---|---|
| Android build | Prototype-ready | Debug APK compiles; application ID is `com.carmelita.carmelink`; Firebase config exists. | Release uses debug signing; configure protected production keystore. |
| Android permissions | Implemented | Requests only active feature permissions: network, location/background, notification, camera/media, boot/wake/vibration. | Physical-device and store declaration review. App-usage permission is absent. |
| iOS build configuration | Partial | Bundle ID and iOS 15.5 target exist; location/background/photo descriptions and APNs entitlement exist. | `GoogleService-Info.plist` and development team are absent; APNs is development-only. |
| Push delivery | Partial/verify live | Android/iOS Flutter handlers and server FCM sender exist. | iOS cannot be considered configured; server secrets and real devices unverified. |
| Release operations | Not production-ready | Local tests and Android debug build pass. | Add signed release builds, CI gates, crash monitoring, backups/restoration, runbooks, and pilot process. |

## Current verification results

```text
flutter analyze             PASS — no issues
flutter test                PASS — 381 tests
flutter build apk --debug   PASS
Remote migration parity     NOT VERIFIED
Remote RLS/Storage tests    NOT VERIFIED
Physical mobile tests       NOT VERIFIED
iOS production build        NOT VERIFIED
```

## Overall interpretation

The core dormitory management system is substantially implemented and is suitable for a controlled prototype after the visible broken/placeholder paths are addressed. The primary modules are not merely mock screens; most have services, migrations, RPCs, RLS design, and tests. Production readiness is lower because deployed authorization, secrets, private media, Realtime, native background behavior, retention, signing, and operational controls still require proof.

Highest-priority fixes:

1. Resolve the missing boundary-update RPC or remove boundary editing.
2. Connect announcement push and remove the obsolete empty notification page.
3. Remove or implement device binding, feedback submission, and call actions.
4. Align employee-curfew behavior and polygon/circle geofence semantics.
5. Synchronize and test the complete backend in staging with every role.
6. Finish Android/iOS production signing, Firebase/APNs, and physical-device tests.
7. Correct stale documentation so it distinguishes implemented, partial, and future-work behavior.

# CarmeLink Backend Module Logic and Configuration Guide

> Canonical completion decisions and open gaps are maintained in [`STATUS.md`](STATUS.md). This file is a technical reference, not the live status authority.

> Repository review date: September 25, 2026  
> Purpose: explain how each application module currently processes information and provide a practical checklist for verifying the deployed backend.  
> Scope: Flutter mobile/staff UI, controllers, services, Supabase migrations, Edge Functions, Storage, Realtime, Cloudinary, FCM, and Android tripwire geofencing.

## 1. How to use this document

This describes the behavior implemented in the repository. A migration or function existing in Git proves the **intended** backend configuration, not that it has been deployed. Items marked **live check** must be confirmed in the Supabase dashboard or by running the integration scripts.

The normal data path is:

```text
Screen/widget
  -> role controller (loading, cached UI state, errors)
  -> service (validation, mapping, query/RPC/function call)
  -> Supabase Auth / Postgres / Storage / Edge Function
  -> RLS + constraints + triggers enforce server rules
  -> mapped Dart model
  -> controller notifies listeners
  -> UI rebuilds
```

Important principles used throughout the system:

- Supabase Auth owns credentials and sessions; `profiles` owns application identity and role.
- The publishable Supabase key is intentionally present in the client. Security must come from RLS, grants, RPC authorization, and server-only secrets—not from hiding that key.
- Sensitive or multi-step changes generally use database RPCs or Edge Functions instead of direct client writes.
- Controllers hold temporary presentation state. Postgres is the source of truth.
- Many screens refetch after writes. Realtime is used selectively for messages, notifications, gate data, and debounced table refreshes.
- UI checks improve usability but are not security boundaries. Backend policies, constraints, and functions must repeat important validation.

## Risk-first review order

Use this section before the module reference when preparing a demonstration, defense, privacy review, or deployment. Work from Tier 1 downward.

### Tier 1 — resolve before defense or live demonstration

| Issue | Evidence in the current repository | Why it matters | Required decision/action |
|---|---|---|---|
| Boundary-editing backend is missing | `BoundaryConfigService` calls `update_dorm_boundary_config`, but `202609250002_boundary_config_editable.sql` is zero bytes and no repository migration defines the RPC. | Editing will fail unless an unreproducible function was created manually in production. It also conflicts with any paper claim that the boundary is hardcoded or has no admin editor. | Choose one design: implement and migrate an authorized, validated owner/staff RPC; or remove/disable the editing client and document the boundary as deployment-managed. Make the paper match the chosen implementation. |
| Announcement push needs staging proof | Announcement creation now routes through `AppNotificationService.notifyNewAnnouncement` and marks `fcm_sent` only after the Edge Function accepts the request. | Repository wiring is complete, but deployed secrets, recipient rows, and physical-device delivery are not proven locally. | Deploy the functions and test tenant, guardian, and all-resident audiences on staging devices. |
| Retention configuration has no executor in this repository | Settings and audit events exist, but no scheduled deletion/anonymization task was found. | A saved retention duration does not dispose of data. Claiming automated disposal would overstate the implementation. | Describe enforcement as future work unless a separately deployed scheduled job can be evidenced. If such a job exists, document its location, schedule, authorization, target tables, dry-run/recovery behavior, and logs. |

### Tier 2 — standard backend due diligence

| Area | What to verify |
|---|---|
| Migrations versus deployed schema | Every nonempty migration is applied in filename order to the actual Supabase project. Investigate the empty boundary migration explicitly. |
| RLS coverage | RLS is enabled on every business table/private bucket; run positive and negative tests for tenant, guardian, caretaker, owner, and anonymous callers. |
| Boundary geometry | Confirm `dorm_boundary_config` contains real approved/surveyed points rather than placeholder geometry. Then reconcile polygon rules with the circular Android/iOS native tripwires. |
| Realtime publication | Confirm `gate_events`, `messages`, `conversations`, and `app_notifications` are published and still filtered by RLS. |
| Edge Function configuration | Verify FCM and Cloudinary secrets and restrict/remove `BOOTSTRAP_SECRET` provisioning in production. |
| End-to-end workflows | Run every scenario in section 27F once against staging, including expected-denial cases and side effects. |
| Mobile production setup | Resolve Android signing and iOS Firebase/APNs/signing gaps described in section 23. |

### Tier 3 — acceptable limitations if stated accurately

- Guardian alert time is process-local, resets on restart, does not schedule an OS alarm, and is informational only.
- Receipt OCR only suggests values; a person confirms the payment data and the server remains authoritative.
- `clientSafe` fallbacks can make backend failure resemble an empty dataset. Treat this as a testing caveat, not proof of correct configuration.
- iOS tripwire events can remain local until Flutter resumes; do not promise Android-equivalent background delivery.
- Native tripwires currently represent circles, not the configured polygon exactly.

### Fast verification sequence

Run these from the repository root against a safe staging environment:

```powershell
flutter pub get
flutter analyze
flutter test
powershell -ExecutionPolicy Bypass -File tool/phase5b_integration_readiness.ps1
powershell -ExecutionPolicy Bypass -File tool/contract_remote_smoke_test.ps1
powershell -ExecutionPolicy Bypass -File tool/visitor_remote_smoke_test.ps1
```

There are five validation commands after dependency installation: analyzer, test suite, and three PowerShell checks. The remote smoke tests may create or modify records, so inspect their required environment variables and point them at staging rather than production.

## 2. Runtime startup and session routing

### `main.dart`, `app.dart`, and Supabase configuration

Startup initializes Flutter, attempts Supabase initialization with a five-second timeout, initializes push notifications, mounts the app, and then restores the session asynchronously. A failed/slow Supabase initialization is logged rather than preventing the UI from starting.

`SupabaseConfig` points to project `https://iuplkgvitovzjbmtzpme.supabase.co` and exposes the client. Password recovery redirects default to `https://carmelitasdormitory.site/reset-password`, overridable with `--dart-define=PASSWORD_RECOVERY_REDIRECT_URL=...`.

`CarmelitaBootstrap` listens to:

- session and theme changes;
- `carmelink://onboarding?token=...` deep links;
- notification-open events.

It routes authenticated users to tenant, guardian, caretaker, or owner shells. Recovery and email-verification states take priority over ordinary role routing. Conversation notifications open the appropriate messaging page; other notifications open the notification center.

**Backend checks:** the project URL/key must belong to the intended environment; Auth redirect URLs must include the web recovery URL and mobile deep-link schemes; every Auth user must have one valid `profiles` row.

## 3. Authentication, accounts, and roles

### Authentication and session module

`AuthService` signs in through Supabase Auth, then loads `profiles` using the Auth UUID. It maps database roles to `tenant`, `guardian`, `caretaker`, or `owner`. Missing or invalid profiles make authentication unusable even if the Auth credential is valid.

Email verification uses OTP verification/resend methods. Password reset sends an Auth recovery email, accepts recovery OTP/deep-link sessions, and updates the password. Ordinary password changes first reauthenticate the user. `SessionController` owns loading/error/recovery/verification flags, registers push tokens after sign-in, and clears role controllers on sign-out.

### Staff account administration

`AccountService` lists `profiles` and calls Edge Functions for privileged Auth operations:

- `create-user`: creates the Auth user, inserts `profiles`, then inserts `tenant_details` or `staff_details` as appropriate.
- `manage-user`: updates identity/profile data, resends verification/reset messages, or deletes an account.
- `provision-test-users`: bootstrap-only utility protected by `BOOTSTRAP_SECRET`; it should not be exposed as a normal production workflow.

Privileged functions create a caller-scoped client to authenticate/authorize the requester, then use the service-role client only after authorization. The service-role key must never be shipped in Flutter or web builds.

### Core identity tables

| Table | Current purpose |
|---|---|
| `profiles` | One row per Auth UUID; full name, email-facing identity, role, verification/account state. |
| `tenant_details` | Tenant-specific personal/residency data plus cached gate state and active-contract dates. |
| `staff_details` | Staff-specific role information. |
| `guardian_tenant_links` | Guardian-to-tenant relationship, including primary-link semantics. |

**Backend checks:** confirm role enum values match the Flutter parser; profile creation cannot be performed anonymously; owner/caretaker permissions are separated as intended; Auth deletion and relational cleanup behave correctly; email confirmation templates and redirect allowlists are deployed.

## 4. Application models and state controllers

`models.dart` is the shared client contract. It contains `AppUser`, `Room`, `Roommate`, `Payment`, `MaintenanceReport`, `GateEvent`, `VisitorRequest`, `VisitorEvent`, `Announcement`, `ConcernReport`, `AppNotification`, `ChatMessage`, `ConversationRecord`, `DormRoomStatus`, `TenantDirectoryEntry`, `TenantContract`, `ContractDocument`, `OnboardingInvitation`, `ContractRequirement`, `ContractSigner`, `OwnerConversation`, `LinkedTenant`, and `CurfewRequest`.

`fromRow` factories normalize Supabase JSON, parse dates/numbers, and translate stored status strings into display-ready objects. If database columns or status spellings change, these mappings must change with them.

Controller responsibilities:

- `SessionController`: authentication lifecycle and global role selection.
- `TenantController`: tenant room, payments, maintenance, visitors, concerns, curfew, and gate presence.
- `OwnerController`: staff-wide payments, rooms, visitors, reports, curfew, maintenance, tenants, contracts, and manual gate logging.
- `GuardianController`: linked tenants, room/payment/gate summaries, and guardian curfew decisions.
- `MessagingController`: inbox filters, active conversation, messages, read position, and Realtime subscriptions.
- `ThemeController`: local presentation preference only; no backend dependency.

Controllers prevent duplicate loads, expose loading/error flags, replace locally changed rows, and call `notifyListeners()`. Their arrays are caches for a screen session, not durable records.

## 5. Rooms, beds, assignments, and tenant directory

### Processing logic

`RoomService` reads `rooms`, `bed_spaces`, and `tenant_assignments`, joins them in memory, and produces room/bed occupancy records. Room creation calls `create_room_with_four_beds`, ensuring the system convention of four beds per room is applied atomically. Room/bed edits use table updates subject to RLS and database validation.

Assignments call `assign_tenant_bed`; ending an assignment calls `end_tenant_assignment`. These server functions validate capacity/status, close conflicting active assignments, and keep relationships consistent. `get_my_room_details` returns the caller's room or a permitted tenant's room.

`TenantService` builds the staff directory by combining profiles, active assignments, guardian links, tenant details, and contracts. It also groups available beds by room and updates residency status.

`ProfileService` supplies compact relationship labels such as a tenant's room assignment or a guardian's linked tenant.

### Source tables/RPCs

- Tables: `rooms`, `bed_spaces`, `tenant_assignments`, `profiles`, `tenant_details`, `guardian_tenant_links`, `tenant_contracts`.
- RPCs: `create_room_with_four_beds`, `assign_tenant_bed`, `end_tenant_assignment`, `get_my_room_details`.
- Guards/triggers: room capacity, bed capacity/status, role relationship validation.

**Backend checks:** there must be no more than one active assignment per tenant/bed; room occupancy must agree with active assignments; deleted/disabled beds cannot receive tenants; tenants/guardians can read only permitted room data.

## 6. Contracts, onboarding, requirements, and documents

### Contract lifecycle

`ContractService` CRUDs `tenant_contracts`. Contract dates, rent, status, and tenant ownership are parsed into `TenantContract`. Database triggers synchronize active contract dates into `tenant_details` and generate billing when a contract becomes active.

`OnboardingInvitationService` lets staff create/revoke tokenized invitations. A signed-in tenant claims a token with `claim_onboarding_invitation`, then submits profile data through `complete_onboarding_invitation`. The server binds the invitation to the authenticated tenant and controls expiry/status.

`ContractOnboardingService` manages required submissions and signer state. Contract creation initializes `contract_requirements` and `contract_signers`. Tenants/staff submit documents; authorized staff review them, control guardian-required state, and update signer records. Activating a contract is protected by verified email, complete emergency-contact information, the verified latest signed contract, required documents, and required signers. Room/bed assignment and guardian linking remain parallel residency tasks, but a room assignment must exist before official PDF generation because the client lease prints the room number; the bed label is intentionally omitted. Rent follows the contract schedule rather than physical move-in, while occupancy metrics continue to use active assignments. When an overnight-leave request has no linked guardian, `submit_curfew_request` routes it directly to staff review instead of leaving it in `pending_guardian`.

`ContractDocumentService` generates PDF bytes from the official lease content, uploads generated/signed versions to the `contract-documents` bucket, registers metadata in `contract_documents`, supports review, download, and guarded deletion. Version numbers are calculated from existing records. Database rules enforce one logical generated/signed pair and protect signed records.

### Source tables/RPCs

- Tables: `tenant_contracts`, `tenant_onboarding_invitations`, `contract_requirements`, `contract_signers`, `contract_documents`.
- RPCs/triggers: claim/complete invitation, initialize onboarding, submit/review requirements, signer updates, email verification requirement, contract billing/date synchronization, signed-document review/protection.
- Storage: `contract-documents` and requirement upload paths with owner/staff policies.

**Backend checks:** invitation tokens are non-guessable and expire; tenant identity is taken from `auth.uid()` rather than trusted request data; Storage policies match metadata access; activation cannot bypass verified email, required items, or signatures; date sync and billing triggers run exactly once.

## 7. Billing, payments, utility allocation, and receipt OCR

### Billing flow

Contracts generate immutable billing facts in `billing_charges`. `PaymentService` reads tenant-visible payment transactions and lets a tenant submit proof through `submit_payment_transaction`. Receipt bytes are uploaded first; the RPC registers the amount, method/reference, charge, and storage reference. If registration fails, the service attempts to remove the orphan upload.

Staff lists pending/all payments and calls `review_payment_transaction` to approve or reject. The backend protects tenant-submitted fields and financial ledger facts from later client tampering.

Utility charges can be created for one tenant or as a cart/batch. `create_utility_charge_cart` receives JSON items and creates the batch, charges, and allocations transactionally. Workspace-locking prevents the temporary occupant set from changing mid-operation. Rent changes use `apply_rent_rate_override`, producing an audit record rather than silently rewriting history.

`ReceiptOcrService` runs Google ML Kit on-device. It extracts candidate amounts, payment methods, and reference numbers using heuristics. OCR output only pre-fills the form; it is not authoritative and the user must review it before submission.

### Source data

- Tables: `billing_charges`, `payment_transactions`, legacy/compatibility `payments`, `rent_rate_overrides`, `rent_charge_adjustments`, `utility_charge_batches`, `utility_charge_batch_items`, `utility_charge_allocations`.
- RPCs: `submit_payment_transaction`, `review_payment_transaction`, `create_utility_charge`, `create_utility_charge_cart`, `apply_rent_rate_override`, contract billing generation.
- Storage/media: receipts are private; URLs are signed or authorized, never assumed public.

**Backend checks:** charge balances equal approved allocations; rejected payments do not settle charges; tenants cannot review their own proof or change ledger fields; batch RPC is atomic; duplicate contract activation does not duplicate rent; receipt policies prevent cross-tenant access.

## 8. Maintenance workflows

### Tenant maintenance

`MaintenanceService` requires the signed-in tenant ID, lists only their reports, and creates/updates/deletes tenant-owned requests. Images are uploaded before the database row is finalized; failed writes trigger best-effort media cleanup. Tenants may edit only states allowed by server protection rules.

### Staff maintenance

`StaffMaintenanceService` loads joined tenant/room information, derives allowed next statuses, and updates through `update_staff_maintenance`. Status transitions and staff notes are written server-side, with `maintenance_staff_history` preserving an audit trail. Photo access uses an authorized URL.

### Media path

Current media code supports protected Cloudinary references via `SecureMediaService` and Edge Functions as well as Supabase Storage paths used by older/specific flows. Callers store the returned reference, not raw image bytes or a permanently public URL.

**Backend checks:** `maintenance_reports` and history exist; tenant and staff update guards are active; the `maintenance-photos` bucket/policies or Cloudinary secrets match the chosen deployment path; status transitions cannot be skipped or reversed outside allowed rules.

## 9. Visitors

`VisitorService` lets tenants list, submit, and edit their pending visitor requests. Staff reads the broader queue and calls `transition_visitor_request` for approvals, rejection, check-in/out, cancellation, or completion. Every transition can produce a `visitor_events` audit record.

Client-side `visitor_policy.dart` gives immediate validation, while database triggers `validate_visitor_request_details` and `enforce_visitor_approval_policy` are authoritative. They enforce contact information, same-day scheduling, allowed timing/status, and approval requirements.

**Backend checks:** `visitor_requests` may originate in an earlier migration while `visitor_events` and enforcement are added later—apply the full migration chain; tenants cannot approve requests; edits are limited to pending/owned requests; event history is not tenant-editable.

## 10. Curfew requests and employee exceptions

### Ordinary curfew requests

Tenants submit destination, reason, departure, and expected return. Initial state is normally `pending_guardian` when guardian approval applies, then `pending_staff`; guardian/staff decision methods update their respective decision fields. Approved windows are consulted by geofence recording so an otherwise curfew-time movement is not automatically flagged. Cancellation is restricted by state and ownership.

### Employee curfew profiles

`EmployeeCurfewProfileService` handles recurring work-related exceptions. Staff creates/updates/approves/revokes profiles; tenants see only their approved profiles. `resolve_employee_curfew_profile` determines the effective exception for a date/time. `employee_curfew_profile_events` records lifecycle actions.

Shared policy helpers calculate allowable dates/status transitions for UI consistency; RPCs remain authoritative.

**Backend checks:** guardian linkage and primary guardian behavior are correct; decision order matches policy; approved windows use `timestamptz` consistently; Asia/Manila curfew evaluation matches business rules; revoked/expired employee profiles are never resolved as active.

## 11. Gate presence, geofencing, and native tripwire

### Data model

`gate_events` is append-only history. Each observation records tenant, `IN`/`OUT` (or null when unavailable), method, status, checkpoint, timestamp, notes, and creator. A trigger updates `tenant_details.current_gate_status` and `last_gate_event_at`; clients must not overwrite history to represent current state.

`dorm_boundary_config` contains the active polygon or circle, center/radius, edge buffer, ordered polygon points, and audit timestamps. It stores facility geometry, never tenant coordinate history.

### Foreground/manual flow

`GeofenceService` requests location permission, obtains current GPS, and evaluates point-in-polygon or circle distance with an edge buffer. `TenantController.performGeofenceCheckIn` converts the result into a server event. `GateService` calls `record_tenant_geofence_check`; staff manual logs call `record_staff_manual_log` and require notes.

The server validates caller role, direction/status/checkpoint, evaluates curfew exceptions, normalizes duplicates, inserts history, and updates the tenant summary. Coordinates are deliberately not persisted.

### Android native tripwire flow

`TripwireGeofenceService` sends active boundary data, tenant ID, Supabase URL/key, and access token through a Flutter platform channel to Kotlin. `TripwireGeofenceManager`, `GeofenceBroadcastReceiver`, `TripwireSyncWorker`, and `TripwireBootReceiver` register transitions, persist a small pending queue locally, and call the secure transition RPC. Pending transitions are synced later after connectivity/process interruptions. `GeofenceScheduler` provides foreground position transition detection and de-duplication.

After a stored event, the app invokes `notify-geofence`, which finds staff and linked guardians, inserts `app_notifications`, and sends FCM where configured.

**Backend checks:** one active boundary has real production coordinates; Android permissions/background declarations are accepted on target OS versions; `record_tenant_geofence_transition` authenticates the token and de-duplicates client event IDs; direct inserts are revoked; Realtime publication includes `gate_events`; current summary equals the newest event; no raw coordinates are stored.

## 12. Messaging and read receipts

`MessagingService` gets or creates tenant/guardian/staff conversations, lists accessible conversations, fetches messages ordered by time, inserts new messages, and calls `notify-message`. A database trigger updates conversation last-message metadata. `mark_conversation_messages_read` records the caller's read boundary, allowing delivery/read metadata without rewriting message content.

`MessagingController` owns the inbox filter/search, active conversation, optimistic loading states, and subscriptions. It subscribes separately to message inserts/updates for the open chat and conversation changes for the inbox; it refetches authoritative joined rows because Realtime payloads do not contain all joins.

Access is centralized by `can_access_conversation`: participants, relevant guardians/tenants, and permitted staff can read/send. RLS must apply the same rule to conversations and messages.

**Backend checks:** `conversations` and `messages` are in the Realtime publication; unauthorized UUID guessing returns no data; sender ID is derived/validated from `auth.uid()`; read-receipt RPC only changes the caller's marker; message notification function cannot notify arbitrary unrelated users.

## 13. Announcements and notifications

`AnnouncementService` lists visible announcements and allows staff to create, update, pin, and delete records. It keeps a 30-second in-memory cache by audience. Creating an announcement invokes `AppNotificationService.notifyNewAnnouncement`; the authorized Edge Function creates recipient notification rows and attempts FCM delivery. The service records `fcm_sent` only after the function accepts the request. The database announcement remains the durable record if push delivery is unavailable.

`AppNotificationService` provides typed helper methods for announcements, maintenance, payments, utility bills, visitors, curfew, conduct, appeals, and inspections. It invokes `send-fcm-notification`, which validates the actor/recipient relationship, inserts an `app_notifications` row, sends to active `push_device_tokens`, revokes invalid tokens, and records delivery information.

`PushNotificationService` initializes Firebase/local notifications, requests permission, registers refreshed device tokens against the logged-in user, displays foreground notifications, and emits tap payloads for navigation. `mark_notification_read` and mark-all operations update only the recipient's records.

Required Edge Function secrets are `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, and `FCM_PRIVATE_KEY` (with escaped newlines converted at runtime).

**Backend checks:** Firebase Android/iOS files belong to the intended Firebase project; APNs is configured for iOS; tokens are unique/current and removed on logout; notification RLS is recipient-only; absent FCM secrets degrade gracefully while in-app rows still behave as intended.

## 14. Guardian links and guardian portal

`GuardianLinkService` lets authorized staff list guardian/tenant profiles and create, edit, or delete links. Setting a primary guardian clears other primary flags for that tenant before applying the selected link.

`GuardianService` loads only linked tenants and enriches them with current gate state, room, and payment summaries. `GuardianController` switches the selected tenant, loads permitted curfew/gate data, and subscribes to refreshes. All tenant-specific queries still depend on RLS; the selected tenant ID in the client is not authorization.

**Backend checks:** `is_guardian_of` is used consistently; removed links immediately revoke access; only one primary link exists where required; guardians cannot see unrelated tenants or staff-only notes.

## 15. Confidential reports

`ConfidentialReportService` lets a tenant submit and list their own concerns. Owners list reports through `owner_list_confidential_reports` and review through `owner_review_confidential_report`. Review changes and access are captured in `confidential_report_audit`; ordinary broad table access is intentionally avoided.

**Backend checks:** caretaker access matches the intended policy (owner-only review is implied by function names); reporters cannot see other reports; owner RPCs validate role server-side; audit rows cannot be modified by clients.

## 16. Room cleaning and noncompliance

`RoomOperationsService` loads bed schedules, sets schedules through `set_cleaning_schedule`, obtains a tenant's room schedule through `get_my_room_cleaning_schedule`, and handles noncompliance submissions/reviews. Tenant context is resolved server-side from the current active assignment. `cleaning_report_history` preserves staff changes.

`cleaning_schedule_policy.dart` supplies client-side scheduling/transition rules. Database functions validate active rooms/beds, authorization, allowed values, and report transitions.

**Backend checks:** tenant visibility covers the current room only; assignment changes remove old-room access; staff schedule changes and report decisions are audited; direct history writes are denied.

## 17. Room inspections

`RoomInspectionService` creates, starts, completes, or cancels inspections via RPCs. Findings are separately added/updated with category, severity, responsibility, remediation, and status. Evidence is uploaded to the private `room_inspection_evidence` bucket, then registered in metadata; failed registration removes the upload.

Tenants can read inspections/findings for their current room according to RLS, while staff manage the lifecycle. `room_inspection_policy.dart` mirrors transition rules for UI validation.

**Backend checks:** only valid lifecycle transitions succeed; completing an inspection respects unresolved-finding rules; tenant evidence visibility matches privacy requirements; bucket size/MIME policies are deployed; Storage object paths cannot escape the inspection prefix.

## 18. Conduct cases, responses, warnings, evidence, and appeals

`ConductCaseService` separates staff and tenant reads. Staff creates a draft case, publishes it, records review state, issues warnings, and may recommend termination review. Tenants read their own published cases and submit responses. Events form an audit timeline. Evidence is uploaded privately and registered by RPC.

`ConductCaseAppealService` lets an eligible tenant submit or withdraw an appeal; staff starts review and decides it. Appeal windows, eligible case states, text requirements, and valid transitions are mirrored by policy helpers and enforced in RPCs.

Tables are `conduct_cases`, `conduct_case_responses`, `conduct_case_warnings`, `conduct_case_events`, `conduct_case_evidence`, and `conduct_case_appeals`.

**Backend checks:** drafts are invisible to tenants; tenants see only their own cases; warnings/events are append-only; evidence bucket is private; appeal deadlines use server time; deciding an appeal cannot be repeated or performed by the subject tenant.

## 19. Retention policy settings

`RetentionPolicyService` lists settings/events and calls `update_retention_policy_setting`. The database records the actor and old/new policy details in `retention_policy_events`. `retention_policy.dart` validates UI values.

This module currently manages policy configuration and audit information; the presence of settings does **not by itself prove automated deletion/anonymization jobs are running**.

**Backend checks:** confirm who may edit policies; audit is append-only; determine whether a scheduled cleanup job exists outside this repository. If none exists, retention settings are descriptive rather than automatically enforced.

## 20. Reporting

`DormitoryReportService` reads existing module data and generates PDFs client-side for financial results, occupancy roster, maintenance, curfew/gate activity, and executive overview. It formats records into printable documents and opens the platform print/preview flow. Reports do not create a separate backend reporting warehouse.

**Backend checks:** report queries must be protected by staff RLS; totals should reconcile against billing/payment rows; PDF generation uses only the rows returned to the caller, so incorrect RLS can become a data leak.

## 21. Media security and Cloudinary

`SecureMediaService` calls:

- `cloudinary-media-upload` to upload an authenticated image and return a protected reference;
- `cloudinary-media-url` to obtain a short-lived authorized delivery URL after checking access to the referenced business record;
- `cloudinary-media-delete` to remove authorized media.

The shared function code maps media kinds to permitted tables/records and uses a caller client so RLS participates in authorization. Cloudinary signing uses server-only `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, and `CLOUDINARY_API_SECRET`.

**Backend checks:** Cloudinary resources are authenticated/private; transformations/signatures expire; reference-to-record checks cover maintenance, payments, inspections, and conduct evidence as deployed; delete permission is stricter than read permission; secrets exist only in Edge Function configuration.

## 22. Connectivity, refresh, and fallback behavior

`ConnectivityBannerHost` observes network status and displays connectivity state. It does not guarantee that Supabase is reachable; service calls still handle errors.

`TableRefreshSubscription` creates a named Supabase channel, listens for table changes, and debounces callbacks to avoid query storms during batch writes. Consumers should refetch after the debounce rather than treating raw Realtime rows as fully joined models.

Several services use `clientSafe` and return empty/null results when Supabase is unavailable so previews/tests can render. That fallback is useful for UI resilience but can make a broken backend resemble an empty dataset. During verification, inspect logs/errors and do not accept an empty screen alone as proof of correct setup.

The former unreachable mobile `mock_data.dart` file has been removed. Web demo/preview stores remain presentation-only and are not evidence of backend connectivity.

### Auxiliary device-only services

`GuardianAlertService` is an in-memory preference/helper. It defaults to 9:00 PM and returns true when the chosen time has passed and the linked tenant status is `OUT`/`Outside`. It does not persist a guardian preference, schedule a platform alarm, insert a gate event, or trigger disciplinary handling. Restarting the process resets the preference.

The system contains no application-usage tracking feature. The former Android service, privileged manifest permission, native method channel, and guardian display were removed. Neither Android nor iOS reads installed-app activity or foreground-use duration.

`BoundaryConfigService` reads the newest active `dorm_boundary_config`, immediately applies it to the in-memory geofence calculator, and attempts updates through `update_dorm_boundary_config`. Failed reads deliberately retain the existing in-memory/default geometry.

**Known repository mismatch:** `supabase/migrations/202609250002_boundary_config_editable.sql` is currently empty (zero bytes), and no migration in this repository defines `update_dorm_boundary_config`. Unless that RPC was created manually in the remote project, boundary editing will fail with a missing-function error. Even if it exists remotely, the backend is not reproducible until its definition, validation, grants, and authorization are committed in a migration.

## 23. Android versus iOS implementation status

Most business functionality is shared Flutter code and therefore has the same Supabase services, models, controllers, validation, and screens on both platforms. The meaningful differences are native services, permissions, background execution, signing, and vendor configuration.

### Current capability comparison

| Capability | Android current state | iOS current state | Assessment |
|---|---|---|---|
| Flutter business modules | Implemented from shared Dart code | Implemented from shared Dart code | Broadly equal |
| Supabase Auth/database/RPC/Storage | Shared Supabase client | Shared Supabase client | Equal, subject to backend configuration |
| Onboarding deep link | Manifest handles `carmelink://onboarding` | URL scheme registers `carmelink`; Dart validates host `onboarding` | Implemented on both |
| Foreground GPS check | Geolocator/permission-handler | Geolocator/permission-handler | Implemented on both |
| Native region monitoring | Google Play Services circular geofence | Core Location `CLCircularRegion` plus significant-location monitoring | Implemented on both, but behavior differs |
| Background event queue | SharedPreferences, bounded to 24, expires after 24 hours | UserDefaults, bounded to 24, returned only if under 24 hours | Similar local queue |
| Background server synchronization | WorkManager uploads without opening Flutter, refreshes expired Supabase sessions | No native HTTP uploader/background task; Flutter must run `syncPending()` | Android substantially stronger |
| Reboot/app-update restoration | `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED` receiver | `restoreIfNeeded()` on app launch; iOS normally preserves monitored regions itself | Different OS model; Android restoration is more explicit |
| Application-usage tracking | Not present | Not present | Intentionally excluded from system scope |
| Firebase client file | `android/app/google-services.json` exists | `GoogleService-Info.plist` is absent | iOS push initialization is not reproducible/currently incomplete |
| Push entitlement | Android notification permission/channel/icon declared | `aps-environment` is hard-coded to `development` | iOS production push needs signing/configuration work |
| Release signing | Release currently uses debug signing key | No `DEVELOPMENT_TEAM` committed; signing must be supplied externally/Xcode | Neither is production-release ready from repo alone |
| Minimum OS | Flutter-derived Android minimum SDK | iOS 15.5 | iOS explicitly constrained |
| Camera/photo selection | Permissions declared; picker plugins shared | Usage-description strings declared; picker plugins shared | Implemented on both |

### Android implementation details

The Android application ID is `com.carmelita.carmelink`, although the Kotlin namespace remains `com.example.carmelitas_dormitory_system`; that difference is legal but should be intentional. It uses Java/Kotlin 17, Google Play Services Location, WorkManager, Firebase Google Services, and core-library desugaring.

`MainActivity` exposes two method channels:

- `carmelitas/tripwire_geofence` registers/unregisters monitoring, exposes queued events/status, and acknowledges synced events.

The manifest declares internet/network state, fine/coarse/background location, location foreground service, wake lock, boot completion, notifications, camera/media, and vibration. Runtime permission requests are still necessary; declarations alone do not grant access. It does not request `PACKAGE_USAGE_STATS`.

For geofencing, `TripwireGeofenceManager` requires fine and background location before registration. It stores the tenant, boundary center/radius, Supabase access/refresh tokens, and pending events in ordinary `SharedPreferences`. Google Play Services receives a circular geofence with a minimum wake-up radius of 100 metres. Entry/exit broadcasts append a de-duplicated event and schedule unique WorkManager work. `TripwireSyncWorker` sends events to `record_tenant_geofence_transition`, refreshes expired Supabase access tokens, retries transient failures, and discards events older than 24 hours.

Android strengths in the current repository:

- genuine native upload while Flutter is not running;
- session refresh in the background worker;
- explicit permission failure returned to Flutter;
- restoration after reboot or package replacement;
- Firebase configuration file and notification channel/icon are present.

Android risks/gaps:

- release builds are explicitly signed with the debug key;
- Auth tokens are stored in unencrypted `SharedPreferences` for the worker;
- the Kotlin namespace is still the template-style namespace;
- Android 13+ notification and Android background-location approval must be tested on physical devices;
- OEM battery restrictions can delay WorkManager/geofence delivery;
- the 100 m native circle does not represent a 50 m/polygon boundary precisely.

### iOS implementation details

The bundle identifier is `com.carmelita.carmelink`, deployment target is iOS 15.5, and the app declares Always/When-in-Use location, camera, photo-library, and photo-library-add explanations. Background modes include location, fetch, and remote notification. The URL scheme is `carmelink`.

`AppDelegate.swift` implements `carmelitas/tripwire_geofence` through `TripwireLocationManager`. It requests Always authorization, monitors one circular region, starts significant-location changes, establishes an initial state without recording it as a crossing, filters significant updates to recent locations with accuracy at most 35 metres, queues at most 24 transitions in `UserDefaults`, and exposes them to Flutter for acknowledgement.

iOS strengths in the current repository:

- native Core Location region callbacks can wake the app for boundary changes;
- significant-location updates provide a secondary circle-state signal;
- queue/baseline/de-duplication behavior is implemented;
- appropriate location usage strings and background modes are present;
- APNs entitlement and Flutter notification handling code exist.

iOS risks/gaps:

- there is no `ios/Runner/GoogleService-Info.plist`, so `Firebase.initializeApp()` and FCM cannot be considered configured from this repository;
- `aps-environment` is fixed to `development`; production/TestFlight builds normally require the production entitlement provided by the correct provisioning profile/configuration;
- no Apple development team is committed, so archive/signing needs external configuration;
- native tripwire code does not receive/store Supabase credentials and has no equivalent of Android's WorkManager uploader;
- queued events are synchronized only when shared Flutter code calls `syncPending()`, so the 15-minute delivery target is not guaranteed while the app remains suspended;
- `register` returns success immediately after requesting authorization and does not report monitoring/authorization failure back to Flutter;
- `UIBackgroundModes` includes `fetch`, but no background-fetch scheduler/handler is implemented here;

### Cross-platform geofence accuracy caveat

The authoritative boundary can be a polygon, but both native adapters monitor a circle using only `center_latitude`, `center_longitude`, and `radius_meters`. Android expands its hardware wake-up circle to at least 100 m; iOS clamps it to at least 25 m. Native entry/exit callbacks are converted directly to `IN`/`OUT` events—they do not re-run the polygon algorithm at the transition coordinate. The Flutter foreground baseline does use the configured polygon.

Therefore, polygon deployments can produce native events that disagree with foreground polygon checks, especially on Android between the configured boundary and the 100 m wake-up radius. The code comment saying the larger Android circle only wakes a final polygon decision does not match the current receiver: the receiver immediately queues the circular transition. Treat native presence as circular until a coordinate-aware polygon confirmation stage is implemented.

### Platform readiness weighting

For ordinary in-app CRUD workflows, the platforms are approximately equal because both use the same Flutter/Supabase implementation. For current native integration readiness:

- **Android is closer to operational readiness** because background geofence upload, token refresh, Firebase client configuration, and reboot restoration exist.
- **iOS is functionally implemented but incomplete for production** because push configuration/signing is missing and background geofence delivery depends on Flutter resuming.
- **Neither should be considered production-release ready** until Android release signing, iOS Firebase/APNs/signing, physical-device permission testing, and polygon/circle semantics are resolved.

Recommended order of work:

1. Add the correct iOS `GoogleService-Info.plist`, Apple team/provisioning, and production APNs capability.
2. Replace Android debug release signing with a protected release keystore configuration.
3. Decide whether the official geofence is circular or polygonal; make native transition semantics match that decision.
4. Add a reliable iOS native/background sync strategy or clearly define eventual delivery on next app resume.
5. Move native Supabase session material to platform-secure storage and define logout/token-rotation cleanup.
6. Run physical-device entry/exit, reboot, offline, token-expiry, killed-app, and notification tests on both platforms.

## 24. Web and staff portal modules

`main_web.dart` and the `lib/web` tree provide the public landing site, local demo, staff gate, and staff workspace. Landing content, gallery, map, theme, motion, and branding are largely static/client-side. Staff portal screens reuse or emulate domain views depending on entry point.

Verify which web entry point the deployment command builds. `main_staff_preview.dart` and demo stores are not production authentication. The real staff gate must rely on Supabase session/profile role and backend RLS, not a visual route guard alone.

## 25. Edge Function inventory

| Function | Responsibility | Required server configuration |
|---|---|---|
| `create-user` | Staff-authorized Auth/profile creation | Supabase URL, anon key, service-role key; Auth mail settings |
| `manage-user` | Account update, reset/verification resend, deletion | Same Supabase secrets; role authorization |
| `provision-test-users` | Controlled test bootstrap | `BOOTSTRAP_SECRET`; should be restricted/removed in production |
| `send-fcm-notification` | Generic authorized in-app + push delivery | FCM project ID, client email, private key |
| `notify-geofence` | Fan-out a stored gate event to staff/guardians | Supabase service role and FCM secrets |
| `notify-message` | Fan-out a stored message to permitted recipients | Supabase service role and FCM secrets |
| `cloudinary-media-upload` | Signed protected upload | Cloudinary cloud name/key/secret plus Supabase secrets |
| `cloudinary-media-url` | Authorized short-lived media access | Same Cloudinary/Supabase secrets |
| `cloudinary-media-delete` | Authorized deletion | Same Cloudinary/Supabase secrets |

All functions must validate bearer tokens and role/relationship claims on the server. CORS headers do not provide authorization.

## 26. Database inventory by domain

| Domain | Tables |
|---|---|
| Identity | `profiles`, `tenant_details`, `staff_details`, `guardian_tenant_links` |
| Rooms | `rooms`, `bed_spaces`, `tenant_assignments` |
| Contracts/onboarding | `tenant_contracts`, `tenant_onboarding_invitations`, `contract_requirements`, `contract_signers`, `contract_documents` |
| Finance | `billing_charges`, `payment_transactions`, `payments`, `rent_rate_overrides`, `rent_charge_adjustments`, `utility_charge_batches`, `utility_charge_batch_items`, `utility_charge_allocations` |
| Maintenance | `maintenance_reports`, `maintenance_staff_history` |
| Gate/curfew | `gate_events`, `dorm_boundary_config`, `curfew_requests`, `employee_curfew_profiles`, `employee_curfew_profile_events` |
| Visitors | `visitor_requests`, `visitor_events` |
| Messaging | `conversations`, `messages` |
| Communications | `announcements`, `push_device_tokens`, `app_notifications` |
| Confidential concerns | `confidential_reports`, `confidential_report_audit` |
| Cleaning | `cleaning_schedules`, `cleaning_noncompliance_reports`, `cleaning_report_history` |
| Inspections | `room_inspections`, `room_inspection_findings`, `room_inspection_evidence` |
| Conduct | `conduct_cases`, `conduct_case_responses`, `conduct_case_warnings`, `conduct_case_events`, `conduct_case_evidence`, `conduct_case_appeals` |
| Governance | `retention_policy_settings`, `retention_policy_events` |

Note: `visitor_requests`, `maintenance_reports`, and `tenant_details` are introduced/extended across multiple migrations. Check the final deployed shape, not only one migration file.

## 27. Backend verification checklist

### A. Migration and schema integrity

- [ ] Every file in `supabase/migrations` is recorded as applied in the target project in filename order.
- [ ] All tables in section 26 exist with their final columns, defaults, foreign keys, checks, and indexes.
- [ ] RLS is enabled on every user/business table and every private Storage path.
- [ ] Helper functions use a safe `search_path`; `SECURITY DEFINER` functions explicitly authorize `auth.uid()` and role/relationship.
- [ ] Trigger inventory includes timestamp updates, gate summary sync, conversation summary sync, contract onboarding/billing/date sync, and audit/history creation.
- [ ] Direct grants do not bypass RPC-only workflows.

### B. Auth and roles

- [ ] Create one test user for each role and verify Auth UUID equals `profiles.id`.
- [ ] Tenant and staff detail rows are created for the correct roles.
- [ ] Invalid/missing profiles fail closed.
- [ ] Recovery and confirmation redirects work on mobile and web.
- [ ] Tenant, guardian, caretaker, and owner negative-access tests return no unauthorized rows.

### C. Storage and external media

- [ ] Required buckets exist and are private: contract documents/requirements, maintenance photos where used, inspection evidence, and conduct evidence.
- [ ] Upload, read, update, and delete policies are tested separately for every role.
- [ ] Cloudinary secrets are deployed and URLs are signed/expiring.
- [ ] Failed metadata writes do not leave persistent orphan files in normal flows.

### D. Realtime

- [ ] Required tables are in `supabase_realtime`: at minimum messages/conversations, notifications, and gate events used by live screens.
- [ ] Realtime respects RLS for each role.
- [ ] Batch changes produce one debounced refresh rather than uncontrolled query loops.

### E. Edge Functions and secrets

- [ ] All functions in section 25 are deployed at versions matching this repository.
- [ ] `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are available only server-side where required.
- [ ] FCM and Cloudinary secrets are present and valid.
- [ ] `BOOTSTRAP_SECRET` is strong and the provisioning function is disabled/restricted when not needed.
- [ ] Function logs show authorization failures for anonymous/incorrect-role calls.

### F. End-to-end business scenarios

- [ ] Staff creates tenant -> tenant verifies email -> onboarding invitation is claimed -> requirements/signers complete -> contract activates -> rent charge appears once.
- [ ] Tenant submits payment proof -> staff approves -> balance changes and immutable audit facts remain protected.
- [ ] Tenant submits maintenance with photo -> staff transitions it -> history and authorized photo access work.
- [ ] Tenant requests visitor -> staff approves/checks in/out -> events are preserved.
- [ ] Tenant requests curfew exception -> guardian/staff approve -> gate event in approved window is classified correctly.
- [ ] Native/foreground geofence inserts an append-only event -> summary updates -> staff/guardian notification is created.
- [ ] Tenant/guardian message -> conversation metadata/read state updates -> correct recipient gets in-app/push notification.
- [ ] Cleaning, inspection, conduct, appeal, and retention changes each create the expected audit/event row.

### G. Automated checks already in the repository

Run from the repository root:

```powershell
flutter pub get
flutter analyze
flutter test
powershell -ExecutionPolicy Bypass -File tool/phase5b_integration_readiness.ps1
powershell -ExecutionPolicy Bypass -File tool/contract_remote_smoke_test.ps1
powershell -ExecutionPolicy Bypass -File tool/visitor_remote_smoke_test.ps1
```

The remote scripts may require environment variables or test credentials. Read them before running against production; use a staging project when they create records.

## 28. High-risk configuration mismatches to look for first

1. **Migrations present locally but not deployed.** New screens then fail with missing table/function/column errors.
2. **RLS too broad or too narrow.** Too broad leaks tenant information; too narrow looks like empty data and can be mistaken for no records.
3. **Auth role/profile mismatch.** Login succeeds but role routing or RPC authorization fails.
4. **Missing Edge Function secrets.** Core rows may save while push/media/account administration silently fails or returns function errors.
5. **Realtime publication missing.** Data is correct after manual refresh but live screens appear stale.
6. **Private bucket policy mismatch.** Metadata exists but images/documents cannot be uploaded or viewed—or are accidentally public.
7. **Wrong boundary coordinates/permissions.** Geofence logic works technically but reports incorrect presence.
8. **Timezone mismatch.** Curfew and visitor rules must consistently use `timestamptz` with Asia/Manila business interpretation.
9. **Preview/demo entry point deployed.** A convincing UI may run entirely from local demo data.
10. **Retention settings without an executor.** Policies can be saved and audited while old records are never actually purged.
11. **Announcement push assumed to be production-proven.** Automatic dispatch is implemented, but staging secrets, audience fan-out, and physical-device delivery still require verification.
12. **Guardian alert assumed to be a backend feature.** Guardian alert state is process-local and informational only.
13. **Boundary editing RPC missing from migrations.** The client calls `update_dorm_boundary_config`, but the intended migration file is empty and no repository SQL defines the function.

14. **Platform parity assumed from shared Flutter UI.** Android currently has stronger background geofence delivery; iOS push configuration and native background upload are incomplete.

## 29. Final configuration standard

The backend is properly configured only when all four statements are true:

1. The deployed schema/functions match the complete migration chain.
2. Positive flows succeed for the intended role.
3. Negative tests prove every other role and anonymous callers are denied.
4. Side effects—history, summary triggers, Storage cleanup, Realtime refresh, in-app notifications, and optional push delivery—produce the expected results.

A successful screen render or successful insert alone is not sufficient evidence. Verify authorization, derived state, audit history, and failure behavior for each workflow.

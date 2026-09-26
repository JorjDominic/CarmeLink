# CarmeLink System Completion Audit

> Snapshot only. Use [`STATUS.md`](STATUS.md) for the maintained status and acceptance tracker.

> Audited from the repository on September 25, 2026.  
> This separates **prototype completeness**, **production code readiness**, and **verified deployment readiness**. A working UI is not treated as proof that the remote backend is correctly deployed.

> **Ownership note (September 26, 2026):** Jorj Dominic retains FCM/push,
> tenant onboarding/contracts, and geofencing. Japle Ligaya owns every other
> open module and production-cleanup item, with cross-cutting verification split
> so each developer covers only their assigned scope. `STATUS.md` contains the
> authoritative task-level assignments and acceptance criteria.

## Japle merged-work source reconciliation — September 27, 2026

The current `main` tree and Git history were re-audited because earlier Japle
commits were merged before every planning file was updated. These checkmarks
mean **implemented in repository source/history**, not production-deployed or
remotely verified:

- [x] Tenant maintenance CRUD, photo evidence, history, and pending edit/cancel.
- [x] Visitor request/review/history plus one-calendar-day lead time,
  9:00 AM–9:00 PM policy, same-day departure, and arrival/departure logging.
- [x] Bed-based cleaning schedules and private missed-duty reporting.
- [x] Monthly/follow-up room inspections with three-day notice, evidence,
  findings, corrective actions, and follow-up.
- [x] Conduct cases with evidence/responses/warnings/history and separate appeals.
- [x] Non-destructive retention settings/configuration and audit trail.
- [x] Tenant My Room and Guardian linked-tenant room/payment views.
- [x] Tenant payment-proof upload and on-device receipt OCR.
- [x] Tenant/Guardian announcements and role-scoped persistent messaging.
- [x] Reports/PDF infrastructure and public/staff web surfaces in source.
- [x] Production `MockData` dependency removed.

Still **not** closed by this source audit:

- [ ] Immediate `STATUS.md` Tasks 1–5 and UI-1–UI-6 that remain open in current source.
- [ ] End-to-end move-out/settlement workflow.
- [ ] Tenant/Guardian permitted self-profile editing and persisted notification preferences.
- [ ] In-app notification deep-link navigation and Guardian personal-alert persistence/scheduling.
- [ ] Remote migration/RLS/RPC/Storage/Realtime/staging verification for non-reserved modules.
- [ ] Android production signing/AAB, production web/session proof, CI cleanup, and operational readiness.

Do not downgrade any remaining production gap merely because its UI/service is
present locally.

## Executive verdict

| Target | Current estimate | Verdict |
|---|---:|---|
| Functional prototype/demo | **92%** | Strong prototype; primary dormitory workflows are implemented, with visible placeholders clearly tracked. |
| Demo/staging deployability | **76%** | Local checks pass, but migrations, functions, secrets, and multi-role remote workflows still need staging proof. |
| Android production readiness | **58%** | Core Android code exists; release signing, secure token storage, physical FCM/geofence tests, and operational controls remain. |
| Full Android+iOS production readiness | **42%** | iOS Firebase/APNs/signing and autonomous background-delivery evidence remain incomplete. |
| Verified production deployment | **Not established** | Remote migrations, RLS, Realtime, secrets, Storage policies, device delivery, and production signing were not verifiable from local source alone. |

These percentages are evidence-based ranges, not story-point completion. Prototype scoring emphasizes demonstrable workflows. Production scoring gives greater weight to security, negative authorization tests, release configuration, failure recovery, privacy, and deployed infrastructure.

## What is already strong

- Supabase-backed authentication and four-role routing exist.
- Rooms, beds, tenant assignments, guardian links, and tenant directory services exist.
- Contracts, invitations, requirements, signers, documents, billing synchronization, and payment review are implemented.
- Tenant/staff maintenance, visitors, curfew requests, gate events, messaging, confidential concerns, cleaning, inspections, conduct cases, appeals, and retention settings have database-backed service layers.
- RLS, server RPCs, triggers, audit/history tables, protected Storage, Realtime, Cloudinary, and FCM infrastructure are represented in migrations/functions.
- Android native background geofence queuing and WorkManager synchronization are implemented.
- The project passes `flutter analyze` and all **410** local tests.
- A debug Android APK builds successfully.
- The prior app-usage tracking feature and permission were fully removed.
- Unreachable mock data, unsafe scratch code, and unused assets were removed.

## Completion by system area

| Area | Prototype | Production | Current assessment |
|---|---:|---:|---|
| Authentication and role routing | 95% | 70% | Login, restore, verification, recovery, and role shells exist. Production redirect/email configuration and live negative-role testing remain. |
| Account administration | 90% | 65% | Create/manage Edge Functions exist. Service-role handling and destructive actions need deployed-function verification and audit testing. |
| Rooms, beds, assignments, directory | 95% | 75% | Live services/RPCs and constraints exist. Needs live concurrency and RLS tests. |
| Contracts and onboarding | 90% | 65% | Broad workflow and documents exist. Needs Storage/RPC deployment verification and full activation test. |
| Billing and payments | 90% | 60% | Charges, submissions, verification, utilities, overrides, and OCR exist. Financial reconciliation and idempotency require staging evidence. |
| Maintenance | 90% | 65% | Tenant/staff flow and history exist. Media path and transition authorization need live verification. |
| Visitors | 95% | 75% | Server policy and smoke script are strong. Remote execution is still required. |
| Curfew requests | 90% | 65% | Tenant/guardian/staff review flow exists. Timezone and exception behavior need physical/live tests. |
| Gate/geofence | 80% | 40% | Foreground and native adapters exist, but polygon/circle semantics differ and iOS lacks Android-equivalent background upload. |
| Messaging/read receipts | 90% | 60% | Realtime service and notification hook exist. Publication, RLS, and push delivery need live multi-role tests. |
| Announcements | 90% | 55% | CRUD and audience-targeted dispatch are wired; staging recipient and physical-device delivery remain unverified. |
| In-app/push notifications | 82% | 45% | Core event hooks, authorized fan-out, token lifecycle, and Android handlers exist; several secondary modules lack hooks, one shortcut remains obsolete, and live Android/iOS delivery is unverified. |
| Guardian portal | 90% | 65% | Linked tenant, payment, curfew, gate, and messaging views exist. Relationship isolation needs live testing. |
| Cleaning and inspections | 85% | 55% | Full RPC/table workflows exist. Physical/staging workflow and evidence-bucket tests remain. |
| Conduct and appeals | 85% | 50% | Case/audit/evidence/appeal workflows exist. Policy acceptance and deployed access tests remain. |
| Retention/privacy | 55% | 25% | Configuration and audit exist; deletion/anonymization is intentionally hard-disabled and no executor exists. |
| Reports/PDFs | 85% | 55% | Multiple reports generate client-side. Financial totals and access boundaries need reconciliation tests. |
| Public website/staff web | 85% | 60% | Public site, staff gate/workspace, responsive tests, and separate demo entry exist. Deployment entry point and production session behavior need confirmation. |
| Android release | 85% prototype | 55% production | Debug APK builds and Firebase/geofence support exist. Release still uses debug signing. |
| iOS release | 70% prototype | 30% production | Native region monitoring exists, but Firebase plist, production APNs/signing, and autonomous background sync are incomplete. |

## Prototype blockers and visible inconsistencies

These should be resolved before a formal demonstration or defense because they can visibly fail or contradict the paper.

1. **Boundary editing calls a missing RPC.** `BoundaryConfigService` calls `update_dorm_boundary_config`, while `202609250002_boundary_config_editable.sql` is empty and no migration defines the function.
2. **Announcement push is not live-verified.** Repository dispatch is implemented, but deployed functions, secrets, audience fan-out, and device delivery need staging proof.
3. **Two notification experiences disagree.** The primary `NotificationsPage` reads live `app_notifications`, but the header/global notification route in `common_widgets.dart` opens `_GlobalNotificationsPage`, which always displays “not connected yet.”
4. **Device binding is a placeholder.** The page displays a button but does not create a trusted-device record or hardware binding. Native geofence registration is a separate mechanism.
5. **Emergency contact calling is a placeholder.** Contact data displays, but the Call action only shows a snackbar.
6. **Curfew/geofence screens visibly label parts of the workflow WIP.** This is honest, but it means those features should be demonstrated as under physical-device validation.

## Production release blockers

### Backend and security

- The remote migration list has not been proven equal to the local migration chain.
- The final migration file is empty, making a fresh environment non-reproducible for boundary editing.
- Live RLS negative tests have not been evidenced for every role/table/bucket.
- Realtime publication and RLS behavior are not verified against the actual project.
- FCM, Cloudinary, service-role, and bootstrap secrets cannot be confirmed from source.
- Storage bucket privacy, MIME/size limits, and object-path isolation need live testing.
- Retention enforcement does not exist; documentation must not promise automatic deletion.
- `provision-test-users` should be restricted or removed from production exposure.

### Mobile releases

- Android release builds use the debug signing key.
- iOS has no repository `GoogleService-Info.plist`.
- iOS APNs entitlement is fixed to `development`, and no development team is committed.
- iOS native geofence transitions queue locally but have no Android-equivalent native background uploader.
- Android stores background-worker Supabase access/refresh tokens in ordinary `SharedPreferences`, not platform-secure storage.
- Both native tripwires use circles even when the official configuration is polygonal; Android expands its circle to at least 100 m.
- Physical-device tests are required for denied permissions, killed app, reboot, offline crossing, token expiry, battery restriction, and push-open routing.

### Operations and reliability

- No production monitoring/alerting, crash reporting, backup-restore drill, incident process, or service-level target is evidenced here.
- No automated retention executor or cleanup evidence exists.
- Remote smoke tests require staging credentials and intentionally create temporary records; they have not been run in this audit.
- There is no evidence of load/concurrency testing for assignment, billing, messaging, or batch utility operations.
- Environment separation is weak: the Supabase project URL/key are compiled directly into the client configuration rather than selected by an explicit environment profile.

## Recommended route to a defensible prototype

Complete these in order:

1. Decide whether boundary editing belongs in scope. Implement its RPC migration or remove the editor.
2. Deploy the FCM functions/secrets and verify announcement and core-module delivery on physical Android devices.
3. Make every notification button open the live `NotificationsPage`; remove the placeholder implementation.
4. Either implement device binding and phone launching or label/remove those actions from the defense build.
5. Update README/progress/paper statements so they match the repository exactly.
6. Run all local checks and the three staging integration scripts.
7. Conduct one scripted walkthrough for each role, including expected authorization failures.

At that point, the prototype should be approximately **92–95% defense-ready**, assuming the staging backend matches the migrations.

## Recommended route to production

After prototype cleanup:

1. Repair migration reproducibility and deploy to a clean staging Supabase project.
2. Execute a role-by-role RLS/Storage/RPC test matrix, including anonymous access.
3. Reconcile circular versus polygon geofence behavior and complete physical-device validation.
4. Configure Android release signing and complete iOS Firebase/APNs/team provisioning.
5. Secure native token storage and define logout/token-rotation cleanup.
6. Implement or formally defer retention enforcement after privacy/legal review.
7. Add crash reporting, backend monitoring, backups, restoration testing, and operational runbooks.
8. Run release-mode Android and iOS builds, device tests, and store-compliance reviews.
9. Perform a limited pilot with non-production/test data before accepting real tenant data.

## Verification evidence from this review

```text
flutter analyze                  PASS (no issues)
flutter test                     PASS (410 tests)
flutter build apk --debug        PASS
Android Firebase config          PRESENT
iOS Firebase config              MISSING
Android production signing       NOT CONFIGURED (debug key used)
Boundary editor migration        MISSING/EMPTY
Remote migrations/RLS/secrets    NOT VERIFIED
```

## Bottom line

CarmeLink is already beyond a UI-only prototype: most core workflows have real service and database designs. It is suitable for a controlled prototype demonstration after the visible Tier-1 inconsistencies are fixed. It should **not** yet handle real production tenant data or be represented as production-ready until backend deployment, authorization, mobile release, privacy, geofence, and operational controls are verified.

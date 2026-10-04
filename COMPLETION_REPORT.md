# CarmeLink completion assessment

Assessment date: October 4, 2026 (Asia/Manila).
Source baseline: `9d81002`, branch `geofencing-main-new`.

Estimated completion of the current scoped project: **85%**, with a reasonable assessment range of **80–90%**. This is an engineering estimate based on implementation, remaining acceptance work, and available verification. It is not a measured percentage of every requirement or a production certification.

This report is a dated assessment. `STATUS.md` remains the canonical backlog. Its historical unchecked items must be reconciled with current source before treating them as missing features.

## Basis for the estimate

The ten areas below receive equal weight for this assessment; their estimated scores average to 85%. Scores reflect implemented workflows and remaining acceptance work, rather than file counts or test pass rates. Unverified live behavior is not credited as fully complete. Capstone 2 work explicitly deferred in `STATUS.md` is excluded from the current feature scope, but relevant deployment and safety gaps still affect release readiness.

| Area | Estimate | Implementation evidence and remaining work |
|---|---:|---|
| Authentication, roles, and profiles | 95% | Role routing, account management, recovery tests, and protected self-profile editing exist. Live role-isolation and complete recovery/onboarding acceptance remain. |
| Residents, guardians, rooms, and beds | 95% | Live assignments, linked-tenant views, guardian links, and room management exist. Cross-role relationship isolation still needs live verification. |
| Contracts, onboarding, and move-out | 90% | Document/signature workflows, activation safeguards, and move-out settlement exist. PDF Unicode warnings and complete live lifecycle verification remain. |
| Billing and payments | 90% | Charges, payment proof/OCR, verification, and billing-center workflows exist. Deposit policy needs reconciliation and remote financial acceptance remains. |
| Maintenance and room operations | 90% | Maintenance, cleaning rotation, room inspection services, UI, migrations, and tests exist. Live media/RLS checks and remaining lifecycle edge cases need acceptance. |
| Visitors, curfew, conduct, and safety | 85% | Visitor policy/review, guardian overnight decisions, staff late-return review, confidential reports, conduct cases, and appeals exist. Live cross-role workflows and policy edge cases remain. |
| Messaging, announcements, and notifications | 85% | Live notification navigation, role-scoped messaging, guardian preferences, and FCM functions exist. Location-off guardian alerts are deployed. Physical push delivery and reconnect behavior remain unverified. |
| Geofencing and monitoring health | 80% | Native Android/iOS polygon confirmation, reconciliation, queueing, health incidents, and alerts exist. Physical background/offline/reboot/permission tests and native credential protection remain. |
| UI, reporting, and web integration | 80% | Role interfaces, staff/public web source, responsive tests, report/PDF infrastructure, and live summaries exist. Full route/state/text-scale acceptance and report/export scope reconciliation remain; feedback is explicitly a preview. |
| Deployment, security, and release acceptance | 60% | Linked database reports no pending migrations and deployed function is active. Production signing, live access-control/storage/realtime matrices, device tests, and operational proof remain. |

## Checks performed for this assessment

| Check | Result |
|---|---|
| Full `flutter test` suite | **Passed: 553 tests** |
| `flutter analyze` | **Passed: no issues found** (143.7 seconds). |
| `tool/status_guardrails.ps1` | **Passed**: prohibited tracking absent, boundary RPC contract present, announcement dispatch wired, obsolete notification page absent, retention enforcement disabled. |
| `tool/phase5b_integration_readiness.ps1 -SkipSupabase` | **Stopped at branch allowlist**: current branch `geofencing-main-new` is not among `japel`, `main`, or `web`. Later checks did not execute. This is a script restriction, not evidence of a broken application workflow. |
| Remote database migration check during deployment | **Passed**: `supabase db push --linked --dry-run` reported the database up to date after the new migration. This confirms migration-history parity, not a complete live schema/policy audit. |
| Location-monitoring Edge Function | **Deployed and ACTIVE** on project `iuplkgvitovzjbmtzpme`. Unauthenticated POST returned **401**. An authorized processing run and actual guardian device receipt were not verified. |
| Physical Android/iOS validation | Not performed in this assessment. |
| Release builds and production signing | Not performed in this assessment. |

## Latest delivered change

The migration `202610040001_location_off_guardian_notifications.sql` adds `guardian_notified_at` and an index for pending guardian notifications. Existing escalations are backfilled to avoid sending another initial alert.

`process-location-monitoring-alerts` now selects unresolved incidents awaiting an initial guardian notification, in addition to incidents due for the existing 30-minute escalation. It selects guardians through `guardian_tenant_links` for the affected tenant and creates in-app notifications and FCM requests. Initial alerts run on the existing five-minute schedule after the device reports the outage. The existing 30-minute staff/guardian escalation remains.

Both migration and function deployment succeeded. Scheduler execution, authorized processing, FCM configuration, and physical receipt still require end-to-end evidence. Delivery depends on connectivity and the phone successfully reporting monitoring health.

## Remaining work in priority order

1. **Prove guardian notification delivery.** Test GPS off and permission denial with linked and unrelated guardians, foreground/background receipt, notification opening, outage repetition, recovery, and the 30-minute escalation. Verify cron runs and FCM outcomes.
2. **Complete physical geofence tests on both platforms.** Cover entry/exit, edges, background, offline retry, reboot, revoked permissions, battery restrictions, and Android launch-time recovery after Settings Force Stop. The app cannot run while Android keeps it Force Stopped.
3. **Complete live security and realtime checks.** Test positive and negative permissions for all four roles and anonymous callers across tables, RPCs, functions, private storage, and realtime subscriptions. Protect native background credentials; Android currently stores access/refresh tokens in ordinary SharedPreferences.
4. **Prepare production mobile releases.** Android release configuration still uses debug signing. iOS APNs entitlement is development; production Apple signing/APNs and Firebase configuration need verified release evidence.
5. **Resolve confirmed product and data-quality gaps.** Contract PDF tests emit Helvetica Unicode warnings. The contract-billing migration creates deposit charges despite the documented request not to collect them through Payments; reconcile current database behavior and legacy rows. Feedback currently validates a preview without persistence. Ensure simulation tools cannot contaminate operational history.
6. **Finish acceptance and reconcile documentation.** Profile editing, live notification navigation, planned device-binding labeling, and cleaning rotation now have source/test evidence despite older open tracker entries. Update those entries with acceptance evidence. Reconcile report/export requirements, complete UI state coverage, and decide whether the readiness script should accept this working branch.
7. **Evidence operational readiness before production.** Confirm backup/restore, monitoring, rollback procedures, incident ownership, and staging/production separation.

## Deferred scope

Trusted-device binding, automatic retention deletion/anonymization, employee-curfew profiles automatically changing gate classification, and proposed Wi-Fi beacon fallback must not be presented as completed production features. Retention configuration is intentionally non-destructive. Some deferred native geofence work now exists in source, but its production guarantees still depend on device validation.

## Assessment conclusion

CarmeLink has most of its core application workflows implemented and a passing automated test suite. **85% is a defensible planning estimate for the current scope.** The remaining work is largely acceptance, device/platform proof, release hardening, and specific product gaps. Production readiness remains unconfirmed until the live security and physical-device gates are satisfied.

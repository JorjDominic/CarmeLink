# Focused Phase 1-3 production handoff (2026-10-09)

Original audit: no production writes or Git operations in main. Finalization: only the verified curfew list fix, its regression test and these read-only verification files were transferred to japelbranch for authorized local commits. No push, deployment or branch switch; unrelated changes preserved.
Previous 44 Flutter / 21 isolated SQL checks are reused, not represented as live verification.

## Confirmed observations and fix

- Public-key, zero-row REST probes now return 42501 (anonymous SELECT denied) for room_floors, curfew_requests and app_notifications. Floor's earlier PGRST205 was not reproduced. Do NOT grant anon SELECT in response to the API hint. These checks do not verify authenticated grants, columns, RLS, triggers or record counts.
- Curfew list methods swallowed database/network exceptions and returned empty success, bypassing existing controller error/retry handling. Removed that catch in Tenant, Staff and Guardian lists. Local HTTP regression tests verify 403 errors propagate and successful empty responses remain valid. Existing approval/return/notification behavior unchanged.
- Production web returns HTTP 200; its root page contains no inspected commit/build identifier. This is NOT proof that deployed code matches japelbranch.
- New rooms.floor FK requires an existing floor. Old clients that allow arbitrary new floor text will fail safely. Deploy compatible app builds after verification; do not remove the FK or deletion guards.

## Manual read-only verification

In SQL Editor of configured project iuplkgvitovzjbmtzpme:
1. Run supabase/tests/phase123_production_readiness_readonly.sql; run its final catalog queries separately only if the first query confirms those catalogs exist. No RPCs that send alerts are executed. NULL required signatures or disabled/missing triggers need investigation. Manual SQL Editor migrations may be absent from migration history even when objects exist.
2. Run existing supabase/tests/phase3_floor_management_preflight.sql. Compare counts to supplied predeployment baseline: 15 rooms, 60 beds, 9 assignments, 5 active assignments. Any drift needs reconciliation with legitimate activity, not automatic rollback/deletion.
3. Compare actual function/trigger definitions and grants to the existing source migrations. Resolve differences with leader review; do not blindly reapply non-idempotent migrations.

Dependency order to verify, not a bulk deployment instruction:
- Phase 1: existing curfew request/types, guardian preferences and 202610050002_curfew_staff_fallback_acknowledgment.sql; 202610070012_notification_coverage_completion.sql helpers; 202610080008_curfew_return_and_reminders.sql. Its reminder scheduler is intentionally not activated by the migration.
- Optional implemented nightly snapshot: 202610080007_nightly_curfew_status.sql needs notification helpers, private.dispatch_report_pushes and pg_cron. It is distinct from actual return recording and never writes actual_return_time.
- Phase 2: 202609250001_fcm_notifications.sql; notification realtime/publication migrations; 202609281731_phase2_notifications_and_maintenance.sql; existing report/cleaning/inspection/conduct/appeal and staff report-access migrations; 202610070003_report_alerts.sql, 202610070005_report_push_delivery.sql, 202610070012_notification_coverage_completion.sql; 202610090001_phase2_saved_report_notifications.sql.
- Phase 3: existing configuration/addenda/idempotency, fixed beds, room identity and conduct RPC migrations; 202610090002_phase3_report_and_room_safety.sql. User reports Phase 2/3 deployed; full live definitions remain unverified here.

Expected jobs: curfew-return-reminders every 5 minutes, report-push-delivery every minute; nightly-curfew-status at 0 15 * * * (23:00 Asia/Manila under UTC cron). Verify active status, command target in the private dashboard, UTC cron configuration and successful recent runs. Do not share commands if they include secrets. If reminder job is absent, after controlled/approved recipient testing use existing ops_manual_sql/03_enable_reminders_after_approval.sql once; do not create duplicate jobs.

Edge Functions dashboard: verify send-fcm-notification and process-report-pushes deployed, worker's verify_jwt=false plus its internal hashed bearer authentication, private dispatch endpoint matching this project, and required FCM_PROJECT_ID/FCM_CLIENT_EMAIL/FCM_PRIVATE_KEY secrets configured (names only; never expose values). In-app notifications can succeed while pushes fail. Queue/cron claim execution is not a read-only test. Review dashboard worker logs without disclosing tenant payloads/tokens.

Realtime: app_notifications publication is required for immediate inbox/badge updates; other monitored tables appear in the query. Floor publication is optional because local refresh and polling exist. SQL publication presence alone does not prove actual authorized delivery.

## Outstanding acceptance checks

Authenticated Owner/Caretaker/Tenant/Guardian sessions: RLS isolation, guardian link revocation, all notification types/taps/read-all/badges, missing records, controlled successful and failed saves. Stage concurrent requests/return edits/resolve-addendum/room assignment-delete, duplicate submissions and full-schema deletion dependencies; do not create test rows in production automatically. Verify web release artifact/deployment commit against japelbranch and supported mobile versions. Test Android/iOS push foreground/background/terminated taps, then verify restore on disposable staging from the existing backup.

Focused results: curfew_load_failure_test.dart 3 passed; phase1_curfew_return_contract_test.dart 4 passed. Initial audit test harness setup failed (Flutter HTTP interception/storage mock), corrected and rerun. Final transferred implementation: the same 7 affected tests passed together on japelbranch. Original audit flutter analyze --no-pub: no issues; git diff --check: passed. No newly confirmed critical defect; production readiness remains NOT VERIFIED until authenticated/live checks above are completed.

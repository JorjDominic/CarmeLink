# Phase 3 floor blocker and manual setup

Live, read-only API probe against configured project `iuplkgvitovzjbmtzpme` returned HTTP 404, `PGRST205`: `public.room_floors` was not found in the schema cache. `RoomService.listFloors()` fails, and the page correctly keeps Add Floor disabled when loading fails. This is not proof that the table is physically absent: missing migration, wrong project/version, or stale PostgREST metadata must be distinguished with SQL Editor checks. The probe used the app's public key, not an authenticated Owner session; no private rows were requested.

## Verify before applying

1. Open SQL Editor in the **same project** as the app. Run [read-only preflight/postflight queries](../supabase/tests/phase3_floor_management_preflight.sql). Save the baseline room/bed/assignment counts and review existing FKs/triggers. Do not change data to force preflight checks to pass.
2. Required source migration: **`202610090002_phase3_report_and_room_safety.sql`**. Dependencies include `202610070009_room_expansion_and_dynamic_capacity.sql`, `202610070011_dynamic_configuration_and_room_identity.sql`, `202610070006_dormitory_configuration_and_report_addenda.sql`, and `202610070007_confidential_addenda_idempotency.sql`, plus existing role helpers. Verify their objects, rather than assuming migration history alone proves installation.
3. New registry: `public.room_floors(name)` with normalized-name uniqueness, authenticated SELECT and staff-only RLS. Public RPCs: `create_room_floor(text)`, `manage_room_floor(text,text,integer,boolean)`, `safe_delete_room_floor(text)`, `safe_delete_room(uuid)`. Existing `rename_room_floor(text,text,integer)` stays compatible. Structural room/bed guards and resolved-addenda guard must be present.
4. If the registry/RPCs are **absent** and baseline objects/data match, validate the complete migration on disposable full-schema staging first. With approval and a recoverable database backup, paste the **entire** reviewed migration, including BEGIN/COMMIT, into SQL Editor and run once. No application/tenant/history rows are deleted by applying it; registry backfill retains existing floor labels and room/bed IDs. It changes future deletion behavior, so full-schema dependencies and structural triggers require review. Ambiguous labels fail/roll back rather than silently merging records.
5. If objects already exist or only some exist, **do not blindly rerun**: CREATE TABLE is intentionally not idempotent. Compare the actual definitions/grants/constraints with source and investigate the version mismatch with the leader. A failed migration transaction must be rolled back before retrying a corrected, reviewed script.
6. If all objects/grants are correct but `PGRST205`/`PGRST202` persists, the user/admin may manually run `NOTIFY pgrst, 'reload schema';` in SQL Editor. Refresh/retry the app after metadata reload. This is a cache refresh, not a substitute for creating missing objects.
7. Rerun postflight checks. Baseline room, bed, assignment and active-assignment counts must be unchanged. `rooms_floor_registry_fkey` must exist; `bed_spaces_room_id_fkey` must use RESTRICT, not CASCADE. Verify authenticated RPC execution, staff SELECT policy, owner checks inside write RPCs, and that direct registry writes remain denied. Sign in as an actual Owner and use Retry/Refresh; do not test write RPCs under SQL Editor's elevated role as proof of app authorization.

Realtime publication is optional for immediate cross-client floor updates; the existing subscription has a 30-second polling fallback and successful actions refresh locally. If the leader wants immediate floor-only events, they may separately review adding `public.room_floors` to the existing `supabase_realtime` publication. This task does not modify the publication automatically.

## Manual checklist — live testing PENDING

- Add an empty floor; duplicate case/whitespace name is rejected.
- Rename it; existing rooms keep IDs, beds, residents and original floor-plan drawing slots.
- Move a room via Edit Room's existing-floor dropdown; then explicitly merge floors with affected-room confirmation.
- Delete an empty floor; deletion of any floor containing active **or archived** rooms is blocked (occupied-floor deletion included).
- Verify local refresh, another client's realtime/polling update and failed-save behavior. Caretaker/tenant/guardian cannot perform structural writes.
- Attempt room deletion with assignment/inspection/maintenance/cleaning history: blocked, no record loss. Validate concurrency in staging, not by destructive production experiments.

No production SQL was executed by the assistant. Source review and isolated PostgreSQL tests are not proof of the deployed schema or successful live Owner integration. Deployment and live Floor Management testing remain **PENDING** until the user completes these steps.

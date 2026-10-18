# System maintenance and repeated violations

Deployment update, October 19, 2026: migrations 202610190002–202610190005 are
now applied to the linked sample-data database. Twenty-two rollback-only live
role checks passed. A dedicated staff tenant register, independent maintenance
message saving and the current agreement scope are implemented. See
[current system scope](current-system-scope.md) for the current status; the
implementation/validation history below records earlier local-only work.

Implemented locally on October 19, 2026. No live migrations or deployment performed.

## Tenant conduct status

Staff Conduct lists now show each tenant's confirmed incident counts and a filter
for repeated/continuous violations. The case investigation panel shows the same
status to authorized staff and the affected tenant.

- Repeated violations: at least two confirmed incidents across recorded history.
- Continuous violations: at least three confirmed incidents within the previous
  90 days, based on incident dates, inclusive of the start boundary.
- Only the latest explicit owner investigation outcome counts. Drafts, allegations,
  warnings, dismissed cases, overturned outcomes and future incidents do not count.
- Linked duplicate incidents count once; their earliest currently confirmed
  incident date is used so newer duplicates cannot extend the 90-day window.
- Accepted appeals alone retain the outcome until an owner records an overturn.
- Flags are derived at read time, so expiry and corrections are reflected on
  refresh. Existing page subscriptions refresh approximately every 30 seconds.
- Residency, contracts and accounts are unchanged by these flags. Existing warning,
  termination recommendation and owner eviction workflows remain separate.

## System maintenance

Mobile Operations → Reports & Cases → System maintenance; staff web portal →
Administration → System maintenance.

Both staff roles can open existing account and security/retention tools and read
maintenance status and the latest 100 maintenance audit events. Existing account
and retention permissions continue to apply. Owner-only configuration tools,
maintenance-mode changes and backup/restore are enforced by backend permissions.

Maintenance mode pauses tenant/guardian access across the updated mobile app's
Navigator, including open routes. Staff can still sign in and end maintenance.
Availability is checked on login, resume, manual retry and every 30 seconds.
Pending or failed initial checks leave the workspace available, including when
the settings migration is absent. Subsequent failures retain the last successfully
confirmed state; background polling continues. Only a confirmed enabled setting
shows the maintenance screen. This is an app availability gate, not a
database/API shutdown; older clients, integrations and background services are
not suspended. The web portal is staff-only and remains available.

Backups are immutable server snapshots of **custom dormitory options** (labels,
instructions, ordering and active status), with downloadable JSON exports.
Restore uses a saved server snapshot and automatically saves the current options
first, within the same transaction. Identity mismatches or constraint conflicts
abort the entire restore. Newer options absent from the snapshot stay unchanged;
system options, accounts, resident data, files and maintenance mode are excluded.
The UI labels this scope explicitly. Restore does not import exported JSON.
Full database, authentication and file backup/recovery remains a hosting-platform
operation; this screen does not implement full disaster recovery.

## Validation and rollout

Apply `202610190002_repeat_violation_status.sql`, then
`202610190003_system_maintenance.sql` after the existing migrations before
releasing the updated client. Both are additive; historical outcomes are retained.

- Disposable PGlite harness: 24 checks passed, including existing conduct/evidence/
  agreement regressions, repeat rules, duplicate incidents, appeal correction,
  tenant isolation, staff/owner permissions, stale maintenance writes, successful
  configuration restore and failed-restore rollback.
- Flutter: 20 tests passed across availability gates (320/1280 px, resident and
  guardian blocking/retry, staff bypass, stale session responses), conduct policy
  and tenant evidence regressions.
- Targeted analyzer: changed application files pass.
- Full analyzer and existing investigation/agreement widget suite are blocked by
  pre-existing working-tree errors in `shared_views.dart`: missing feedback
  service and mismatched notification/form parameters. Those edits are preserved.
- Full Supabase migration-chain replay, actual file export, authenticated
  configuration restore using production option triggers, staff screen walkthrough
  and physical-device verification remain integration checks before release.


October 19 availability fix: the initial fail-closed gate could lock tenant and
guardian accounts out when the settings table was absent or unreachable. It now
leaves access available until maintenance is positively confirmed. Six focused
widget tests cover both roles, failed/pending checks, polling recovery, confirmed
maintenance retention and staff/session isolation.

October 19 shared-screen repair follow-up: the older shared-screen compile
blocker recorded above is resolved locally. Full analysis and the conduct
investigation/agreement widget suite now pass. See
[shared-screen and transfer repair](shared-screen-and-room-transfer-repair.md).

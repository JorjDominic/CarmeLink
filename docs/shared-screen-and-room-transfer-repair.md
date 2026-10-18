# Shared screens and Standard Shared room transfers

Local repair and validation: October 19, 2026. No database migration or app
deployment was performed by this repair.

## Shared screens

The uncommitted shared-screen replacement removed notification navigation,
pagination, unread synchronization and injected service support. It also removed
tenant onboarding/document sections, profile editing actions and saved guardian
alert preferences, and referenced a missing feedback service.

Restored the working tracked implementations. Feedback again clearly describes
its existing validation-only behavior instead of claiming an unavailable backend
saved a submission. Retained the compact staff profile header and clearer
"Privacy and permissions" title. Kept the tenant payment card's existing
contract-rent-to-adjusted-rent explanation. The removed local draft screens are
preserved in ignored `build/local-repair-backups/20261019/` for reference.

Full `flutter analyze --no-pub`: no issues. Sixty tests passed across notification
read/navigation behavior, profile editor/preferences/ink, feedback, conduct
investigation/agreements, disabled floor plans, staff maintenance and tenant
payments. The older shared-screen compile blocker noted in the conduct feature
documents is resolved locally by this repair.

## Standard Shared transfers

Recorded the existing `202610190001_allow_standard_shared_room_transfer.sql`.
It permits ordinary transfers for independently priced Standard Shared contracts,
while shared/exclusive-shared rent groups still require their group workflow.

Review found its assignment-function replacement also omitted prior DELETE,
inactive-status, retired-bed and concurrency guards. Added
`202610190005_preserve_standard_shared_transfer_guards.sql` to restore the full
existing guard, changing only its cross-room restriction for independently priced
occupancy. This follow-up is necessary for databases that already applied 001;
the historical migration is preserved rather than silently rewritten.

Validation used disposable PGlite databases with actual migration functions:

- Fifteen signed-transfer checks passed. The main lifecycle now starts with a
  Standard Shared contract and verifies proposal, signed PDF, tenant notice
  acknowledgement, required signatures, owner verification, completion, unchanged
  contract terms, one active assignment and a subsequent transfer. Shared and
  exclusive-shared group proposals remain blocked.
- Twenty-two dynamic occupancy checks passed, including five follow-up guard
  checks: proposal availability without unsigned reassignment, immutable history,
  inactive historical rows, retired beds, declared membership and shared-rent
  cross-room restrictions.

Existing room and tenant locking statements are retained from the previous guard.
No new multi-session concurrency run or physical-device walkthrough was performed.
Apply 005 in migration order after existing migrations before relying on these
assignment safeguards in the linked database. Full Supabase migration-chain and
device validation remain rollout checks.

Generated `supabase/.temp/cli-latest` changes are excluded from these commits.

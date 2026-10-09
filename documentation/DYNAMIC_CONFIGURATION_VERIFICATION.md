# Dynamic configuration handoff

Checked existing maintenance_category, common_area, report_type,
announcement_category and payment_method groups. They use dormitory_options,
Owner insert/update RLS, normalized unique labels, stable option IDs/codes,
active-only form reads and existing realtime/polling. Remove means archive;
protected business choices remain protected. No new configuration modules.

Fixes: option edit/archive/restore now require a persisted row (no zero-row
false success); configured field reloads if its group changes; prior dynamic
selector fixes clear invalid parent selections, refresh open pickers, filter
archived rooms and invalidate room statistics after successful assignments.
Desktop Rooms actions have a 10px gap; mobile 10px wrapping stays unchanged.

REVIEW-ONLY migration: 202610090003_configured_concern_snapshot_safety.sql.
Existing SQL demanded Specify for every category_code=other custom concern,
unlike the application's actual catch-all detection. It also revalidated an
archived concern type and rewrote historical labels on staff review. The fix
aligns catch-all validation, drops irrelevant specification on new/changed
non-catch-all selection and preserves unchanged report snapshots on review.
Maintenance rules, RLS, IDs, length limits and existing triggers are retained.
Do not modify already deployed migration 006 or reapply entire older migrations.

Original checks: 24 focused Flutter tests passed; 5 isolated PostgreSQL checks
passed; flutter analyze --no-pub clean; git diff --check passed. SQL fixture
tests cover owner add/edit/archive, duplicate labels, tenant permission denial,
new selection validation and history/Specify preservation. API fixtures cover
persisted management calls, current option reads, zero-row failure and room CRUD.
Button spacing uses source assertions plus existing layout regression tests,
not authenticated live visual verification.

Before manual deployment, review the actual function with:
select pg_get_functiondef('public.snapshot_report_options()'::regprocedure);
Validate migration on disposable full-schema staging. After approval/backup,
apply the complete 003 transaction once through SQL Editor; compare the deployed
function and test approved workflows. Assistant executed no production SQL.
Live Owner-to-Tenant/Guardian/Staff realtime and web/mobile visual integration,
all five groups' deployed policies/publication and historical maintenance edits
remain manual checks. Code fixes are not proof of live deployment or RLS.

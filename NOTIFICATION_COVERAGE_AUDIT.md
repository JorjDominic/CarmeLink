# Notification coverage audit — 2026-10-07

This verifies repository wiring and local regression tests, not live FCM delivery.
No live notifications were sent. No database or Edge Function was deployed.

| Feature | Recipients / coverage found | Delivery path and limitations |
| --- | --- | --- |
| Messages | Conversation participants, all four roles | `notify-message`, inbox and mobile push; exact conversation routing |
| Announcements | Selected audience | Client dispatcher; corrected staff-only mapping which previously broadcast to all roles. Edits do not re-notify. |
| Maintenance | Submission to owner/caretaker; status to reporting tenant | Client dispatcher; depends on the app completing the post-save call |
| Payment submission/review | Submission to staff; review to tenant | Client dispatcher; guardian payment page exists but these events do not notify guardians |
| Utility cart | Every billed tenant | Fixed: database trigger now uses each allocation and its actual amount; previous client code missed room scopes and read a missing `amount` field as zero. Requires migration 010. |
| Other manual bill creation/adjustment | Affected tenant | Client calls exist; rent-rate override does not dispatch a notification |
| Due/overdue billing reminders | Staff | App-driven check with local daily suppression, not a guaranteed server schedule; current dispatcher excludes the actor |
| Visitor requests/status/reschedule/reminders | Staff and affected tenant | Database trigger, reminder cron and queued server push; guardian not targeted |
| Curfew requests/decisions | Staff, affected tenant, linked guardians according to request | Client dispatcher; guardian decisions also notify staff |
| Gate/presence | Linked guardians and configured staff paths | Dedicated Edge Functions; cutoff/location monitoring workers depend on cron and credentials |
| Guardian status-update request | Linked tenant | Dedicated authenticated/rate-limited request function |
| Confidential reports | Staff and reporting tenant on supported updates | Database trigger and queued push; no guardian disclosure |
| Cleaning noncompliance reports | Staff on submission, reporter on update | Database trigger and queued push |
| Completed inspections | Assigned tenants | Client dispatcher; no scheduled-inspection reminder found |
| Conduct cases/appeals | Tenant, linked guardians; appeal submission to staff | Client dispatcher; guardians receive readable notification details, not the staff case page |
| Contracts/signing/onboarding milestones | Gap | No notification dispatch found in contract services; an onboarding destination alone is not delivery |
| Move-out/clearance/deposit/refund milestones | Gap | No notification dispatch found in settlement/deposit services |
| Room assignment, cleaning rotation, employee-curfew profile changes | Gap | Data refresh exists but no dedicated event notification found |

## Fixes in this work

- Staff announcement audiences remain staff-only; unknown audiences fail closed.
- Added gateway configuration for the report-push and guardian-presence workers.
  Both continue to authenticate their private cron bearer inside their handlers.
- Utility allocation notifications are created transactionally and enter the
  existing retryable server push queue. Apply migration 010 before releasing the
  updated payment service, which no longer sends the incorrect duplicate call.
- Inbox pagination now uses timestamp plus notification ID, avoiding skipped rows
  when a transaction creates several notifications with the same timestamp.
- Existing destinations, inbox read state, all-role shells, and web notification
  navigation passed the focused local suite (29 tests).

## Runtime verification still required

1. Apply migrations and deploy the two worker configurations; verify cron jobs
   execute and the queue drains without repeated failures.
2. Verify FCM credentials and active device registration without exposing secrets.
3. Use test accounts for owner/caretaker/tenant/guardian to exercise each recipient
   path in foreground, background, cold start, logout/account switch, and denied
   notification permission. Check inbox ownership and target-record navigation.
4. Run `supabase/tests/utility_allocation_notifications.sql` on a migrated test
   database. It rolls back charges, notifications and push jobs.
5. Browser/desktop OS push is not implemented by `PushNotificationService`; those
   platforms use the in-app realtime inbox and polling fallback.

Client-dispatched events are best-effort and generally not queued for retry if
the app exits after saving. Full delivery reliability requires moving those event
notifications to durable server-side transactions. Missing feature notifications
above are remaining implementation work, not verified-running features.

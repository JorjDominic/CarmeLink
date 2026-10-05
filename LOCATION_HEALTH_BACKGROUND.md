Location availability monitoring
================================

Android uses a separate settings-only foreground service with an ongoing
CarmeLink safety monitoring notification. It observes provider changes and checks
availability every 30 seconds while running. It does not request coordinates,
or change gate/presence decisions. A separate location foreground service now
monitors the polygon continuously after registration, reducing sampling power
farther than 50 metres from its edges and requesting precise fixes near the
boundary or during confirmation. It keeps an ongoing boundary-monitoring
notification. OS callbacks can still start bounded two-minute GPS sessions.
Continuous sampling can use more battery and needs on-site testing for drift.
The service remains active after ordinary recent-task removal. Force stop and
manufacturer restrictions can still stop it; reopening starts it again.
Foreground promotion happens in the service start command, and resume retries
failed starts. A process-lifetime settings receiver remains attached if service
promotion is denied, so the living process can still observe OFF/ON changes.
Denials are logged under CarmeLinkHealth and exposed by the native status method.

Android has one native reminder channel and cooldown. Flutter's reminder is used
only on other platforms. Observed recovery clears the cooldown. A missing reminder
is restored silently during the cooldown rather than hidden for an hour; an
observed new outage alerts immediately. Notification/channel blocking never
consumes the cooldown. Reminder visibility still depends on OS notification rules.

The service declares Android's specialUse foreground-service type because its
work checks settings availability rather than collecting location. A Play Store
release needs the corresponding foreground-service declaration and review.

Reports use expedited work on Android 12+ with a network constraint, preserving
OFF/ON snapshots in order when offline. Periodic work remains a fallback.
The tenant reminder stays local so it works without internet. Guardian and staff
alerts use server FCM. Inserting an outage incident queues an authenticated
database webhook after commit, targeting that incident immediately. The existing
five-minute job retries failures and handles escalation. There is no intentional
five-minute wait for initial guardian alerts. Phone connectivity, OS scheduling,
webhook processing and FCM delivery still affect latency; instant arrival cannot
be guaranteed. FCM acceptance is not proof of display on the device.

Failed pushes and missing tokens keep incidents pending. Each recipient/stage has
a stable notification ID; retries reuse it and skip recipients already accepted
by FCM. A database lease prevents webhook/cron overlap from sending concurrently;
abandoned leases expire after five minutes. Unregistered tokens are revoked. Escalation still starts after 30 minutes
of the server-recorded incident.

Rollout: rebuild/install the Android app and deploy the updated
process-location-monitoring-alerts Edge Function (including handler.ts).
Apply migration 202610050001_immediate_location_health_alerts.sql, then deploy the
updated Edge Function, which requires its claim RPC. Earlier migrations and the
scheduled processor must already be deployed. The webhook uses a dedicated private
credential without rotating the existing cron credentials. Its URL matches the
project already configured in the scheduler; change it for other environments.
Immediate dispatch works for reports from either platform; these changes do not
modify iOS device-side monitoring.

Closed-app IN/OUT recovery
-------------------------

The polygon monitor remains active after normal task removal and can restart
through START_STICKY; Android/OEM restrictions and Force Stop still apply. On app
resume it restarts without waiting for a boundary-config network fetch. Every
geofence callback also queues a bounded WorkManager verifier, which requests fresh
fixes and retries a limited number of times if service promotion is rejected or
no crossing is confirmed. The existing polygon, 35-metre quality gate, freshness,
edge buffer, and two-matching-fix rules are retained. Shared cached observations
are counted once across native collectors, and verification/queueing is serialized.

Uploads acknowledge only their own event IDs so new events are not overwritten
by a worker's old snapshot. Uploaded server IDs go into a separate durable
notification outbox before acknowledgement. Notification failures retry without
uploading another transition, and native auth refresh is shared between workers.
The notify-geofence endpoint reuses failed notification rows, skips recipients
already accepted by FCM, and responds 503 while recipients remain undelivered.
Deploy the updated notify-geofence function along with reinstalling the app.

Native status includes backgroundMonitorRunning, pendingNotificationCount,
lastVerificationError, lastGeofenceCallbackAt, and lastNotificationError. Testing
must cover exits/entries while staying within the outer 100-metre wake circle,
screen off, task removal, offline reconnection, and stationary indoor GPS drift.
The native event queue retains up to 24 transitions and drops entries over 24 hours
old, as before. Force Stop cannot be bypassed and missed history cannot be recreated.

Phone verification: sign in as a tenant with monitoring registered, background
the app, turn location off, and confirm the local reminder without reopening.
Repeat after swiping the app away. Check the incident creation time and the linked
guardian's FCM alert without waiting for the next scheduled run. Restore location and confirm
recovery. Repeat offline then reconnect, and verify ordered outage/recovery reports.

Checks:
- flutter test test/services/location_monitoring_alert_contract_test.dart
- npx --yes deno test --allow-env supabase/functions/process-location-monitoring-alerts/index_test.ts
- node supabase/tests/location_health_dispatch.test.cjs (requires @electric-sql/pglite
  in node_modules or NODE_PATH; uses an isolated PostgreSQL database and mocked
  network queue, without contacting Supabase or FCM)
- Android Gradle :app:compileDebugKotlin using Android Studio's bundled JBR

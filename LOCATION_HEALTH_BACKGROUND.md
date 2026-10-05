Location availability monitoring
================================

Android uses a separate settings-only foreground service with an ongoing
CarmeLink safety monitoring notification. It observes provider changes and checks
availability every 30 seconds while running. It does not request coordinates,
change the crossing verifier, or extend the existing two-minute GPS burst.
The service remains active after ordinary recent-task removal. Force stop and
manufacturer restrictions can still stop it; reopening starts it again.

The service declares Android's specialUse foreground-service type because its
work checks settings availability rather than collecting location. A Play Store
release needs the corresponding foreground-service declaration and review.

Reports use expedited work on Android 12+ with a network constraint, preserving
OFF/ON snapshots in order when offline. Periodic work remains a fallback.
The tenant reminder stays local so it works without internet. Guardian and staff
alerts use server FCM, after a report reaches Supabase and the existing five-minute
scheduled processor runs. FCM acceptance is not proof of display on the device.

Failed pushes and missing tokens keep incidents pending. Each recipient/stage has
a stable notification ID; retries reuse it and skip recipients already accepted
by FCM. Unregistered tokens are revoked. Escalation still starts after 30 minutes
of the server-recorded incident.

Rollout: rebuild/install the Android app and deploy the updated
process-location-monitoring-alerts Edge Function (including handler.ts).
No new database migration is required. Existing migrations and the scheduled
processor must already be deployed. These changes do not modify iOS monitoring.

Phone verification: sign in as a tenant with monitoring registered, background
the app, turn location off, and confirm the local reminder without reopening.
Repeat after swiping the app away. Check the incident creation time and the linked
guardian's FCM alert after the next scheduled run. Restore location and confirm
recovery. Repeat offline then reconnect, and verify ordered outage/recovery reports.

Checks:
- flutter test test/services/location_monitoring_alert_contract_test.dart
- npx --yes deno test --allow-env supabase/functions/process-location-monitoring-alerts/index_test.ts
- Android Gradle :app:compileDebugKotlin using Android Studio's bundled JBR

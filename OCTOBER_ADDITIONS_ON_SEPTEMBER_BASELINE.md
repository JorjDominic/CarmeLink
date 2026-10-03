# October additions on the September 30 baseline

This branch starts at `cfc2643` (September 30, 2026). Its starting point is also
preserved at `backup/geofencing-main-new-before-oct-additions-20261003`.
The original October build remains on `main` at `a0e6900`.

## Separate changes

1. Guardian presence-update requests: authenticated guardian/tenant link checks,
   30-minute cooldown, five requests per 24 hours, request audit, tenant in-app
   notification, and attempted FCM push.
2. Guardian request history and status breakdowns.
3. Horizontal filter bars and collapsible/dismissible guide cards. These are UI
   changes, not changes to crossing evaluation.
4. Location-health incident storage and scheduled outage escalation backend.
5. Location-off reminders and health reporting, isolated from crossing detection.

## Geofencing retained

Android crossing verifier, geofence callback receiver, bounded two-minute GPS
burst service, Flutter polygon evaluator, and foreground scheduler match the
September 30 versions. iOS polygon classification, confirmation and bounded
GPS burst behavior are retained; added callbacks only observe monitoring health.
The October persistent monitoring, adaptive GPS, altered boundary buffers,
movement/gate proof, transition worker and battery-settings changes are excluded.
Existing September 30 detection weaknesses are not claimed to be fixed.

## Location health is separate from presence

The Android `LocationMonitoringHealth` observer reads Location Services and
permission settings. It never requests GPS or records IN/OUT events. A separate
receiver handles location-setting broadcasts; a 15-minute WorkManager check
provides recovery checks without continuous polling. WorkManager execution can
be delayed. Resume and boot also check health. Unregister cancels health work.
Reporting retries independently when the backend is unavailable.

iOS health checks run during existing registration, resume, location, permission
and error callbacks. They do not add continuous GPS monitoring. There is no
guarantee of immediate detection while iOS suspends the app or after force-stop.
Reminder notifications are canceled on recovery/unregister.

The tenant gets a local reminder when an outage is detected, subject to OS
notification permission. Android repeats on later checks after an hour; iOS
schedules hourly reminders. Flutter supplies a startup reminder if the native
monitor cannot start. Reminder failure must not block tripwire registration.

Unresolved incidents lasting 30 minutes are eligible for staff and linked-guardian
in-app notifications and FCM attempts. The cron processor runs every five minutes.
Immediate guardian push on location disable is NOT included. An outage must be
successfully reported before the backend can escalate it.

## Backend setup

Apply the three restored `202610020001`, `202610020002`, and `202610020003`
migrations in order, and deploy `process-location-monitoring-alerts` and
`request-tenant-status-update`. Existing FCM and guardian-alert cron credentials,
pg_cron, and pg_net configuration are required. The schedule migration recreates
the guardian and monitoring schedules using a shared rotated cron credential;
review its project URL when targeting a different Supabase project.
These changes are local; database migrations/functions have not been deployed.

## Device acceptance checks

- Confirm entry/exit with the app visible, on Home, and with the screen locked.
- Sit inside without moving and watch for false OUT events.
- Disable Location; check the tenant reminder and backend open incident.
- Re-enable Location; confirm recovery and cancellation of reminders.
- Leave Location disabled for over 30 minutes; verify guardian/staff alerts.
- Send a guardian request; verify tenant notification and request history.
- Sign out; verify location-health reminders/work stop.

Local validation: Flutter analysis, targeted guardian/geofencing/health tests,
and Android debug APK build. iOS compilation and real-device behavior require
their respective devices/toolchains.

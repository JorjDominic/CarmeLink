# CarmeLink Automatic Geofencing Implementation

## Purpose

This document specifies the recommended software-only geofencing design for
CarmeLink. It does not require QR scanners, RFID, NFC readers, beacons, or other
external hardware.

The module estimates whether a tenant is inside or outside the dormitory using
the tenant's phone, native Android/iOS background location facilities, and
server-side validation.

Geofencing is evidence of presence, not absolute proof. GPS can be unavailable,
inaccurate, disabled, or restricted by the operating system. The application
must display uncertainty honestly instead of treating an old result as current.

The delivery target is **within 15 minutes of a crossing**, not instant
detection. Events will often arrive sooner, but correctness is more important
than speed.

## Core rule

**Authentication and physical presence are separate.**

Signing in must never set a tenant to `IN` or `OUT`. Authentication only allows
the app to register or restore monitoring for the signed-in tenant. Presence
changes only after the location verification rules in this document succeed.

```text
Tenant authenticates
        |
        v
Register or restore native monitoring
        |
        v
OS reports a possible boundary transition
        |
        v
Collect several fresh, accurate GPS readings
        |
        v
Confirm transition or retain the previous state
        |
        v
Send a minimized event to Supabase
```

## Presence states

Use explicit states instead of only `IN`, `OUT`, and `UNAVAILABLE`:

| State | Meaning |
| --- | --- |
| `INSIDE_CONFIRMED` | Recent readings consistently place the tenant inside. |
| `OUTSIDE_CONFIRMED` | Recent readings consistently place the tenant outside. |
| `VERIFYING_ENTRY` | A possible entry was detected but is not confirmed. |
| `VERIFYING_EXIT` | A possible exit was detected but is not confirmed. |
| `LOCATION_UNAVAILABLE` | Permission, GPS, accuracy, or signal prevented verification. |
| `STALE` | The last confirmed state is too old to describe current presence. |

The last confirmed state may be retained separately for history, but the UI
must not present it as current after its freshness period expires.

## Boundary model

The authoritative dormitory boundary remains the server-owned polygon in
`dorm_boundary_config`.

Native mobile geofence APIs commonly monitor circular regions rather than
arbitrary polygons. Therefore:

1. Register one or more circular native regions around the dormitory as a
   low-power wake-up mechanism.
2. When the OS reports entry or exit, obtain fresh GPS readings.
3. Evaluate those readings against CarmeLink's exact polygon on the device.
4. Use separate entry and exit thresholds to prevent GPS jitter.

Recommended thresholds:

- Entry: a reading must be clearly inside the polygon.
- Exit: a reading must be at least 15-25 metres beyond the polygon edge.
- Accuracy: reject readings whose reported horizontal accuracy is worse than
  35 metres.
- Freshness: reject readings older than two minutes.
- Mock locations: reject readings marked as mocked where the platform exposes
  that information.

The wider exit boundary creates hysteresis. A tenant close to a wall or gate
does not repeatedly alternate between inside and outside.

The native wake-up circle may need to be larger than the 50-metre fallback
circle used by the existing app. Apple advises that practical region-monitoring
radii can vary significantly with Wi-Fi, cellular coverage, buildings, and the
surrounding environment. A larger circle can wake the app, after which the exact
polygon makes the final decision. The radius must be chosen through on-site
testing rather than assumed from the lot dimensions alone.

## Transition confirmation

A single GPS sample must not change confirmed presence.

### Confirming an exit

1. The OS reports a possible exit, movement triggers verification, or a
   reconciliation check finds an outside reading.
2. Set the transient state to `VERIFYING_EXIT`.
3. Collect at least two acceptable readings over 30-60 seconds.
4. Require all accepted readings to be beyond the exit threshold.
5. If confirmed, record `OUTSIDE_CONFIRMED`.
6. If readings disagree, retain the previous confirmed state and retry later.

### Confirming an entry

1. The OS reports a possible entry or reconciliation finds an inside reading.
2. Set the transient state to `VERIFYING_ENTRY`.
3. Collect at least two acceptable readings over 30-60 seconds.
4. Require all accepted readings to be clearly inside the polygon.
5. If confirmed, record `INSIDE_CONFIRMED`.
6. If readings disagree, retain the previous confirmed state and retry later.

The confirmation count, interval, accuracy limit, and boundary margins should
be remotely configurable so on-site testing can tune them without publishing a
new application version.

## Automatic operation

### Android

- Register native geofence regions after the tenant grants location access.
- Request background location only after explaining why it is needed.
- Receive transitions through a native broadcast receiver or equivalent
  platform integration.
- Use an appropriately declared foreground location service only while actively
  confirming a transition, rather than maintaining unrestricted continuous GPS.
- Restore registered monitoring after device restart and application update.
- Detect disabled permissions, disabled location services, and battery
  restrictions, then expose those conditions in the app.

### iOS

- Register monitored regions through Core Location.
- Request `Always` location access only after an in-app explanation and initial
  when-in-use authorization.
- Process region transitions through the native location delegate.
- Perform a short high-accuracy confirmation session after a transition.
- Re-register monitoring when authentication or boundary configuration changes.
- Enable significant-location-change monitoring as a coarse recovery trigger.
  It does not replace the dormitory region because it may wake only after the
  phone has moved much farther away.
- Recreate the location manager immediately when iOS launches the application
  because of a location event.

iOS can attempt to relaunch an application for registered region-monitoring or
significant-location-change events even when it is not running. Delivery is
still controlled by iOS, may be throttled, and depends on authorization,
location services, device movement, and environmental signal quality.

### Flutter integration

Expose native events to Flutter through a platform channel or a suitable,
actively maintained geofencing package. The native layer must be able to record
a minimized pending event locally when the Flutter engine or network is not
available.

The current `GeofenceScheduler` can remain temporarily as foreground
reconciliation, but it must not be the primary background mechanism. Flutter
timers are not guaranteed to run after the operating system suspends or
terminates the application.

## Reconciliation schedule

Native transition events are primary. Periodic checks repair missed events and
refresh confidence:

| Condition | Suggested behavior |
| --- | --- |
| App resumes | Run one fresh reconciliation check. |
| Normal daytime | Use low-frequency checks when the OS permits them. |
| 8:00-10:00 PM | Increase reconciliation frequency. |
| Curfew and confirmed outside | Retry more frequently, subject to OS limits. |
| Curfew and confirmed inside | Reduce checks to preserve battery. |
| Location unavailable | Use bounded retry/backoff and show the reason. |

These intervals are requests, not guarantees. Android and iOS may delay
background work for battery and privacy reasons. A transition delivered within
15 minutes is acceptable for this project.

## Server event contract

The phone evaluates coordinates locally. Raw tenant latitude, longitude, GPS
tracks, and exact distances must not be sent to Supabase.

A confirmed or unavailable event should contain only:

```json
{
  "event_id": "device-generated UUID",
  "direction": "IN",
  "status": "Verified",
  "checkpoint_type": "native_transition",
  "source": "android_geofence",
  "observed_at": "2026-09-21T14:30:00Z",
  "confidence": "high",
  "boundary_version": "server boundary version"
}
```

The authenticated session determines the tenant ID. The client must never be
allowed to submit an arbitrary tenant ID for a GPS event.

The backend must:

- accept events only from authenticated tenant accounts;
- validate enum values and timestamp limits;
- make `event_id` unique for idempotent offline retries;
- reject implausibly old or future timestamps;
- deduplicate repeated transitions;
- apply Philippine-time curfew and approved-leave rules;
- update the current presence projection transactionally; and
- retain append-only event history for authorized users.

Queued events should contain only the minimized payload above, use encrypted
platform storage where practical, have a fixed maximum count, and expire after
24 hours.

## Freshness and unavailable behavior

A separate server-maintained field should describe when presence was last
verified. A scheduled server job or read-time calculation should mark the
displayed state `STALE` after a configured duration.

Suggested UI wording:

- `Inside - verified 4 minutes ago`
- `Outside - verified 12 minutes ago`
- `Verifying possible exit...`
- `Status unavailable - location permission disabled`
- `Last known inside - status is stale`

If GPS fails during a verification attempt, record `LOCATION_UNAVAILABLE` as a
health event without replacing the historical last-confirmed direction. This
prevents a temporary signal failure from pretending the tenant entered or left.

## Permissions and privacy

- Ask for foreground location only when the tenant enables the safety feature.
- Explain the benefit before requesting background access.
- Provide direct links to app and location settings after denial.
- Show whether monitoring is active, restricted, or unavailable.
- Stop monitoring immediately on sign-out, account removal, or explicit
  revocation.
- Do not expose exact coordinates to tenants, guardians, or staff.
- Guardians may view only linked tenants through existing row-level security.
- Document background-location use in the privacy policy and app-store forms.

## Failure handling

| Failure | Required result |
| --- | --- |
| Permission denied | `LOCATION_UNAVAILABLE`; explain how to enable it. |
| Permission permanently denied | Link to system app settings. |
| GPS disabled | Preserve last confirmed direction but mark current status unavailable. |
| Poor or stale signal | Reject the reading and retry with backoff. |
| Network unavailable | Queue the minimized event locally. |
| Android app force-stopped in Settings | Report interruption and restore monitoring when the app next opens. |
| iOS app not running | Region/significant-change monitoring may relaunch it; queue the event immediately. |
| Conflicting readings | Keep the prior confirmed state and remain in verification. |
| Boundary configuration unavailable | Use the last validated cached boundary. |

No software-only implementation can guarantee updates when Android places the
application in the force-stopped state, GPS is disabled, permission is revoked,
the phone is off, or the OS cannot obtain a usable location. iOS region and
significant-change monitoring can relaunch an application that is not running,
but delivery timing and reliability remain controlled by iOS.

## Recommended repository changes

1. Add native Android and iOS geofence adapters and a Flutter platform-channel
   interface.
2. Refactor `GeofenceScheduler` into a reconciliation coordinator instead of
   the primary detector.
3. Extend `GeofenceLocationService` with multi-sample transition confirmation
   and separate entry/exit margins.
4. Extend the presence model and database constraints with verifying, stale,
   source, confidence, event ID, observed time, and boundary version fields.
5. Update the secure Supabase RPC to validate idempotent device events.
6. Preserve the zero-coordinate persistence rule in local storage, requests,
   logs, analytics, and database tables.
7. Update tenant, guardian, and staff screens to show freshness and uncertainty.
8. Add native reboot/update restoration and monitoring-health reporting.

## Validation checklist

- [ ] Signing in starts monitoring but does not change presence.
- [ ] One inaccurate reading cannot cause an entry or exit.
- [ ] Boundary-edge GPS drift does not create repeated transitions.
- [ ] Entry and exit work while the app is foregrounded, backgrounded, and
      suspended on physical Android and iOS devices.
- [ ] Device restart restores monitoring where the platform allows it.
- [ ] Permission denial, GPS disabled, poor accuracy, timeout, and recovery are
      represented correctly.
- [ ] Android force-stop and all monitoring interruptions are visible rather
      than silently presenting stale data as current.
- [ ] iOS region and significant-change relaunch behavior is tested after the
      app is backgrounded, terminated, and removed from the app switcher.
- [ ] Confirmed events normally synchronize within the accepted 15-minute
      delivery window under supported conditions.
- [ ] Offline events sync once and duplicate retries remain idempotent.
- [ ] Raw tenant coordinates never appear in requests, storage, logs, crash
      reports, analytics, or database records.
- [ ] Linked guardians can read only their linked tenants' minimized events.
- [ ] On-site walk testing validates the entry and exit margins around every
      side of the configured dormitory boundary.
- [ ] Battery impact is measured over daytime and overnight test periods.

## Recommended final architecture

```text
Native Android/iOS region monitoring
                |
                v
        Possible transition
                |
                v
 Short multi-reading GPS confirmation
                |
                v
 Exact on-device polygon evaluation
                |
                v
 Minimized, idempotent Supabase event
                |
                v
 Curfew validation + current-state projection
                |
                v
 Tenant / linked guardian / authorized staff UI
```

This design makes monitoring automatic without external hardware while keeping
the system honest about mobile-platform limits, GPS uncertainty, privacy, and
the freshness of its conclusions.

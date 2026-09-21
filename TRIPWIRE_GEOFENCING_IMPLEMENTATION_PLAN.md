# CarmeLink Tripwire Geofencing Implementation Plan

## 1. Objective

Implement geofencing as a simple automatic tripwire:

```text
Tenant crosses out of the dorm boundary -> log one OUT event
Tenant crosses into the dorm boundary  -> log one IN event
```

The module will not attempt to continuously prove a tenant's exact location.
It will record boundary-crossing events, reject obvious GPS noise, prevent
duplicates, and expose monitoring failures honestly.

No external hardware is required.

## 2. Scope

### Included

- Automatic native Android and iOS boundary monitoring.
- Entry and exit detection while the app is foregrounded or backgrounded.
- Capture of native transition events when Flutter is suspended.
- Best-effort capture when the operating system terminates the app normally.
- A minimized native queue for transitions awaiting synchronization.
- Synchronization through the existing authenticated Supabase RPC.
- Initial-state baselining without creating a false entry or exit event.
- Short transition confirmation to reduce GPS jitter.
- Duplicate suppression.
- Existing curfew validation and guardian/staff visibility.
- Monitoring-health and permission reporting.

### Excluded

- Continuous live tracking or a map of tenant movement.
- Storage or transmission of raw tenant coordinates.
- RFID, QR, NFC, cameras, beacons, or other gate hardware.
- Guaranteed operation after Android force-stop.
- Guaranteed operation when location is disabled, permission is revoked, the
  phone is off, or the operating system blocks background execution.
- Treating login, logout, or opening the application as a physical crossing.

## 3. Important platform expectations

"App closed" has several meanings:

| App condition | Expected behavior |
| --- | --- |
| Screen off | Monitoring should continue when permissions allow. |
| App in background | Native geofence callbacks should continue. |
| App removed from recent apps | Usually continues; must be tested per device. |
| App process killed by the OS | Native callbacks can relaunch/wake eligible components. |
| Android user force-stop | Cannot receive events until the user opens the app again. |
| iOS app is not running or was swiped away | Registered region or significant-change events can cause iOS to relaunch it, but timing and reliability remain system-controlled. |
| GPS/location disabled | No reliable transition can be detected. |

The UI and project documentation must not promise uninterrupted tracking under
conditions the operating system does not permit.

The accepted delivery target is **within 15 minutes of a crossing**. The system
does not need to detect or upload an event instantly.

## 4. Existing components to retain

The following repository components remain useful:

- `GeofenceLocationService`: polygon evaluation, accuracy/staleness checks,
  mock-location rejection, and zero-coordinate result objects.
- `GateService`: secure RPC calls, bounded offline event queue, and event loads.
- `gate_events`: append-only minimized event history.
- `record_tenant_geofence_check`: authenticated insertion and server-side
  curfew evaluation.
- `dorm_boundary_config`: authoritative boundary configuration.
- Existing row-level security for tenants, linked guardians, and staff.
- Existing 45-second database duplicate suppression as a secondary safeguard.

The current `GeofenceScheduler` will be reduced to foreground reconciliation
and recovery. It will no longer be the primary tripwire.

## 5. Target event flow

```text
Authenticated tenant enables monitoring
                |
                v
Fetch and cache active boundary configuration
                |
                v
Register native OS geofence region(s)
                |
                v
Establish current baseline without writing gate_events
                |
                v
OS reports possible ENTER or EXIT
                |
                v
Capture transition in a minimized native queue
                |
                v
Run short location confirmation when the OS permits
                |
         +------+------+
         |             |
      confirmed     uncertain
         |             |
         v             v
  sync one IN/OUT   retain prior state,
  event to RPC      retry or report unavailable
         |
         v
Server validates, deduplicates, and applies curfew rules
```

## 6. Boundary strategy

### Authoritative decision boundary

Continue using the existing dormitory polygon for precise on-device checks.

### Native wake-up boundary

Android and iOS native region APIs are primarily circular. Register a circular
region that encloses or approximates the dormitory. This region is only the
wake-up trigger; it is not necessarily the final decision boundary.

When a native transition arrives and a fresh location is available, evaluate
it against the exact polygon before committing the event.

### Hysteresis

Use direction-aware margins:

- Entry confirmation: clearly inside the polygon, initially 5 metres from its
  edge when accuracy permits.
- Exit confirmation: clearly outside the polygon, initially 10-15 metres past
  its edge.
- Do not use the current flat 3-metre buffer as the final production value
  without an on-site walk test.

The final values must be tuned at the physical dormitory.

## 7. Baseline and state machine

Persist one native monitoring state per authenticated tenant:

- `unknown`: no trustworthy baseline yet.
- `inside`: last confirmed side is inside.
- `outside`: last confirmed side is outside.
- `verifying_entry`: temporary internal state.
- `verifying_exit`: temporary internal state.

Only `IN` and `OUT` are persisted as physical events in `gate_events`. The
verifying states are internal and do not require a database schema change.

### Baseline rule

When monitoring is first registered:

1. Obtain a trustworthy location when possible.
2. Determine the current side of the boundary.
3. Save it as the baseline.
4. Do not insert a gate event.

Examples:

- Tenant enables monitoring while already inside: baseline becomes `inside`;
  no `IN` event is created.
- Tenant enables monitoring while already outside: baseline becomes `outside`;
  no `OUT` event is created.

### Transition rule

- Baseline `inside` plus confirmed exit -> insert exactly one `OUT` event and
  change native state to `outside`.
- Baseline `outside` plus confirmed entry -> insert exactly one `IN` event and
  change native state to `inside`.
- A repeated transition matching the current side is ignored.
- An `UNAVAILABLE` check never changes the last confirmed side.

## 8. Confirmation policy

The target is near-real-time behavior without trusting a single noisy sample.

Initial policy:

1. Receive a native transition callback.
2. Request a high-accuracy location fix with a 10-second timeout.
3. Accept only a fresh, non-mocked reading with reported accuracy of 35 metres
   or better.
4. If it clearly agrees with the transition, wait approximately 10-15 seconds
   and obtain one additional accepted reading when platform execution time
   allows.
5. Commit the transition when both readings agree.
6. If the readings disagree, do not log a crossing; schedule a bounded retry.

Many events may arrive within seconds or a few minutes. Weak signals,
confirmation, native relaunch throttling, and operating-system scheduling can
extend delivery. An event delivered within 15 minutes meets the project target.

If a platform does not grant enough execution time for two readings, retain
the native transition as `pending_confirmation` and finish confirmation at the
next permitted background execution or app resume. Do not convert an uncertain
transition into a verified event.

## 9. Native Android work

### Components

- Add the Google Play services location/geofencing dependency.
- Add a `GeofenceBroadcastReceiver` for native transition callbacks.
- Add a small native `TripwireGeofenceManager` for registration, removal,
  baseline state, and pending-event persistence.
- Add a boot/package-update receiver if permitted and appropriate, so monitoring
  can be restored after restart or application update.
- Add a short-lived foreground service only when required to finish transition
  confirmation under modern Android background-execution rules.
- Expose registration, removal, health, and queue-drain operations to Flutter
  through a method channel.

### Permissions

- Fine/coarse location.
- Background location on supported Android versions.
- Foreground service and foreground-service location permission where required.
- Boot completion only if restart restoration is implemented.

Permission requests must remain staged: foreground first, explanation, then
background access. Registration succeeds only after required permissions are
confirmed.

### Android limitations

- Force-stop disables receivers and geofence delivery until the next launch.
- Device vendors may impose extra battery restrictions.
- Reboot restoration depends on permissions, device policy, and available
  authenticated tenant configuration.

## 10. Native iOS work

### Components

- Add a persistent `CLLocationManager` coordinator in the iOS runner.
- Register a circular monitored region with entry and exit notifications.
- Register significant-location-change monitoring as a backup wake-up and
  recovery signal, not as the exact dormitory boundary.
- Handle `didEnterRegion` and `didExitRegion` callbacks.
- Request a short location confirmation session after a callback.
- Store minimized pending transitions in native protected preferences/storage.
- Expose registration, removal, health, and queue-drain operations through a
  Flutter method channel.

### Permissions and capabilities

- Preserve the current when-in-use and always-location purpose strings.
- Request when-in-use first, then request always access with a clear explanation.
- Preserve the location background mode.
- Verify signing capabilities and App Store privacy declarations before release.

### iOS limitations

- iOS controls callback timing and may delay delivery.
- Registered geographic region and significant-location-change services can
  relaunch an application that is not running, including after it is removed
  from the app switcher, but this must be validated on supported iOS versions.
- Native relaunches may be throttled, particularly during repeated test
  crossings over a short period.
- A small dormitory-sized region may be less reliable than a larger wake-up
  region because Core Location also depends on Wi-Fi and cellular conditions.
- Significant-location changes are coarse and may be detected only after the
  tenant has moved well beyond the dormitory.
- Region monitoring is not a continuous high-accuracy location stream.

## 11. Flutter coordination layer

Add a `TripwireGeofenceService` responsible for:

- sending the active boundary and tenant identity scope to native code;
- registering monitoring after successful tenant authentication and permission
  onboarding;
- removing monitoring on sign-out or role/account change;
- draining minimized native events at startup and app resume;
- passing confirmed events to `GateService`;
- exposing monitoring health to the UI; and
- avoiding simultaneous registration for multiple accounts.

Update `SessionController` so tenant authentication restores monitoring but does
not initiate an event-producing presence check.

Update `GeofenceScheduler` so it performs only:

- app-resume reconciliation;
- boundary-configuration refresh;
- recovery after unavailable monitoring; and
- optional low-frequency health checks.

It must not continually write identical presence checkpoints.

## 12. Native pending-event format

Store no coordinates or raw distance. A pending item needs only:

```json
{
  "native_event_id": "UUID",
  "tenant_id": "authenticated tenant UUID",
  "direction": "OUT",
  "observed_at": "2026-09-21T14:30:00Z",
  "platform": "android",
  "state": "confirmed"
}
```

Requirements:

- Maximum 24 pending items.
- Expire items after 24 hours.
- Use native application-private storage.
- Never store access tokens in this queue.
- Clear events for a different tenant during account changes.
- Drain idempotently; remove an item only after successful server acceptance.

If a native transition is captured while Flutter cannot run, it is saved here.
Server visibility may be delayed until background execution or the next app
launch permits authenticated synchronization.

## 13. Supabase compatibility and migration strategy

### Minimum-change option (recommended first)

Keep the current columns and send native transitions through
`record_tenant_geofence_check`:

- `p_direction`: `IN` or `OUT`.
- `p_status`: `Verified`.
- `p_checkpoint_type`: initially `on_demand`, or add `native_transition` through
  a small controlled migration.

The existing RPC continues to convert an unauthorized curfew `OUT` event into
`Flagged`.

### Recommended small migration

Add `native_transition` to the `checkpoint_type` constraint and RPC allow-list.
Add a nullable, unique `client_event_id` so offline retries are idempotent
across longer intervals, not only within the existing 45-second duplicate
window.

Do not add confidence, raw coordinates, or the six-state model for the tripwire
version.

## 14. Synchronization rules

1. Native code captures and confirms the crossing.
2. Flutter drains the queue when an authenticated engine is available.
3. Confirm the queued tenant ID matches the active authenticated user.
4. Send the event through the secure RPC with its client event ID and observed
   timestamp.
5. Supabase validates the timestamp and deduplicates the event.
6. Supabase applies curfew/approved-leave rules using Philippine time.
7. Remove the local item only after confirmed acceptance or confirmed duplicate.
8. Notify tenant, guardian, and staff data controllers through the existing
   realtime/refresh path.

Server timestamps should record insertion time separately from the device's
validated `observed_at`, because an offline event may synchronize later.

## 15. UI changes

### Tenant

- Show `Tripwire monitoring active`, `Permission required`, `Location off`, or
  `Monitoring restricted`.
- Explain background permission before requesting it.
- Provide shortcuts to application and location settings.
- Show the most recent crossing and when it was observed.

### Guardian and staff

- Continue showing the linked/authorized tenant's event history.
- Label events as entry or exit rather than promising continuous live presence.
- When useful, show `Last recorded entry/exit` instead of `Currently inside`.
- Show delayed synchronization time separately if an event was captured offline.

The UI must not convert the absence of a recent event into a claim that the
tenant is inside or outside.

## 16. Security and privacy

- Raw coordinates remain in function scope only for confirmation.
- Do not write coordinates to native preferences, Dart preferences, Supabase,
  logs, analytics, or crash reports.
- Do not accept a caller-provided tenant ID in the public GPS RPC; derive it
  from `auth.uid()`.
- Validate that queued events belong to the active user before synchronization.
- Stop and clear tenant-scoped native monitoring on sign-out.
- Keep `gate_events` append-only for client roles.
- Preserve guardian access only through verified guardian-tenant links.

## 17. Delivery phases

### Phase 0: behavior lock and test fixtures

- Agree that the feature is an event logger, not continuous presence proof.
- Freeze the initial entry/exit margins and confirmation interval for testing.
- Add test cases for the state machine before changing runtime behavior.

Exit criterion: the team approves the tripwire semantics and known limitations.

### Phase 1: Dart state machine and baseline semantics

- Add baseline-versus-transition logic.
- Ensure authentication never creates an event.
- Add two-reading confirmation in the foreground.
- Prevent repeated same-direction events.
- Preserve last confirmed side during unavailable checks.
- Adapt the existing scheduler to reconciliation-only behavior.

Exit criterion: foreground walk tests create exactly one event per crossing.

### Phase 2: Android native tripwire

- Implement registration, receiver, confirmation, native queue, channel, and
  monitoring-health reporting.
- Add staged permissions and required manifest declarations.
- Add restart restoration if feasible within release scope.

Exit criterion: physical Android tests pass in foreground, background, screen
off, recent-app removal, process death, offline, and recovery scenarios.

### Phase 3: iOS native tripwire

- Implement Core Location region monitoring, native queue, confirmation,
  channel, and health reporting.
- Validate authorization upgrade and background behavior.

Exit criterion: the equivalent physical iPhone test matrix passes within iOS
platform limitations.

### Phase 4: server idempotency and delayed-event handling

- Add `native_transition`, client event IDs, and observed timestamps.
- Harden RPC validation and deduplication.
- Verify curfew classification for delayed offline events uses observed time.

Exit criterion: retries and offline synchronization cannot create duplicates or
misclassify curfew status.

### Phase 5: UI, privacy, and release readiness

- Add health/permission surfaces.
- Update wording from continuous presence to last crossing where appropriate.
- Update privacy disclosures and store-review documentation.
- Complete on-site tuning and battery testing.

Exit criterion: behavior, limitations, and data use are accurately represented
in the product and release materials.

## 18. Test matrix

### Logic tests

- Initial inside and initial outside states create no event.
- `inside -> outside` creates one `OUT`.
- `outside -> inside` creates one `IN`.
- Repeated `OUT` while already outside is ignored.
- Repeated `IN` while already inside is ignored.
- One noisy sample creates no transition.
- Two agreeing acceptable samples confirm a transition.
- Conflicting samples retain the previous state.
- Mocked, stale, and low-accuracy samples are rejected.
- `UNAVAILABLE` does not erase the last confirmed side.

### Native lifecycle tests

- Foreground.
- Background.
- Screen locked.
- Removed from recents.
- Process killed by the OS.
- Device restarted.
- App updated.
- Android force-stop limitation.
- iOS relaunch after the app is removed from the app switcher.
- iOS region relaunch after removal from the app switcher.
- iOS significant-location-change recovery trigger.

### Connectivity tests

- Online crossing.
- Offline crossing followed by reconnection.
- Multiple offline crossings in correct order.
- Expired pending event.
- Duplicate delivery.
- Account switch before queue synchronization.

### On-site tests

- Walk through each practical entrance and exit.
- Walk parallel to each boundary without crossing.
- Stand near the boundary for several minutes.
- Test inside rooms with weak GPS.
- Test daytime, pre-curfew, and curfew periods.
- Measure callback delay and false-positive/false-negative rates.
- Measure battery consumption over at least one daytime and overnight period.

## 19. Acceptance criteria

The feature is ready when:

1. Login, logout, and app launch never create physical crossing events.
2. A normal boundary crossing produces one correct event, usually within
   the accepted 15-minute delivery window under supported conditions.
3. Remaining near the boundary does not create repeated IN/OUT oscillation.
4. Events captured offline synchronize once without duplicates.
5. Android and iOS background tests pass on physical devices.
6. Monitoring failures are visible to the tenant.
7. No raw tenant coordinate is persisted or transmitted.
8. Curfew classification remains correct for online and delayed events.
9. Guardians can access only linked tenants' events.
10. Product wording acknowledges platform limitations and does not promise
    guaranteed operation after Android force-stop, disabled location, revoked
    permission, a powered-off phone, or unavailable location signals.

## 20. Recommended implementation decision

Use native OS geofencing as the tripwire trigger, the existing polygon logic as
the confirmation check, the existing Supabase RPC and event table as the main
backend path, and a minimized native queue for callbacks received while Flutter
or the network is unavailable.

Avoid a broad presence-model redesign. Keep the database focused on `IN` and
`OUT` crossings, add only the idempotency and observed-time fields required for
reliable background/offline delivery, and treat monitoring health separately
from physical events.

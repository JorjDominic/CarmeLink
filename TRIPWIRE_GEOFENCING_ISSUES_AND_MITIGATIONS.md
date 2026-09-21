# Tripwire Geofencing: Possible Issues and Mitigations

## Purpose

CarmeLink's geofence will act like a virtual tripwire:

- When a tenant leaves the dormitory boundary, log `OUT`.
- When a tenant enters the dormitory boundary, log `IN`.
- The tenant does not need to press a button or create a manual log during
  normal operation.

The system uses the tenant's phone. It does not require gate hardware.

This document explains what can go wrong and what CarmeLink can do about it in
simple terms.

## Important limitation

No phone-only geofence can be guaranteed to work all the time. The tenant owns
the phone and can turn it off, disable location, remove permission, force-stop
the app, or leave the phone somewhere else.

CarmeLink should therefore describe geofence logs as **automatic supporting
evidence**, not perfect proof that a tenant is physically present.

## Quick reference

| Situation | Will automatic logging work? | What CarmeLink should do |
| --- | --- | --- |
| App is open | Yes, normally | Detect and confirm crossings. |
| App is in the background | Yes, with correct permission | Use native low-power geofencing. |
| Phone screen is locked | Yes, normally | Continue native monitoring. |
| App has not been opened for days | Yes, normally | Keep native monitoring registered. |
| Android app is swiped from Recent Apps | Usually yes | Test on real devices and restore when reopened. |
| Android user selects Force stop in Settings | No | Restore monitoring after the app is opened again. |
| iPhone user swipes CarmeLink away | iOS region or significant-change events can relaunch it, but delivery remains system-controlled | Recreate location monitoring on relaunch and test on physical devices. |
| Location permission is removed | No | Show a warning and an Open Settings button. |
| Location services are turned off | No | Show that automatic logging is paused. |
| Phone has no internet | Crossing can be saved locally | Upload it when internet returns. |
| Phone is turned off | No | Mark the period as unknown. |
| GPS signal is weak | Possibly delayed or unavailable | Reject poor readings and retry. |

## App closure and background behavior

### The app is left in the background

**Issue:** The tenant may rarely open CarmeLink.

**Expected behavior:** This is fine. Native Android and iOS geofencing is
designed to wait in a low-power state and wake the app when a boundary may have
been crossed.

**Mitigation:**

- Use native operating-system geofencing, not only a Flutter timer.
- Register monitoring after setup and keep it registered.
- Restore registration after account, permission, or boundary changes.
- Use high-accuracy GPS only briefly after a possible crossing.

### Android app is swiped away

**Issue:** The tenant removes CarmeLink from the Recent Apps screen or selects
Close All.

**Expected behavior:** On standard Android, this normally removes the visible
app screen but is not the same as Force stop. A native geofence receiver should
usually continue working. Some phone brands apply stricter battery rules.

**Mitigation:**

- Use a native Android geofence receiver.
- Avoid relying on a Dart timer or a permanently open Flutter screen.
- Test Samsung, Xiaomi, Oppo, Vivo, Realme, and other devices used by tenants.
- Show battery-optimization guidance only when the phone is known to restrict
  CarmeLink.
- Restore and verify monitoring whenever the app opens.

### Android Force stop

**Issue:** The tenant opens Android Settings, selects CarmeLink, and presses
Force stop.

**Expected behavior:** Android blocks the app's receivers and background work
until the tenant manually opens CarmeLink again. The app cannot bypass this.

**Mitigation:**

- Restore geofencing immediately when CarmeLink is opened again.
- Record the time when monitoring reconnects.
- Mark the missing period as `Monitoring status unknown`.
- Do not assume the tenant stayed inside or went outside during the gap.
- Explain during onboarding that Force stop pauses automatic logging.

### iPhone app is swiped away

**Issue:** The tenant manually swipes CarmeLink away in the iPhone app switcher.

**Expected behavior:** Registered geographic region monitoring and the
significant-location-change service can cause iOS to relaunch CarmeLink in the
background for a location event. The exact timing is controlled by iOS and can
be delayed or throttled, so this is not the same as continuous tracking.

**Mitigation:**

- Register native geographic region monitoring before the app closes.
- Register significant-location-change monitoring as a coarse backup trigger.
- Recreate `CLLocationManager` immediately when iOS relaunches CarmeLink for a
  location event.
- Save the transition locally during the short background execution window.
- Restore and verify geofencing whenever the tenant opens CarmeLink.
- Mark missing periods as unknown rather than creating fake events.
- Test removal from the app switcher on each supported iOS version.

### Operating system closes the app to free memory

**Issue:** Android or iOS removes the app process because the phone needs memory.

**Expected behavior:** Properly registered native geofencing can normally wake
an eligible app for a boundary event. This is different from a deliberate
force-stop or force-quit.

**Mitigation:**

- Keep geofence registration in native Android/iOS code.
- Store the minimum configuration needed to restore monitoring.
- Queue the crossing locally if Flutter is not running.
- Test actual process death on physical phones.

### Phone restarts

**Issue:** A restart may clear some scheduled work or registration.

**Mitigation:**

- On Android, add a permitted boot receiver that restores the registered
  geofence.
- On iOS, follow Core Location region-monitoring behavior and verify it on a
  physical device.
- Always verify registration the next time CarmeLink opens.
- Show an unknown state if restoration cannot be confirmed.

## Permission problems

### Tenant grants only foreground permission

**Issue:** `While using the app` permission is not enough for dependable
background tripwire behavior.

**Mitigation:**

1. First explain why CarmeLink needs location.
2. Request foreground permission.
3. Explain why background monitoring is needed.
4. Request `Allow all the time` on Android or `Always` on iOS.
5. Register the geofence only after the needed permission is granted.

Do not repeatedly display permission popups without an explanation.

### Tenant denies permission

**Issue:** The operating system may allow the app to ask again, or it may require
the tenant to use Settings.

**Mitigation:**

- Show `Automatic entry and exit logging is paused`.
- Provide an `Enable location monitoring` button.
- Ask again only after the tenant taps the button.
- If the permission is permanently denied, show an `Open Settings` button.
- Never display monitoring as active while permission is missing.

### Tenant removes permission later

**Issue:** The app cannot silently restore a permission that the tenant removed.

**Mitigation:**

- Check permission whenever the app opens or resumes.
- Check permission before registering monitoring.
- Show a persistent warning until the problem is fixed.
- Restore monitoring automatically after permission is granted again.
- Mark the unmonitored period as unknown.

### iOS changes precise location to approximate location

**Issue:** Approximate location may be too broad to identify a small dormitory
boundary reliably.

**Mitigation:**

- Explain why Precise Location improves entry and exit detection.
- Show that monitoring accuracy is limited when precise access is off.
- Direct the tenant to iOS Settings if precise access is required.
- Do not accept a low-quality position as a confirmed crossing.

## Location-service problems

### Location services are turned off

**Issue:** CarmeLink cannot receive reliable GPS or geofence information.

**Mitigation:**

- Show `Location services are off - automatic logging is paused`.
- Provide an `Open Location Settings` button where the platform permits it.
- Recheck automatically when the app resumes.
- Preserve the last event for history, but label current monitoring as unknown.

### Weak GPS indoors

**Issue:** Walls, roofs, weather, and surrounding buildings can reduce GPS
accuracy.

**Mitigation:**

- Reject readings with poor reported accuracy.
- Retry after a short delay.
- Use the operating system's combined location sources, not GPS satellites only.
- Keep the previous confirmed side when a check is uncertain.
- Tune the boundary using physical walk tests.

### GPS position moves while the tenant is standing still

**Issue:** Normal GPS drift can make a phone appear to jump across the boundary.

**Mitigation:**

- Do not log a crossing from one reading.
- Require two acceptable readings that agree.
- Wait about 10-15 seconds between confirmation readings.
- Require an entry to be clearly inside.
- Require an exit to be about 10-15 metres beyond the polygon edge initially.
- Ignore repeated events in the same direction.

### Detection is delayed

**Issue:** Android or iOS may delay a background callback to save battery. GPS
may also need time to find an accurate position.

**Mitigation:**

- Accept a project delivery target of up to 15 minutes.
- Expect many events to arrive sooner under good conditions.
- Save the time the crossing was observed separately from the upload time.
- Avoid promising instant detection.
- Prefer a small delay over a false event.

### Small iOS geofence is not triggered reliably

**Issue:** The dormitory's current 50-metre circle may be too small for reliable
iOS region monitoring in some environments. Core Location uses more than exact
GPS and can be affected by Wi-Fi, cellular coverage, buildings, and signal
reflections.

**Mitigation:**

- Use a larger native circle as a low-power wake-up area.
- Use the exact dormitory polygon only after the app wakes and obtains a usable
  location.
- Add significant-location-change monitoring as a backup wake-up trigger.
- Test several radii around the actual property.
- Accept that the logged observation may occur after the tenant has moved away
  from the exact gate.
- Do not invent an exact gate-crossing time when detection was delayed.

### Mock or fake location

**Issue:** A tenant may use location-spoofing tools.

**Mitigation:**

- Continue rejecting locations marked as mocked by the operating system.
- Treat detection as a warning signal, not absolute proof of misconduct.
- Log monitoring health separately without saving the fake coordinates.
- Do not claim that phone-only anti-spoofing is impossible to bypass.

### Tenant leaves the phone in the dormitory

**Issue:** CarmeLink monitors the phone, not the person's body.

**Mitigation:**

- Clearly describe the feature as device-based geofencing.
- Treat logs as supporting evidence.
- Do not claim that an `IN` phone proves the tenant is physically inside.
- Without another trusted signal or hardware, this cannot be solved completely.

## Event-logging problems

### Login creates a false event

**Issue:** Starting monitoring while the tenant is already inside or outside
could be mistaken for a crossing.

**Mitigation:**

- Establish the initial side as a silent baseline.
- Do not create `IN` or `OUT` during login, setup, or app launch.
- Create an event only after a confirmed change from the baseline.

### Duplicate events

**Issue:** Android/iOS callbacks, retries, or GPS drift may send the same event
more than once.

**Mitigation:**

- After logging `OUT`, ignore more `OUT` callbacks until `IN` is confirmed.
- After logging `IN`, ignore more `IN` callbacks until `OUT` is confirmed.
- Give every native event a unique ID.
- Make the server accept each event ID only once.
- Keep the existing short-time database duplicate check as extra protection.

### Rapid IN/OUT switching near the boundary

**Issue:** A tenant near a wall or entrance might appear to cross repeatedly.

**Mitigation:**

- Use different entry and exit margins.
- Require two agreeing readings.
- Add a short cooldown after a confirmed crossing.
- Tune the boundary at every real entrance.
- Do not make the cooldown so long that a genuine quick return is missed.

### Events arrive out of order

**Issue:** Several offline events may upload later in the wrong order.

**Mitigation:**

- Store the observed time on the device.
- Upload queued events in observed-time order.
- Let the server validate reasonable timestamps.
- Update current state from the newest accepted observed event, not merely the
  latest upload.

### An old queued event uploads later

**Issue:** An event captured hours ago could incorrectly appear to be current.

**Mitigation:**

- Store both `observed_at` and server `created_at`.
- Display the observed time to users.
- Expire unsent events after 24 hours.
- Mark delayed events clearly if needed.
- Apply curfew rules using the validated observed time.

### App account changes before upload

**Issue:** A transition from one tenant must not be uploaded under another
tenant's session.

**Mitigation:**

- Store the tenant ID with the minimized pending event.
- Compare it with the authenticated user before upload.
- Never upload mismatched events.
- Clear or isolate the old tenant's queue during account changes.
- Remove native monitoring immediately on sign-out.

## Internet and server problems

### No internet during a crossing

**Issue:** The phone detects a crossing but cannot contact Supabase.

**Mitigation:**

- Save the minimized event in private local storage.
- Store no coordinates.
- Retry when connectivity or app execution returns.
- Keep no more than 24 pending events.
- Remove events older than 24 hours.
- Delete an item only after the server accepts it.

### Supabase is temporarily unavailable

**Issue:** Upload may fail even when the phone has internet.

**Mitigation:**

- Use the same bounded queue and retry behavior.
- Use increasing retry delays instead of constant requests.
- Keep unique event IDs so retries cannot create duplicates.
- Show a synchronization warning without losing the captured crossing.

### Authentication session expires

**Issue:** Native code may capture a crossing but cannot safely upload it.

**Mitigation:**

- Save the minimized event locally.
- Do not store or invent permanent credentials in native code.
- Refresh the session through the normal Supabase client when possible.
- Synchronize only after the active authenticated tenant is confirmed.

## Battery problems

### Continuous GPS drains the battery

**Issue:** Constant high-accuracy location could drain the battery and encourage
tenants to close or restrict the app.

**Mitigation:**

```text
Most of the time:
Low-power native geofence waits

Possible crossing:
High-accuracy location runs briefly
-> confirms IN or OUT
-> stops again
```

- Do not run a one-minute GPS timer all day.
- Let the operating system provide the low-power tripwire.
- Use high accuracy only during short confirmation windows.
- Measure real battery use during daytime and overnight tests.

### Phone battery dies or the phone is turned off

**Issue:** No app can detect a crossing while the device has no power.

**Mitigation:**

- Mark the period as unknown after monitoring becomes stale.
- Restore monitoring after restart.
- Never invent a missing `IN` or `OUT` event.

### Manufacturer battery restrictions

**Issue:** Some Android manufacturers stop background work more aggressively
than standard Android.

**Mitigation:**

- Detect known battery restrictions where possible.
- Give device-specific instructions only when needed.
- Ask for battery-optimization exemption only if testing shows it is necessary.
- Keep the app battery-efficient so an exemption is easier to justify.
- Test the actual phone brands used by residents.

## Boundary-configuration problems

### Wrong dormitory coordinates

**Issue:** An inaccurate polygon will produce incorrect entry and exit events.

**Mitigation:**

- Verify every polygon point on site.
- Walk every side and entrance while recording test results.
- Keep one active, versioned boundary on the server.
- Cache the last valid boundary for offline operation.
- Require authorized staff access to change it.

### Boundary changes while the app is closed

**Issue:** Native monitoring may continue using an older boundary.

**Mitigation:**

- Store a boundary version.
- Refresh configuration when the app opens or receives permitted background
  work.
- Re-register native regions after a version change.
- Keep the old valid boundary until the new one is completely registered.

### Circular native region does not exactly match the polygon

**Issue:** Android/iOS use a circular region to wake the app, while the dormitory
lot is a polygon.

**Mitigation:**

- Use the circle only as the low-power wake-up trigger.
- Use the exact polygon for the confirmation decision.
- Choose a circle that does not miss any important entrance.
- Test callbacks around every polygon edge.

### Significant-location recovery happens far from the dormitory

**Issue:** iOS significant-location changes are intentionally coarse. The phone
may move hundreds of metres before CarmeLink is awakened.

**Mitigation:**

- Use this service only as backup for a missed region callback.
- Compare the confirmed current side with the saved baseline.
- Store the time the new side was confirmed, not a guessed gate-crossing time.
- Allow the project's 15-minute delivery window.
- Review events near curfew rather than assuming an exact departure minute.

## Status and honesty problems

### Old status looks current

**Issue:** Showing `Inside` without a time may mislead guardians or staff when
monitoring stopped hours ago.

**Mitigation:**

- Prefer `Last recorded entry: 8:42 PM`.
- Show when the event was observed.
- Mark monitoring as stale after a chosen period without device contact.
- Keep monitoring health separate from the last crossing.

### Missing event is treated as a violation

**Issue:** A technical failure could unfairly look like tenant misconduct.

**Mitigation:**

- `No event` must mean `unknown`, not automatically `inside` or `outside`.
- Permission loss, force-stop, dead battery, and signal failure are monitoring
  problems, not proof of a curfew violation.
- Flag only a confirmed `OUT` crossing under the server's curfew rules.
- Allow authorized staff to review gaps and context.

### Guardian expects a perfect live tracker

**Issue:** Guardians may assume the app always knows the tenant's location.

**Mitigation:**

- Use wording such as `Last automatic dorm entry/exit event`.
- Display observation time and monitoring status.
- Explain that CarmeLink does not continuously track exact location.
- Avoid a live-map design that implies accuracy the system does not have.

## Privacy and security problems

### Exact coordinates are exposed

**Issue:** Raw location history would create unnecessary privacy and security
risk.

**Mitigation:**

- Evaluate coordinates on the phone.
- Upload only `IN`, `OUT`, timestamp, event ID, and limited technical metadata.
- Never save latitude, longitude, or exact distance in the database, logs,
  analytics, crash reports, or local queue.

### Guardian sees an unrelated tenant

**Issue:** Presence events are sensitive.

**Mitigation:**

- Keep Supabase row-level security enabled.
- Allow guardians to read only verified linked tenants.
- Derive the tenant ID from authenticated sessions for writes.
- Test access using multiple real accounts before release.

### Native event is changed or replayed

**Issue:** A queued event could be sent more than once or altered.

**Mitigation:**

- Use private application storage.
- Give every event a random unique ID.
- Make the server accept each ID only once.
- Validate direction, timestamp range, authenticated role, and allowed values.
- Keep the event table append-only for mobile clients.

## User-facing monitoring status

CarmeLink should show one simple status:

| Color | Status | Meaning |
| --- | --- | --- |
| Green | Automatic logging active | Required permission and monitoring are active. |
| Amber | Monitoring limited | Battery, accuracy, or background restrictions may delay events. |
| Red | Action required | Permission is missing or location services are off. |
| Gray | Monitoring unknown | The app has not confirmed device contact recently. |

Suggested messages:

- `Automatic entry and exit logging is active.`
- `Allow background location to continue automatic logging.`
- `Location services are off. Automatic logging is paused.`
- `Monitoring has not been confirmed since 8:42 PM.`
- `Last recorded exit: 9:17 PM.`

## Recommended permission experience

1. Explain the feature before showing an operating-system prompt.
2. Ask for foreground location.
3. Ask for background/Always location only after foreground access succeeds.
4. Explain that CarmeLink can remain in the background and uses low power while
   waiting for a crossing.
5. Show how to fix permission or location settings if monitoring stops.
6. Recheck automatically when the app opens or resumes.
7. Never repeatedly nag the tenant on every screen or silently claim success.

## Final recommendation

Build CarmeLink as an automatic, low-power tripwire rather than a continuous
tracker:

```text
Native geofence waits
-> possible crossing detected
-> two short location checks confirm it
-> one IN or OUT event is saved
-> duplicate events are ignored
-> event uploads now or waits safely for internet
```

This design can work well when the app is open, backgrounded, screen-locked, or
not running. On iOS, registered region or significant-location events can
relaunch CarmeLink, although iOS controls timing and may throttle delivery. It
cannot overcome Android Force stop, disabled location, removed permission, a
powered-off phone, unusable signals, or a phone left behind.

When CarmeLink cannot know what happened, it should show **unknown** rather than
guessing. That makes the module useful, fair, privacy-conscious, and technically
honest.

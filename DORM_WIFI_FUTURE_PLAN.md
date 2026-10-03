# Possible future addition: dormitory Wi-Fi presence evidence

Recorded October 3, 2026. Status: **proposed / deferred / not implemented**.
The dormitory router brand, model, controller and available integrations are
currently unknown. Revisit after identifying the network equipment; no hardware
choice or implementation commitment is required now.

## Purpose

Provide supplementary presence evidence when GPS/location monitoring is
unavailable. Prefer the dorm router/controller reporting an enrolled device's
recent connection over continuous Wi-Fi scanning by the mobile app.
This is connected-device evidence, not proof that the tenant crossed the gate
or is physically inside. A phone can remain connected outside the dorm, or be
left behind by its owner.

The September 30 geofencing remains the detection baseline. Implement Wi-Fi
evidence as a separate module, without changing GPS polygon rules or writing
verified gate events from Wi-Fi observations.

## Proposed display and rules

| Evidence | Display | Effect on verified gate state |
|---|---|---|
| Existing GPS verification | Inside / Outside — GPS verified | Existing geofencing behavior |
| Recent enrolled-device dorm Wi-Fi connection | Likely inside — Dorm Wi-Fi, with observation time | None |
| Location unavailable, no fresh Wi-Fi evidence | Presence unknown; show last verified status and its age separately | None |

- A disconnection, missing device, weak signal or expired observation must never
  create an OUT event. Phones can disconnect while still inside.
- Use a freshness window, sustained-connection requirement and deduplication;
  choose their values from coverage/device tests rather than guessing now.
- Location-off incidents and reminders remain active even when Wi-Fi evidence
  exists. Guardian/staff views can show the supplementary evidence alongside
  the monitoring outage; Wi-Fi must not silently clear it.
- Obtain explicit device enrollment and explain what is collected. Private or
  randomized MAC addresses can change; avoid treating an IP/MAC alone as a
  durable tenant identity. Support re-enrollment and device removal.
- Keep only necessary device mappings and minimized evidence timestamps/source.
  Decide access, retention and deletion rules before implementation.

## Step-by-step plan

1. **Identify equipment.** Record router/AP brand, model, firmware, controller,
   administrator access and dorm Wi-Fi coverage. Determine whether a supported
   API, webhook or client-association log exposes connection/disconnection
   information. Do not select a vendor-specific implementation before this.
2. **Check feasibility.** Test which connection information is available, how
   stale it can be, and how sleeping phones/private addresses behave. Determine
   whether tenant enrollment can reliably map a device to an account. If the
   equipment cannot support this, leave the feature deferred and assess options
   separately before proposing any hardware purchase.
3. **Define the integration.** Use a server-side adapter or local bridge to
   authenticate network observations and send minimized evidence to Supabase.
   Keep router credentials off phones and out of the repository. Choose push
   events or modest polling according to the supported interface.
4. **Prototype separately.** Add enrollment, evidence storage, freshness and
   authorization rules behind a disabled-by-default feature flag. Verify that
   observations cannot write gate_events or overwrite current_gate_status.
5. **Add the indicator.** Show source, confidence and observation time for
   tenants, linked guardians and authorized staff. Preserve the distinction
   between verified status, last known status and current unknown status.
6. **Pilot and evaluate.** Test indoors, outside near Wi-Fi coverage, at the
   gate, with Location off, app backgrounded, screen locked, Wi-Fi off, sleeping
   phones, router reboot, internet outage and changed private addresses. Measure
   false associations, stale evidence, delay and battery impact.
7. **Decide whether to ship.** Enable only if evidence remains useful and clearly
   labeled. Add deployment, enrollment, retention and rollback instructions.

## Constraints and acceptance criteria

App-only SSID checks are an easier prototype but are not a dependable substitute
for background monitoring with location disabled. Android restricts location-
sensitive Wi-Fi identifiers; iOS requires entitlements and qualifying access
conditions. Router-side observation avoids requiring the app to execute for each
connection observation, but still depends on network equipment and device behavior.

- [Android Wi-Fi information API](https://developer.android.com/reference/android/net/wifi/WifiInfo)
- [Apple current network information API](https://developer.apple.com/documentation/systemconfiguration/cncopycurrentnetworkinfo)

Accept the prototype only if it cannot generate false verified IN/OUT events,
expires stale evidence, isolates tenant/device access, handles enrollment changes,
and shows useful evidence during the tested outage scenarios. Router-side
observation is expected to have little additional mobile-app battery overhead;
that expectation must be measured. No delivery or accuracy guarantee is made.

This plan concerns existing dorm Wi-Fi association. A separate Bluetooth beacon
is a different hardware/platform design and would need its own feasibility review.

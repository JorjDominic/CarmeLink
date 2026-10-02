import Flutter
import CoreLocation
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let tripwire = TripwireLocationManager.shared

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    tripwire.restoreIfNeeded()
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "carmelitas/tripwire_geofence",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handleTripwireCall(call, result: result)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleTripwireCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "register":
      guard
        let args = call.arguments as? [String: Any],
        let latitude = args["latitude"] as? Double,
        let longitude = args["longitude"] as? Double,
        let radius = args["radiusMeters"] as? Double,
        let tenantId = args["tenantId"] as? String
      else {
        result(FlutterError(code: "invalid_arguments", message: "Boundary and tenant are required.", details: nil))
        return
      }
      tripwire.register(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        tenantId: tenantId,
        initialDirection: args["initialDirection"] as? String,
        polygon: args["polygon"] as? [[String: Double]] ?? [],
        edgeBuffer: args["edgeBufferMeters"] as? Double ?? 3,
        gateEnabled: args["gateEnabled"] as? Bool ?? false,
        gateStartLatitude: args["gateStartLatitude"] as? Double,
        gateStartLongitude: args["gateStartLongitude"] as? Double,
        gateEndLatitude: args["gateEndLatitude"] as? Double,
        gateEndLongitude: args["gateEndLongitude"] as? Double,
        gateTolerance: args["gateToleranceMeters"] as? Double ?? 15,
        configVersion: args["configVersion"] as? Int ?? 1,
        accessToken: args["accessToken"] as? String ?? "",
        refreshToken: args["refreshToken"] as? String ?? "",
        supabaseURL: args["supabaseUrl"] as? String ?? "",
        publishableKey: args["publishableKey"] as? String ?? ""
      )
      result(true)
    case "unregister":
      tripwire.unregister()
      result(true)
    case "consumePending":
      result(tripwire.pendingEvents())
    case "acknowledge":
      guard
        let args = call.arguments as? [String: Any],
        let eventId = args["eventId"] as? String
      else {
        result(FlutterError(code: "invalid_arguments", message: "Event ID is required.", details: nil))
        return
      }
      tripwire.acknowledge(eventId: eventId)
      result(true)
    case "status":
      result(tripwire.status())
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

final class TripwireLocationManager: NSObject, CLLocationManagerDelegate {
  static let shared = TripwireLocationManager()

  private let manager = CLLocationManager()
  private let defaults = UserDefaults.standard
  private let regionIdentifier = "carmelita_dormitory"
  private let gateRegionIdentifier = "carmelita_official_gate"
  private let queueKey = "tripwire_pending_events"
  private let registeredKey = "tripwire_registered"
  private let queuedDirectionKey = "tripwire_queued_direction"
  private let confirmedDirectionKey = "tripwire_confirmed_direction"
  private let candidateDirectionKey = "tripwire_candidate_direction"
  private let candidateFixCountKey = "tripwire_candidate_fix_count"
  private let candidateStartedAtKey = "tripwire_candidate_started_at"
  private let candidateLastFixAtKey = "tripwire_candidate_last_fix_at"
  private let candidateOriginLatKey = "tripwire_candidate_origin_lat"
  private let candidateOriginLngKey = "tripwire_candidate_origin_lng"
  private let candidateMovingKey = "tripwire_candidate_moving"
  private let monitoringAvailableKey = "tripwire_monitoring_available"
  private let monitoringReasonKey = "tripwire_monitoring_reason"
  private var burstTimeout: DispatchWorkItem?
  private var burstActive = false
  private var syncing = false
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var burstBackgroundTask: UIBackgroundTaskIdentifier = .invalid

  private override init() {
    super.init()
    manager.delegate = self
    manager.pausesLocationUpdatesAutomatically = false
    manager.allowsBackgroundLocationUpdates = true
    manager.showsBackgroundLocationIndicator = true
    manager.activityType = .fitness
  }

  func register(
    latitude: Double,
    longitude: Double,
    radius: Double,
    tenantId: String,
    initialDirection: String?,
    polygon: [[String: Double]],
    edgeBuffer: Double,
    gateEnabled: Bool,
    gateStartLatitude: Double?,
    gateStartLongitude: Double?,
    gateEndLatitude: Double?,
    gateEndLongitude: Double?,
    gateTolerance: Double,
    configVersion: Int,
    accessToken: String,
    refreshToken: String,
    supabaseURL: String,
    publishableKey: String
  ) {
    let previousTenant = defaults.string(forKey: "tripwire_tenant_id")
    if previousTenant != tenantId {
      defaults.removeObject(forKey: queueKey)
      defaults.removeObject(forKey: confirmedDirectionKey)
      defaults.removeObject(forKey: queuedDirectionKey)
    }
    defaults.set(tenantId, forKey: "tripwire_tenant_id")
    defaults.set(latitude, forKey: "tripwire_latitude")
    defaults.set(longitude, forKey: "tripwire_longitude")
    defaults.set(radius, forKey: "tripwire_radius")
    defaults.set(true, forKey: registeredKey)
    defaults.set(polygon, forKey: "tripwire_polygon")
    defaults.set(edgeBuffer, forKey: "tripwire_edge_buffer")
    defaults.set(gateEnabled, forKey: "tripwire_gate_enabled")
    defaults.set(gateTolerance, forKey: "tripwire_gate_tolerance")
    defaults.set(configVersion, forKey: "tripwire_config_version")
    defaults.set(accessToken, forKey: "tripwire_access_token")
    defaults.set(refreshToken, forKey: "tripwire_refresh_token")
    defaults.set(supabaseURL, forKey: "tripwire_supabase_url")
    defaults.set(publishableKey, forKey: "tripwire_publishable_key")
    if let value = gateStartLatitude { defaults.set(value, forKey: "tripwire_gate_start_lat") }
    if let value = gateStartLongitude { defaults.set(value, forKey: "tripwire_gate_start_lng") }
    if let value = gateEndLatitude { defaults.set(value, forKey: "tripwire_gate_end_lat") }
    if let value = gateEndLongitude { defaults.set(value, forKey: "tripwire_gate_end_lng") }
    if initialDirection == "IN" || initialDirection == "OUT" {
      defaults.set(initialDirection, forKey: confirmedDirectionKey)
    }
    defaults.removeObject(forKey: candidateDirectionKey)
    defaults.removeObject(forKey: candidateFixCountKey)
    defaults.removeObject(forKey: candidateStartedAtKey)
    clearCandidateEvidence()

    // Start monitoring if authorized for Always OR When In Use.
    // When In Use will still receive region callbacks while active/suspended,
    // and requesting Always authorization prompts the user to upgrade to full background.
    let status = manager.authorizationStatus
    if status == .authorizedAlways || status == .authorizedWhenInUse {
      startMonitoring(latitude: latitude, longitude: longitude, radius: radius)
      startContinuousMonitoring(highAccuracy: false)
    }
    if status == .authorizedWhenInUse {
      manager.requestAlwaysAuthorization()
    }
    syncPendingEvents()
    evaluateMonitoringHealth()
  }

  func restoreIfNeeded() {
    guard defaults.bool(forKey: registeredKey) else { return }
    let status = manager.authorizationStatus
    guard status == .authorizedAlways || status == .authorizedWhenInUse else { return }
    startMonitoring(
      latitude: defaults.double(forKey: "tripwire_latitude"),
      longitude: defaults.double(forKey: "tripwire_longitude"),
      radius: defaults.double(forKey: "tripwire_radius")
    )
    startContinuousMonitoring(highAccuracy: false)
    if status == .authorizedWhenInUse {
      manager.requestAlwaysAuthorization()
    }
    syncPendingEvents()
    evaluateMonitoringHealth()
  }

  private func startMonitoring(latitude: Double, longitude: Double, radius: Double) {
    guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
    for region in manager.monitoredRegions where region.identifier == regionIdentifier || region.identifier == gateRegionIdentifier {
      manager.stopMonitoring(for: region)
    }
    // Region monitoring is only a low-power wake-up hint. Use the same
    // reliable minimum as Android; the precise polygon remains authoritative.
    let effectiveRadius = min(max(radius, 100), manager.maximumRegionMonitoringDistance)
    let region = CLCircularRegion(
      center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
      radius: effectiveRadius,
      identifier: regionIdentifier
    )
    region.notifyOnEntry = true
    region.notifyOnExit = true
    manager.startMonitoring(for: region)
    if defaults.bool(forKey: "tripwire_gate_enabled") {
      let gateCenter = CLLocationCoordinate2D(
        latitude: (defaults.double(forKey: "tripwire_gate_start_lat") + defaults.double(forKey: "tripwire_gate_end_lat")) / 2,
        longitude: (defaults.double(forKey: "tripwire_gate_start_lng") + defaults.double(forKey: "tripwire_gate_end_lng")) / 2
      )
      let gateRegion = CLCircularRegion(
        center: gateCenter,
        radius: max(25, defaults.double(forKey: "tripwire_gate_tolerance") * 2),
        identifier: gateRegionIdentifier
      )
      gateRegion.notifyOnEntry = true
      gateRegion.notifyOnExit = true
      manager.startMonitoring(for: gateRegion)
    }
    manager.startMonitoringSignificantLocationChanges()
    manager.requestLocation()

    if defaults.string(forKey: confirmedDirectionKey) == nil {
      manager.requestState(for: region)
    }
  }

  func unregister() {
    burstTimeout?.cancel()
    burstTimeout = nil
    burstActive = false
    manager.stopUpdatingLocation()
    for region in manager.monitoredRegions where region.identifier == regionIdentifier || region.identifier == gateRegionIdentifier {
      manager.stopMonitoring(for: region)
    }
    manager.stopMonitoringSignificantLocationChanges()
    for key in [
      queueKey, registeredKey, "tripwire_tenant_id", "tripwire_latitude",
      "tripwire_longitude", "tripwire_radius", "tripwire_confirmed_direction",
      queuedDirectionKey, "tripwire_access_token", "tripwire_refresh_token",
      "tripwire_supabase_url", "tripwire_publishable_key", "tripwire_last_sync_error",
      "tripwire_last_notification_error", "tripwire_last_synced_at",
    ] {
      defaults.removeObject(forKey: key)
    }
  }

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    guard region.identifier == regionIdentifier || region.identifier == gateRegionIdentifier else { return }
    startLocationBurst()
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    guard region.identifier == regionIdentifier || region.identifier == gateRegionIdentifier else { return }
    startLocationBurst()
  }

  func locationManager(
    _ manager: CLLocationManager,
    didDetermineState state: CLRegionState,
    for region: CLRegion
  ) {
    guard
      region.identifier == regionIdentifier,
      defaults.string(forKey: confirmedDirectionKey) == nil &&
        defaults.string(forKey: queuedDirectionKey) == nil
    else { return }
    if state == .inside {
      defaults.set("IN", forKey: confirmedDirectionKey)
    } else if state == .outside {
      defaults.set("OUT", forKey: confirmedDirectionKey)
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    reportMonitoringHealth(available: true, reason: nil)
    expireCandidateIfNeeded()
    guard
      defaults.bool(forKey: registeredKey),
      let location = locations.last,
      location.horizontalAccuracy >= 0,
      location.horizontalAccuracy <= 35,
      abs(location.timestamp.timeIntervalSinceNow) <= 120
    else { return }
    guard let direction = verifiedDirection(for: location) else { return }
    let previousLocation: CLLocation? = defaults.object(forKey: "tripwire_last_lat") == nil ? nil : CLLocation(
      latitude: defaults.double(forKey: "tripwire_last_lat"),
      longitude: defaults.double(forKey: "tripwire_last_lng")
    )
    defaults.set(location.coordinate.latitude, forKey: "tripwire_last_lat")
    defaults.set(location.coordinate.longitude, forKey: "tripwire_last_lng")
    defaults.set(location.timestamp.timeIntervalSince1970, forKey: "tripwire_last_at")
    if effectiveDirection() == nil {
      // The first significant-location callback establishes state; it is not
      // evidence that a crossing occurred after monitoring began.
      defaults.set(direction, forKey: confirmedDirectionKey)
      defaults.removeObject(forKey: candidateDirectionKey)
      defaults.removeObject(forKey: candidateFixCountKey)
      defaults.removeObject(forKey: candidateStartedAtKey)
      clearCandidateEvidence()
      startContinuousMonitoring(highAccuracy: false)
      return
    }
    let previousDirection = effectiveDirection()
    // The accurate polygon result is authoritative. The optional gate region
    // remains a low-latency wake-up hint, but sparse background fixes are not
    // required to intersect its short segment. Requiring that intersection
    // discarded real exits when iOS delivered its fix beyond the gate.
    guard previousDirection != direction else {
      defaults.removeObject(forKey: candidateDirectionKey)
      defaults.removeObject(forKey: candidateFixCountKey)
      defaults.removeObject(forKey: candidateStartedAtKey)
      clearCandidateEvidence()
      startContinuousMonitoring(highAccuracy: false)
      return
    }
    let previousCandidate = defaults.string(forKey: candidateDirectionKey)
    let newCandidate = previousCandidate != direction
    let lastCandidateFixAt = defaults.double(forKey: candidateLastFixAtKey)
    let sufficientlySeparated = location.timestamp.timeIntervalSince1970 - lastCandidateFixAt >= 8
    let candidateCount: Int
    if !newCandidate && sufficientlySeparated {
      candidateCount = defaults.integer(forKey: candidateFixCountKey) + 1
    } else if !newCandidate {
      candidateCount = max(defaults.integer(forKey: candidateFixCountKey), 1)
    } else {
      candidateCount = 1
    }
    let candidateMoving = (!newCandidate && defaults.bool(forKey: candidateMovingKey)) || location.speed >= 0.5
    defaults.set(direction, forKey: candidateDirectionKey)
    defaults.set(candidateCount, forKey: candidateFixCountKey)
    defaults.set(candidateMoving, forKey: candidateMovingKey)
    if newCandidate {
      defaults.set(Date().timeIntervalSince1970, forKey: candidateStartedAtKey)
      let origin = previousLocation ?? location
      defaults.set(origin.coordinate.latitude, forKey: candidateOriginLatKey)
      defaults.set(origin.coordinate.longitude, forKey: candidateOriginLngKey)
    }
    if newCandidate || sufficientlySeparated {
      defaults.set(location.timestamp.timeIntervalSince1970, forKey: candidateLastFixAtKey)
    }
    startContinuousMonitoring(highAccuracy: true)
    // Two consecutive accurate fixes prevent a transient GPS jump from
    // rewriting state during post-force-stop reconciliation.
    guard candidateCount >= 2 else { return }
    guard direction != "OUT" || candidateMoving || candidateCrossesGate(to: location) else { return }
    defaults.removeObject(forKey: candidateDirectionKey)
    defaults.removeObject(forKey: candidateFixCountKey)
    defaults.removeObject(forKey: candidateStartedAtKey)
    clearCandidateEvidence()
    append(direction: direction)
    startContinuousMonitoring(highAccuracy: false)
  }

  private func startContinuousMonitoring(highAccuracy: Bool = false) {
    guard defaults.bool(forKey: registeredKey) else { return }
    manager.desiredAccuracy = highAccuracy
      ? kCLLocationAccuracyBest : kCLLocationAccuracyNearestTenMeters
    manager.distanceFilter = highAccuracy ? kCLDistanceFilterNone : 15
    manager.pausesLocationUpdatesAutomatically = !highAccuracy
    manager.startUpdatingLocation()
  }

  private func expireCandidateIfNeeded() {
    guard defaults.integer(forKey: candidateFixCountKey) > 0 else { return }
    let startedAt = defaults.double(forKey: candidateStartedAtKey)
    guard startedAt == 0 || Date().timeIntervalSince1970 - startedAt > 120 else { return }
    defaults.removeObject(forKey: candidateDirectionKey)
    defaults.removeObject(forKey: candidateFixCountKey)
    defaults.removeObject(forKey: candidateStartedAtKey)
    clearCandidateEvidence()
    startContinuousMonitoring(highAccuracy: false)
  }

  // ─── Fine-accuracy location burst ─────────────────────────────────────────

  private func startLocationBurst() {
    guard defaults.bool(forKey: registeredKey) else { return }
    // Always start a fine-accuracy burst whenever the coarse CLCircularRegion
    // fires — we need an accurate fix to confirm direction via polygon
    // evaluation, regardless of whether the virtual gate line is configured.
    burstTimeout?.cancel()
    burstActive = true

    if burstBackgroundTask != .invalid {
      UIApplication.shared.endBackgroundTask(burstBackgroundTask)
      burstBackgroundTask = .invalid
    }
    burstBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "CarmeLinkLocationBurst") { [weak self] in
      self?.stopLocationBurst()
    }

    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = 3
    manager.startUpdatingLocation()

    let timeout = DispatchWorkItem { [weak self] in self?.stopLocationBurst() }
    burstTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 120, execute: timeout)
  }

  private func stopLocationBurst() {
    burstTimeout?.cancel()
    burstTimeout = nil
    burstActive = false
    if defaults.bool(forKey: registeredKey) {
      startContinuousMonitoring(highAccuracy: false)
    } else {
      manager.stopUpdatingLocation()
      manager.distanceFilter = kCLDistanceFilterNone
    }
    if burstBackgroundTask != .invalid {
      UIApplication.shared.endBackgroundTask(burstBackgroundTask)
      burstBackgroundTask = .invalid
    }
  }

  // ─── Geometry helpers ─────────────────────────────────────────────────────

  private struct Point { let lat: Double; let lng: Double }

  private func polygon() -> [Point] {
    (defaults.array(forKey: "tripwire_polygon") as? [[String: Double]] ?? []).compactMap {
      guard let lat = $0["lat"], let lng = $0["lng"] else { return nil }
      return Point(lat: lat, lng: lng)
    }
  }

  /// Evaluates whether [location] is inside the dormitory polygon using the
  /// even-odd ray-casting rule, with edge-buffer hysteresis.
  ///
  /// Returns the crossing direction ("IN"/"OUT"), or nil if the polygon is
  /// too small or unavailable.
  ///
  /// NOTE: This is intentionally gate-agnostic. The polygon check is the
  /// primary boundary test on iOS and runs for every accurate GPS fix.
  private func verifiedDirection(for location: CLLocation) -> String? {
    let points = polygon()
    guard points.count >= 3 else { return nil }
    let p = Point(lat: location.coordinate.latitude, lng: location.coordinate.longitude)
    var inside = false; var j = points.count - 1
    for i in points.indices {
      let a = points[i], b = points[j]
      if (a.lat > p.lat) != (b.lat > p.lat) &&
          p.lng < (b.lng - a.lng) * (p.lat - a.lat) / (b.lat - a.lat) + a.lng { inside.toggle() }
      j = i
    }
    let edgeDistance = points.indices.map {
      pointSegmentDistance(p, points[$0], points[($0 + 1) % points.count])
    }.min() ?? .greatestFiniteMagnitude
    // Hysteresis: if we're within the edge buffer, keep the last known direction.
    if edgeDistance <= max(defaults.double(forKey: "tripwire_edge_buffer"), 8),
       let previous = effectiveDirection() { return previous }
    return inside ? "IN" : "OUT"
  }

  private func xy(_ p: Point, _ origin: Point) -> (Double, Double) {
    let radius = 6_371_000.0
    return ((p.lng - origin.lng) * .pi / 180 * radius * cos(origin.lat * .pi / 180),
            (p.lat - origin.lat) * .pi / 180 * radius)
  }

  private func pointSegmentDistance(_ p: Point, _ a: Point, _ b: Point) -> Double {
    let q = xy(p, a), e = xy(b, a), length = e.0 * e.0 + e.1 * e.1
    let t = length == 0 ? 0 : max(0, min(1, (q.0 * e.0 + q.1 * e.1) / length))
    return hypot(q.0 - t * e.0, q.1 - t * e.1)
  }

  private func clearCandidateEvidence() {
    defaults.removeObject(forKey: candidateLastFixAtKey)
    defaults.removeObject(forKey: candidateOriginLatKey)
    defaults.removeObject(forKey: candidateOriginLngKey)
    defaults.removeObject(forKey: candidateMovingKey)
  }

  private func candidateCrossesGate(to location: CLLocation) -> Bool {
    guard defaults.bool(forKey: "tripwire_gate_enabled"),
          defaults.object(forKey: candidateOriginLatKey) != nil,
          defaults.object(forKey: candidateOriginLngKey) != nil else { return false }
    let origin = Point(
      lat: defaults.double(forKey: candidateOriginLatKey),
      lng: defaults.double(forKey: candidateOriginLngKey)
    )
    let current = Point(lat: location.coordinate.latitude, lng: location.coordinate.longitude)
    let gateStart = Point(
      lat: defaults.double(forKey: "tripwire_gate_start_lat"),
      lng: defaults.double(forKey: "tripwire_gate_start_lng")
    )
    let gateEnd = Point(
      lat: defaults.double(forKey: "tripwire_gate_end_lat"),
      lng: defaults.double(forKey: "tripwire_gate_end_lng")
    )
    return segmentDistance(origin, current, gateStart, gateEnd) <=
      max(defaults.double(forKey: "tripwire_gate_tolerance"), 8)
  }

  private func segmentDistance(_ a: Point, _ b: Point, _ c: Point, _ d: Point) -> Double {
    let aa = xy(a, a), bb = xy(b, a), cc = xy(c, a), dd = xy(d, a)
    func cross(_ p: (Double, Double), _ q: (Double, Double), _ r: (Double, Double)) -> Double {
      (q.0-p.0)*(r.1-p.1) - (q.1-p.1)*(r.0-p.0)
    }
    if cross(aa,bb,cc) * cross(aa,bb,dd) <= 0 &&
       cross(cc,dd,aa) * cross(cc,dd,bb) <= 0 { return 0 }
    return min(pointSegmentDistance(a,c,d), pointSegmentDistance(b,c,d),
               pointSegmentDistance(c,a,b), pointSegmentDistance(d,a,b))
  }

  // ─── CLLocationManagerDelegate — auth & errors ────────────────────────────

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus
    if status == .authorizedAlways || status == .authorizedWhenInUse {
      restoreIfNeeded()
    } else if status == .denied || status == .restricted {
      reportMonitoringHealth(available: false, reason: "LOCATION_PERMISSION_DENIED")
      stopLocationBurst()
    }
  }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    if status == .authorizedAlways || status == .authorizedWhenInUse {
      restoreIfNeeded()
    } else if status == .denied || status == .restricted {
      reportMonitoringHealth(available: false, reason: "LOCATION_PERMISSION_DENIED")
      stopLocationBurst()
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    // Permission denial, disabled Location Services, and temporary position
    // failures are recoverable states. Do not let them destabilize the app.
    NSLog("CarmeLink location update failed: %@", error.localizedDescription)
    evaluateMonitoringHealth()
    stopLocationBurst()
  }

  private func evaluateMonitoringHealth() {
    if !CLLocationManager.locationServicesEnabled() {
      reportMonitoringHealth(available: false, reason: "LOCATION_SERVICES_DISABLED")
    } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
      reportMonitoringHealth(available: false, reason: "LOCATION_PERMISSION_DENIED")
    } else if manager.authorizationStatus != .authorizedAlways {
      reportMonitoringHealth(available: false, reason: "BACKGROUND_LOCATION_DENIED")
    } else {
      reportMonitoringHealth(available: true, reason: nil)
    }
  }

  private func reportMonitoringHealth(available: Bool, reason: String?) {
    let previous = defaults.object(forKey: monitoringAvailableKey) as? Bool
    let previousReason = defaults.string(forKey: monitoringReasonKey)
    guard previous != available || previousReason != reason else { return }
    defaults.set(available, forKey: monitoringAvailableKey)
    if let reason { defaults.set(reason, forKey: monitoringReasonKey) }
    else { defaults.removeObject(forKey: monitoringReasonKey) }

    if !available { showLocationDisabledReminder(reason: reason) }
    else {
      // Reset the cooldown so a new off/on/off cycle alerts immediately.
      defaults.removeObject(forKey: "tripwire_last_location_reminder_at")
      UNUserNotificationCenter.current().removePendingNotificationRequests(
        withIdentifiers: ["carmelink_location_monitoring_off_repeat"]
      )
      UNUserNotificationCenter.current().removeDeliveredNotifications(
        withIdentifiers: ["carmelink_location_monitoring_off"]
      )
    }
    var healthBody: [String: Any] = ["p_available": available, "p_platform": "ios"]
    if let reason { healthBody["p_reason"] = reason }
    post(
      path: "/rest/v1/rpc/set_my_location_monitoring_health",
      body: healthBody
    ) { _, _, _ in }
  }

  private func showLocationDisabledReminder(reason: String?) {
    let last = defaults.double(forKey: "tripwire_last_location_reminder_at")
    guard Date().timeIntervalSince1970 - last >= 3600 else { return }
    defaults.set(Date().timeIntervalSince1970, forKey: "tripwire_last_location_reminder_at")
    let content = UNMutableNotificationContent()
    content.title = "Location monitoring is off"
    content.body = reason == "BACKGROUND_LOCATION_DENIED"
      ? "Allow Location Always in Settings to restore dormitory entry and exit alerts."
      : "Turn on Location in Settings to restore dormitory entry and exit alerts."
    content.sound = .default
    content.userInfo = ["route_type": "location_settings"]
    UNUserNotificationCenter.current().add(UNNotificationRequest(
      identifier: "carmelink_location_monitoring_off", content: content, trigger: nil
    ))
    UNUserNotificationCenter.current().add(UNNotificationRequest(
      identifier: "carmelink_location_monitoring_off_repeat", content: content,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: true)
    ))
  }

  func locationManager(
    _ manager: CLLocationManager,
    monitoringDidFailFor region: CLRegion?,
    withError error: Error
  ) {
    NSLog(
      "CarmeLink region monitoring failed for %@: %@",
      region?.identifier ?? "unknown",
      error.localizedDescription
    )
  }

  // ─── Event queue ──────────────────────────────────────────────────────────

  private func append(direction: String) {
    guard let tenantId = defaults.string(forKey: "tripwire_tenant_id") else { return }
    let previous = effectiveDirection()
    guard previous != direction else { return }
    var events = pendingEventsRaw()
    events.append([
      "event_id": UUID().uuidString,
      "tenant_id": tenantId,
      "direction": direction,
      "observed_at": Int(Date().timeIntervalSince1970 * 1000),
      "platform": "ios",
    ])
    if events.count > 24 { events = Array(events.suffix(24)) }
    defaults.set(events, forKey: queueKey)
    defaults.set(direction, forKey: queuedDirectionKey)
    showCrossingNotification(direction: direction)
    syncPendingEvents()
  }

  private func showCrossingNotification(direction: String) {
    let center = UNUserNotificationCenter.current()
    let content = UNMutableNotificationContent()
    let isEntry = direction == "IN"
    content.title = isEntry ? "🏠 Entered dormitory" : "🚪 Left dormitory"
    content.body = isEntry ? "Your entry was detected. Welcome home!" : "Your departure was detected. Stay safe!"
    content.sound = .default
    content.userInfo = ["route_type": "gate", "direction": direction]

    let request = UNNotificationRequest(
      identifier: isEntry ? "carmelink_entry" : "carmelink_exit",
      content: content,
      trigger: nil
    )
    center.add(request, withCompletionHandler: nil)
  }

  private func pendingEventsRaw() -> [[String: Any]] {
    defaults.array(forKey: queueKey) as? [[String: Any]] ?? []
  }

  private func effectiveDirection() -> String? {
    defaults.string(forKey: queuedDirectionKey) ??
      defaults.string(forKey: confirmedDirectionKey)
  }

  private func persist(events: [[String: Any]]) {
    defaults.set(events, forKey: queueKey)
    if let direction = events.last?["direction"] as? String {
      defaults.set(direction, forKey: queuedDirectionKey)
    } else {
      defaults.removeObject(forKey: queuedDirectionKey)
    }
  }

  /// Uploads queued crossings while iOS keeps the app alive after a region
  /// callback. Flutter also drains the same idempotent queue on next resume.
  private func syncPendingEvents() {
    DispatchQueue.main.async { [weak self] in self?.beginSyncIfNeeded() }
  }

  private func beginSyncIfNeeded() {
    guard !syncing, !pendingEvents().isEmpty else { return }
    guard
      !(defaults.string(forKey: "tripwire_supabase_url") ?? "").isEmpty,
      !(defaults.string(forKey: "tripwire_publishable_key") ?? "").isEmpty,
      !(defaults.string(forKey: "tripwire_access_token") ?? "").isEmpty
    else { return }
    syncing = true
    backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "CarmeLinkTripwireSync") { [weak self] in
      self?.finishSync()
    }
    uploadNextEvent()
  }

  private func uploadNextEvent() {
    let events = pendingEvents()
    guard let event = events.first else {
      persist(events: [])
      finishSync()
      return
    }
    upload(event: event, allowTokenRefresh: true)
  }

  private func upload(event: [String: Any], allowTokenRefresh: Bool) {
    guard
      let direction = event["direction"] as? String,
      let eventId = event["event_id"] as? String,
      let observedAt = event["observed_at"] as? Int
    else {
      persist(events: pendingEventsRaw().filter { ($0["event_id"] as? String) != (event["event_id"] as? String) })
      uploadNextEvent()
      return
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let body: [String: Any] = [
      "p_direction": direction,
      "p_observed_at": formatter.string(from: Date(timeIntervalSince1970: Double(observedAt) / 1000)),
      "p_client_event_id": eventId,
    ]
    post(path: "/rest/v1/rpc/record_tenant_geofence_transition", body: body) { [weak self] code, data, error in
      guard let self else { return }
      if code == 401 && allowTokenRefresh {
        self.refreshSession { refreshed in
          if refreshed { self.upload(event: event, allowTokenRefresh: false) }
          else { self.failSync("Authentication refresh failed while syncing gate event.") }
        }
        return
      }
      guard error == nil, (200...299).contains(code) else {
        let details = data.flatMap { String(data: $0, encoding: .utf8) } ?? error?.localizedDescription ?? "Unknown error"
        self.failSync("Gate event sync failed (\(code)): \(details.prefix(500))")
        return
      }

      self.defaults.set(direction, forKey: self.confirmedDirectionKey)
      self.defaults.set(Date().timeIntervalSince1970 * 1000, forKey: "tripwire_last_synced_at")
      self.defaults.removeObject(forKey: "tripwire_last_sync_error")
      self.persist(events: self.pendingEventsRaw().filter { ($0["event_id"] as? String) != eventId })

      let responseText = data.flatMap { String(data: $0, encoding: .utf8) }
      let storedEventId = responseText?.trimmingCharacters(
        in: CharacterSet(charactersIn: "\"\n\r ")
      )
      if let storedEventId, !storedEventId.isEmpty {
        self.post(
          path: "/functions/v1/notify-geofence",
          body: ["event_id": storedEventId]
        ) { code, data, error in
          if error != nil || !(200...299).contains(code) {
            let details = data.flatMap { String(data: $0, encoding: .utf8) } ??
              error?.localizedDescription ?? "Unknown error"
            self.defaults.set(
              "Notification delivery failed (\(code)): \(details.prefix(300))",
              forKey: "tripwire_last_notification_error"
            )
          } else {
            self.defaults.removeObject(forKey: "tripwire_last_notification_error")
          }
          self.uploadNextEvent()
        }
      } else {
        self.uploadNextEvent()
      }
    }
  }

  private func refreshSession(completion: @escaping (Bool) -> Void) {
    guard let refreshToken = defaults.string(forKey: "tripwire_refresh_token"), !refreshToken.isEmpty else {
      completion(false)
      return
    }
    post(
      path: "/auth/v1/token?grant_type=refresh_token",
      body: ["refresh_token": refreshToken],
      includeAuthorization: false
    ) { [weak self] code, data, _ in
      guard let self, (200...299).contains(code), let data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let access = json["access_token"] as? String, !access.isEmpty else {
        completion(false)
        return
      }
      self.defaults.set(access, forKey: "tripwire_access_token")
      if let refresh = json["refresh_token"] as? String, !refresh.isEmpty {
        self.defaults.set(refresh, forKey: "tripwire_refresh_token")
      }
      completion(true)
    }
  }

  private func post(
    path: String,
    body: [String: Any],
    includeAuthorization: Bool = true,
    completion: @escaping (Int, Data?, Error?) -> Void
  ) {
    guard
      let base = defaults.string(forKey: "tripwire_supabase_url"),
      let url = URL(string: base + path),
      let apiKey = defaults.string(forKey: "tripwire_publishable_key"),
      let payload = try? JSONSerialization.data(withJSONObject: body)
    else {
      completion(0, nil, NSError(domain: "CarmeLinkTripwire", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid sync configuration."]))
      return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = payload
    request.timeoutInterval = 15
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "apikey")
    if includeAuthorization, let token = defaults.string(forKey: "tripwire_access_token") {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    URLSession.shared.dataTask(with: request) { data, response, error in
      completion((response as? HTTPURLResponse)?.statusCode ?? 0, data, error)
    }.resume()
  }

  private func failSync(_ message: String) {
    defaults.set(message, forKey: "tripwire_last_sync_error")
    finishSync()
  }

  private func finishSync() {
    guard Thread.isMainThread else {
      DispatchQueue.main.async { [weak self] in self?.finishSync() }
      return
    }
    syncing = false
    if backgroundTask != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundTask)
      backgroundTask = .invalid
    }
  }

  func pendingEvents() -> [[String: Any]] {
    let cutoff = Int(Date().addingTimeInterval(-24 * 60 * 60).timeIntervalSince1970 * 1000)
    return pendingEventsRaw().filter { ($0["observed_at"] as? Int ?? 0) >= cutoff }
  }

  func acknowledge(eventId: String) {
    let events = pendingEventsRaw()
    let acknowledged = events.first { ($0["event_id"] as? String) == eventId }
    let remaining = events.filter { ($0["event_id"] as? String) != eventId }
    if let direction = acknowledged?["direction"] as? String {
      defaults.set(direction, forKey: confirmedDirectionKey)
    }
    persist(events: remaining)
  }

  func status() -> [String: Any] {
    [
      "registered": defaults.bool(forKey: registeredKey),
      "gateEnabled": defaults.bool(forKey: "tripwire_gate_enabled"),
      "configVersion": defaults.integer(forKey: "tripwire_config_version"),
      "direction": defaults.string(forKey: confirmedDirectionKey) ?? NSNull(),
      "pendingDirection": defaults.string(forKey: queuedDirectionKey) ?? NSNull(),
      "candidateDirection": defaults.string(forKey: candidateDirectionKey) ?? NSNull(),
      "candidateFixCount": defaults.integer(forKey: candidateFixCountKey),
      "pendingCount": pendingEvents().count,
      "lastSyncError": defaults.string(forKey: "tripwire_last_sync_error") ?? NSNull(),
      "lastNotificationError": defaults.string(forKey: "tripwire_last_notification_error") ?? NSNull(),
      "lastSyncedAt": defaults.object(forKey: "tripwire_last_synced_at") ?? NSNull(),
      "authorization": manager.authorizationStatus.rawValue,
    ]
  }
}

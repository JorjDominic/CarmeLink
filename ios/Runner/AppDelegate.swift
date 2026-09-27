import Flutter
import CoreLocation
import UIKit

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
        configVersion: args["configVersion"] as? Int ?? 1
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
  private var burstTimeout: DispatchWorkItem?
  private var burstActive = false

  private override init() {
    super.init()
    manager.delegate = self
    manager.pausesLocationUpdatesAutomatically = false
    manager.allowsBackgroundLocationUpdates = true
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
    configVersion: Int
  ) {
    let previousTenant = defaults.string(forKey: "tripwire_tenant_id")
    if previousTenant != tenantId {
      defaults.removeObject(forKey: queueKey)
      defaults.removeObject(forKey: "tripwire_confirmed_direction")
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
    if let value = gateStartLatitude { defaults.set(value, forKey: "tripwire_gate_start_lat") }
    if let value = gateStartLongitude { defaults.set(value, forKey: "tripwire_gate_start_lng") }
    if let value = gateEndLatitude { defaults.set(value, forKey: "tripwire_gate_end_lat") }
    if let value = gateEndLongitude { defaults.set(value, forKey: "tripwire_gate_end_lng") }
    if initialDirection == "IN" || initialDirection == "OUT" {
      defaults.set(initialDirection, forKey: "tripwire_confirmed_direction")
    }

    // Flutter owns the user-facing permission flow. Starting native region
    // monitoring before iOS finishes the Always-authorization upgrade can
    // produce failures immediately after the permission sheet closes.
    if manager.authorizationStatus == .authorizedAlways {
      startMonitoring(latitude: latitude, longitude: longitude, radius: radius)
    }
  }

  func restoreIfNeeded() {
    guard defaults.bool(forKey: registeredKey),
          manager.authorizationStatus == .authorizedAlways else { return }
    startMonitoring(
      latitude: defaults.double(forKey: "tripwire_latitude"),
      longitude: defaults.double(forKey: "tripwire_longitude"),
      radius: defaults.double(forKey: "tripwire_radius")
    )
  }

  private func startMonitoring(latitude: Double, longitude: Double, radius: Double) {
    guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
    for region in manager.monitoredRegions where region.identifier == regionIdentifier || region.identifier == gateRegionIdentifier {
      manager.stopMonitoring(for: region)
    }
    let effectiveRadius = min(max(radius, 25), manager.maximumRegionMonitoringDistance)
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

    if defaults.string(forKey: "tripwire_confirmed_direction") == nil {
      manager.requestState(for: region)
    }
  }

  func unregister() {
    stopLocationBurst()
    for region in manager.monitoredRegions where region.identifier == regionIdentifier || region.identifier == gateRegionIdentifier {
      manager.stopMonitoring(for: region)
    }
    manager.stopMonitoringSignificantLocationChanges()
    for key in [
      queueKey, registeredKey, "tripwire_tenant_id", "tripwire_latitude",
      "tripwire_longitude", "tripwire_radius", "tripwire_confirmed_direction",
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
      defaults.string(forKey: "tripwire_confirmed_direction") == nil
    else { return }
    if state == .inside {
      defaults.set("IN", forKey: "tripwire_confirmed_direction")
    } else if state == .outside {
      defaults.set("OUT", forKey: "tripwire_confirmed_direction")
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
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
    if defaults.string(forKey: "tripwire_confirmed_direction") == nil {
      // The first significant-location callback establishes state; it is not
      // evidence that a crossing occurred after monitoring began.
      defaults.set(direction, forKey: "tripwire_confirmed_direction")
      return
    }
    let previousDirection = defaults.string(forKey: "tripwire_confirmed_direction")
    guard previousDirection != direction, let previousLocation = previousLocation,
          movementCrossesGate(from: previousLocation, to: location) else { return }
    append(direction: direction)
    stopLocationBurst()
  }

  private func startLocationBurst() {
    guard defaults.bool(forKey: registeredKey),
          defaults.bool(forKey: "tripwire_gate_enabled") else { return }
    burstTimeout?.cancel()
    burstActive = true
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
    if burstActive { manager.stopUpdatingLocation() }
    burstActive = false
    manager.distanceFilter = kCLDistanceFilterNone
  }

  private struct Point { let lat: Double; let lng: Double }

  private func polygon() -> [Point] {
    (defaults.array(forKey: "tripwire_polygon") as? [[String: Double]] ?? []).compactMap {
      guard let lat = $0["lat"], let lng = $0["lng"] else { return nil }
      return Point(lat: lat, lng: lng)
    }
  }

  private func verifiedDirection(for location: CLLocation) -> String? {
    guard defaults.bool(forKey: "tripwire_gate_enabled") else { return nil }
    let points = polygon(); guard points.count >= 3 else { return nil }
    let p = Point(lat: location.coordinate.latitude, lng: location.coordinate.longitude)
    var inside = false; var j = points.count - 1
    for i in points.indices {
      let a = points[i], b = points[j]
      if (a.lat > p.lat) != (b.lat > p.lat) &&
          p.lng < (b.lng - a.lng) * (p.lat - a.lat) / (b.lat - a.lat) + a.lng { inside.toggle() }
      j = i
    }
    let edgeDistance = points.indices.map { pointSegmentDistance(p, points[$0], points[($0 + 1) % points.count]) }.min() ?? .greatestFiniteMagnitude
    if edgeDistance <= defaults.double(forKey: "tripwire_edge_buffer"),
       let previous = defaults.string(forKey: "tripwire_confirmed_direction") { return previous }
    return inside ? "IN" : "OUT"
  }

  private func movementCrossesGate(from: CLLocation, to: CLLocation) -> Bool {
    guard defaults.bool(forKey: "tripwire_gate_enabled") else { return false }
    let start = Point(lat: defaults.double(forKey: "tripwire_gate_start_lat"), lng: defaults.double(forKey: "tripwire_gate_start_lng"))
    let end = Point(lat: defaults.double(forKey: "tripwire_gate_end_lat"), lng: defaults.double(forKey: "tripwire_gate_end_lng"))
    let a = Point(lat: from.coordinate.latitude, lng: from.coordinate.longitude)
    let b = Point(lat: to.coordinate.latitude, lng: to.coordinate.longitude)
    return segmentDistance(a, b, start, end) <= defaults.double(forKey: "tripwire_gate_tolerance")
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

  private func segmentDistance(_ a: Point, _ b: Point, _ c: Point, _ d: Point) -> Double {
    // Gate corridors are deliberately tolerant; endpoint-to-segment distance
    // plus the intersection test covers sparse background fixes.
    let aa = xy(a, a), bb = xy(b, a), cc = xy(c, a), dd = xy(d, a)
    func cross(_ p: (Double, Double), _ q: (Double, Double), _ r: (Double, Double)) -> Double {
      (q.0-p.0)*(r.1-p.1) - (q.1-p.1)*(r.0-p.0)
    }
    if cross(aa,bb,cc) * cross(aa,bb,dd) <= 0 && cross(cc,dd,aa) * cross(cc,dd,bb) <= 0 { return 0 }
    return min(pointSegmentDistance(a,c,d), pointSegmentDistance(b,c,d),
               pointSegmentDistance(c,a,b), pointSegmentDistance(d,a,b))
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if manager.authorizationStatus == .authorizedAlways {
      restoreIfNeeded()
    } else if manager.authorizationStatus == .denied ||
                manager.authorizationStatus == .restricted {
      stopLocationBurst()
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    // Permission denial, disabled Location Services, and temporary position
    // failures are recoverable states. Do not let them destabilize the app.
    NSLog("CarmeLink location update failed: %@", error.localizedDescription)
    stopLocationBurst()
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

  private func append(direction: String) {
    guard let tenantId = defaults.string(forKey: "tripwire_tenant_id") else { return }
    let previous = defaults.string(forKey: "tripwire_confirmed_direction")
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
    defaults.set(direction, forKey: "tripwire_confirmed_direction")
  }

  private func pendingEventsRaw() -> [[String: Any]] {
    defaults.array(forKey: queueKey) as? [[String: Any]] ?? []
  }

  func pendingEvents() -> [[String: Any]] {
    let cutoff = Int(Date().addingTimeInterval(-24 * 60 * 60).timeIntervalSince1970 * 1000)
    return pendingEventsRaw().filter { ($0["observed_at"] as? Int ?? 0) >= cutoff }
  }

  func acknowledge(eventId: String) {
    defaults.set(
      pendingEventsRaw().filter { ($0["event_id"] as? String) != eventId },
      forKey: queueKey
    )
  }

  func status() -> [String: Any] {
    [
      "registered": defaults.bool(forKey: registeredKey),
      "gateEnabled": defaults.bool(forKey: "tripwire_gate_enabled"),
      "configVersion": defaults.integer(forKey: "tripwire_config_version"),
      "direction": defaults.string(forKey: "tripwire_confirmed_direction") as Any,
      "pendingCount": pendingEvents().count,
      "authorization": manager.authorizationStatus.rawValue,
    ]
  }
}

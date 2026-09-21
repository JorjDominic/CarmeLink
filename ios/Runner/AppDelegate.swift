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
        initialDirection: args["initialDirection"] as? String
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
  private let queueKey = "tripwire_pending_events"
  private let registeredKey = "tripwire_registered"

  private override init() {
    super.init()
    manager.delegate = self
  }

  func register(
    latitude: Double,
    longitude: Double,
    radius: Double,
    tenantId: String,
    initialDirection: String?
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
    if initialDirection == "IN" || initialDirection == "OUT" {
      defaults.set(initialDirection, forKey: "tripwire_confirmed_direction")
    }

    manager.requestAlwaysAuthorization()
    startMonitoring(latitude: latitude, longitude: longitude, radius: radius)
  }

  func restoreIfNeeded() {
    guard defaults.bool(forKey: registeredKey) else { return }
    startMonitoring(
      latitude: defaults.double(forKey: "tripwire_latitude"),
      longitude: defaults.double(forKey: "tripwire_longitude"),
      radius: defaults.double(forKey: "tripwire_radius")
    )
  }

  private func startMonitoring(latitude: Double, longitude: Double, radius: Double) {
    guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
    for region in manager.monitoredRegions where region.identifier == regionIdentifier {
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
    manager.startMonitoringSignificantLocationChanges()

    if defaults.string(forKey: "tripwire_confirmed_direction") == nil {
      manager.requestState(for: region)
    }
  }

  func unregister() {
    for region in manager.monitoredRegions where region.identifier == regionIdentifier {
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
    guard region.identifier == regionIdentifier else { return }
    append(direction: "IN")
  }

  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    guard region.identifier == regionIdentifier else { return }
    append(direction: "OUT")
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
    let center = CLLocation(
      latitude: defaults.double(forKey: "tripwire_latitude"),
      longitude: defaults.double(forKey: "tripwire_longitude")
    )
    let radius = defaults.double(forKey: "tripwire_radius")
    let direction = location.distance(from: center) <= radius ? "IN" : "OUT"
    if defaults.string(forKey: "tripwire_confirmed_direction") == nil {
      // The first significant-location callback establishes state; it is not
      // evidence that a crossing occurred after monitoring began.
      defaults.set(direction, forKey: "tripwire_confirmed_direction")
      return
    }
    append(direction: direction)
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if manager.authorizationStatus == .authorizedAlways {
      restoreIfNeeded()
    }
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
      "direction": defaults.string(forKey: "tripwire_confirmed_direction") as Any,
      "pendingCount": pendingEvents().count,
      "authorization": manager.authorizationStatus.rawValue,
    ]
  }
}

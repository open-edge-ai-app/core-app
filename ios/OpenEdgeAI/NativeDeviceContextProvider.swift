import Foundation
import CoreLocation

final class NativeDeviceContextProvider: NSObject, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private var lastLocation: CLLocation?

  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    locationManager.distanceFilter = 500
  }

  func refreshLocationIfAuthorized() {
    guard CLLocationManager.locationServicesEnabled() else {
      return
    }

    switch locationManager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      locationManager.requestLocation()
    case .denied, .restricted, .notDetermined:
      break
    @unknown default:
      break
    }
  }

  func locationContextLines(now: Date) -> [String] {
    guard CLLocationManager.locationServicesEnabled() else {
      return ["Location services: disabled"]
    }

    switch locationManager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      guard let location = lastLocation else {
        return ["Location: permission granted, waiting for device location"]
      }

      let age = max(0, now.timeIntervalSince(location.timestamp))
      var parts = [
        String(format: "latitude %.5f", location.coordinate.latitude),
        String(format: "longitude %.5f", location.coordinate.longitude),
        String(format: "accuracy %.0fm", location.horizontalAccuracy),
        String(format: "updated %.0fs ago", age)
      ]

      if location.verticalAccuracy >= 0 {
        parts.append(String(format: "altitude %.0fm", location.altitude))
        parts.append(String(format: "vertical accuracy %.0fm", location.verticalAccuracy))
      }

      return ["Location: \(parts.joined(separator: ", "))"]
    case .denied:
      return ["Location: permission denied"]
    case .restricted:
      return ["Location: restricted by system"]
    case .notDetermined:
      return ["Location: permission not requested"]
    @unknown default:
      return ["Location: authorization unknown"]
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    lastLocation = locations.last
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

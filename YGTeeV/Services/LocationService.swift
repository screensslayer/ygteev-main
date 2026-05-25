//
//  LocationService.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/11/26.
//

import Foundation
import CoreLocation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()
    private let manager = CLLocationManager()

    var coordinate: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var lastError: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 200   // meters
        authorizationStatus = manager.authorizationStatus
    }

    func requestAuthorizationAndStart() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ mgr: CLLocationManager) {
        authorizationStatus = mgr.authorizationStatus
        if mgr.authorizationStatus == .authorizedWhenInUse
        || mgr.authorizationStatus == .authorizedAlways {
            mgr.startUpdatingLocation()
        }
    }

    func locationManager(_ mgr: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.last else { return }
        coordinate = loc.coordinate
    }

    func locationManager(_ mgr: CLLocationManager, didFailWithError error: Error) {
        lastError = error.localizedDescription
    }
}

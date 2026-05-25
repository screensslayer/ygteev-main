//
//  Geo.swift
//  YGTeeV
//
//  Best-effort forward geocoding for event creation/edit. CLGeocoder
//  can hang on a degraded network so every call is wrapped in a
//  4-second timeout — callers treat `nil` as "couldn't resolve,
//  submit without coords" and never surface an error to the user.
//

import Foundation
import CoreLocation

enum Geo {
    /// Forward-geocode an address string with a hard 4-second timeout.
    /// Returns nil on empty/whitespace input, network failure, zero
    /// matches, or timeout. Never throws.
    static func geocode(_ address: String?) async -> (lat: Double, lng: Double)? {
        let trimmed = address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }

        let geocoder = CLGeocoder()
        return await withTaskGroup(of: (Double, Double)?.self) { group in
            group.addTask {
                do {
                    let placemarks = try await geocoder.geocodeAddressString(trimmed)
                    if let loc = placemarks.first?.location {
                        return (loc.coordinate.latitude, loc.coordinate.longitude)
                    }
                } catch {
                    // Silent fallback — network failure, no results, etc.
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result.map { (lat: $0.0, lng: $0.1) }
        }
    }
}

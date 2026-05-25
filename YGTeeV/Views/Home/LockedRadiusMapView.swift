//
//  LockedRadiusMapView.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/11/26.
//

import SwiftUI
import MapKit

/// SwiftUI Map constrained to a 25-mile circle around the signed-in user.
/// The user can pinch-zoom and pan freely, but `mapCameraBounds(_:)`
/// prevents zooming out past the circle's bounding rect or panning so far
/// that the camera center leaves it. The boundary is drawn as a faint
/// purple ring so the constraint is visible, not mysterious.
struct LockedRadiusMapView: View {
    let userCoordinate: CLLocationCoordinate2D
    let pins: [YouthGroupMapPin]
    let onPinTap: (YouthGroupMapPin) -> Void
    /// Fires when the user finishes a pan/zoom gesture. Caller decides
    /// what to do with the region — typically debounce + re-query
    /// nearby groups + events from the new center.
    var onCameraChange: ((MKCoordinateRegion) -> Void)? = nil

    /// 25 miles in meters.
    private let radiusMeters: CLLocationDistance = 25 * 1609.344

    @State private var cameraPosition: MapCameraPosition = .automatic

    /// Square region (2×radius on a side) that fully contains the 25-mi
    /// circle. Used both for the camera-bounds rect and the initial frame.
    private var boundingRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: userCoordinate,
            latitudinalMeters:  radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )
    }

    private var cameraBounds: MapCameraBounds {
        MapCameraBounds(
            centerCoordinateBounds: MKMapRect(region: boundingRegion),
            // Closest in: ~street level. Furthest out: the circle's
            // diameter plus a small buffer so the whole ring stays
            // comfortably on screen at max zoom-out.
            minimumDistance: 200,
            maximumDistance: radiusMeters * 2.2
        )
    }

    var body: some View {
        // `bounds:` is the Map initializer's camera-bounds parameter — the
        // canonical way to constrain pan/zoom in SwiftUI MapKit. (There is
        // no `.mapCameraBounds(_:)` view modifier.)
        Map(position: $cameraPosition,
            bounds: cameraBounds,
            interactionModes: [.pan, .zoom]) {
            // 25-mile boundary so the user sees what they're locked into.
            MapCircle(center: userCoordinate, radius: radiusMeters)
                .foregroundStyle(YGColors.violet.opacity(0.04))
                .stroke(YGColors.violet.opacity(0.4), lineWidth: 1.5)

            // Youth-group pins.
            ForEach(pins) { pin in
                Annotation(pin.name, coordinate: pin.coordinate) {
                    Button {
                        onPinTap(pin)
                    } label: {
                        GroupMapPin(pin: pin)
                    }
                    .buttonStyle(.plain)
                }
            }

            UserAnnotation()
        }
        // Empty PointOfInterestCategories literal == exclude all POI.
        .mapStyle(.standard(pointsOfInterest: []))
        // `.onEnd` only fires when the pan/zoom gesture settles, so we
        // don't thrash the network mid-drag. Callers debounce further
        // to coalesce the burst that fires when programmatic camera
        // moves chain (e.g. user-location follow → manual pan).
        .onMapCameraChange(frequency: .onEnd) { ctx in
            onCameraChange?(ctx.region)
        }
        .onAppear {
            // Frame the camera so the full 25-mi circle is visible on
            // first present. After this the user is free to pan/zoom
            // within the bounds.
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: userCoordinate,
                    latitudinalMeters:  radiusMeters * 1.8,
                    longitudinalMeters: radiusMeters * 1.8
                )
            )
        }
        .onChange(of: userCoordinate.latitude) { _, _ in recenter() }
        .onChange(of: userCoordinate.longitude) { _, _ in recenter() }
    }

    /// Re-frame the camera if the user's actual location moves enough that
    /// the previous frame is no longer centered. (Bounds recompute via the
    /// `cameraBounds` computed property automatically.)
    private func recenter() {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: userCoordinate,
                latitudinalMeters:  radiusMeters * 1.8,
                longitudinalMeters: radiusMeters * 1.8
            )
        )
    }
}

// MARK: - Group Map Pin (SwiftUI View)

struct GroupMapPin: View {
    let pin: YouthGroupMapPin

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black)
                .frame(width: 56, height: 56)
                .overlay {
                    GroupAvatar(logoUrl: pin.logoUrl, size: 56, cornerRadius: 14) {
                        Text(pin.initials)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.white, lineWidth: 3)
                }
                .shadow(color: .black.opacity(0.25), radius: 8)

            // Tail
            Path { path in
                path.move(to: CGPoint(x: 21, y: 0))
                path.addLine(to: CGPoint(x: 28, y: 0))
                path.addLine(to: CGPoint(x: 24.5, y: 10))
                path.closeSubpath()
            }
            .fill(.white)
            .offset(y: -2)
        }
    }
}

// MARK: - MKCoordinateRegion → MKMapRect

extension MKMapRect {
    /// Bulletproof conversion from a coordinate region to a map rect.
    /// Apple ships a similar initializer in newer SDKs; defining it here
    /// avoids platform-availability concerns and keeps the math obvious.
    init(region: MKCoordinateRegion) {
        let nw = CLLocationCoordinate2D(
            latitude:  region.center.latitude  + region.span.latitudeDelta  / 2,
            longitude: region.center.longitude - region.span.longitudeDelta / 2
        )
        let se = CLLocationCoordinate2D(
            latitude:  region.center.latitude  - region.span.latitudeDelta  / 2,
            longitude: region.center.longitude + region.span.longitudeDelta / 2
        )
        let p1 = MKMapPoint(nw)
        let p2 = MKMapPoint(se)
        self = MKMapRect(
            x: min(p1.x, p2.x),
            y: min(p1.y, p2.y),
            width:  abs(p1.x - p2.x),
            height: abs(p1.y - p2.y)
        )
    }
}

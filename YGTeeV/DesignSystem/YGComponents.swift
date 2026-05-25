//
//  YGComponents.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import SwiftUI
import UIKit
import ObjectiveC

// MARK: - App-wide UITextField placeholder tinting
//
// SwiftUI's `TextField` is backed by `UITextField`. iOS uses a near-invisible
// `placeholderText` system color, so placeholders are too faint on light
// surfaces. We swizzle the two placeholder setters once at launch so every
// UITextField — whether instantiated by SwiftUI or UIKit — automatically
// gets a darker tint without needing per-call `prompt:` overrides.

extension UITextField {
    private static var ygPlaceholderTintColor: UIColor {
        UIColor(YGColors.ink).withAlphaComponent(0.45)
    }

    private static let ygSwizzleOnce: Void = {
        let cls: AnyClass = UITextField.self

        // Swizzle setPlaceholder:
        if let original = class_getInstanceMethod(cls, #selector(setter: UITextField.placeholder)),
           let replacement = class_getInstanceMethod(cls, #selector(UITextField.yg_setPlaceholder(_:))) {
            method_exchangeImplementations(original, replacement)
        }

        // Swizzle setAttributedPlaceholder:
        if let original = class_getInstanceMethod(cls, #selector(setter: UITextField.attributedPlaceholder)),
           let replacement = class_getInstanceMethod(cls, #selector(UITextField.yg_setAttributedPlaceholder(_:))) {
            method_exchangeImplementations(original, replacement)
        }
    }()

    @MainActor static func ygEnablePlaceholderTinting() {
        _ = ygSwizzleOnce
    }

    @objc fileprivate func yg_setPlaceholder(_ newValue: String?) {
        guard let newValue, !newValue.isEmpty else {
            // Calls the original setter (swapped impls).
            self.yg_setPlaceholder(newValue)
            return
        }
        let attr = NSAttributedString(
            string: newValue,
            attributes: [.foregroundColor: UITextField.ygPlaceholderTintColor]
        )
        // Route through the (now-swizzled) attributed setter so the tint sticks.
        self.yg_setAttributedPlaceholder(attr)
    }

    @objc fileprivate func yg_setAttributedPlaceholder(_ newValue: NSAttributedString?) {
        guard let newValue, newValue.length > 0 else {
            self.yg_setAttributedPlaceholder(newValue)
            return
        }
        let mutable = NSMutableAttributedString(attributedString: newValue)
        mutable.addAttribute(
            .foregroundColor,
            value: UITextField.ygPlaceholderTintColor,
            range: NSRange(location: 0, length: mutable.length)
        )
        self.yg_setAttributedPlaceholder(mutable)
    }
}

// MARK: - Avatar Component
struct YGAvatar: View {
    let name: String
    var size: CGFloat = 40
    var showRing: Bool = false
    var imageURL: String? = nil
    
    private var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)) }
            .joined()
            .uppercased()
    }
    
    private var gradientColors: [Color] {
        let hash = abs(name.hashValue)
        let hue1 = Double(hash % 360)
        let hue2 = Double((hash % 307) * 53 % 360)
        return [
            Color(hue: hue1 / 360, saturation: 0.8, brightness: 0.6),
            Color(hue: hue2 / 360, saturation: 0.8, brightness: 0.5)
        ]
    }
    
    var body: some View {
        ZStack {
            if showRing {
                Circle()
                    .fill(YGColors.rainbowRingGradient)
                    .frame(width: size + 6, height: size + 6)
            }
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay {
                    if showRing {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                    }
                }
                .overlay {
                    Text(initials)
                        .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
        }
    }
}

// MARK: - Group Icon Component
struct YGGroupIcon: View {
    let gradient: LinearGradient
    let initials: String
    var size: CGFloat = 56
    var showRing: Bool = false
    
    // Convenience init for YouthGroupMapPin
    init(pin: YouthGroupMapPin, size: CGFloat = 56, showRing: Bool = false) {
        self.gradient = pin.gradient
        self.initials = pin.initials
        self.size = size
        self.showRing = showRing
    }
    
    // Convenience init for YouthGroupPublicProfile
    init(profile: YouthGroupPublicProfile, size: CGFloat = 56, showRing: Bool = false) {
        self.gradient = profile.gradient
        self.initials = profile.initials
        self.size = size
        self.showRing = showRing
    }
    
    // Legacy convenience init for YouthGroup (HomeFeedView compatibility)
    init(group: YouthGroup, size: CGFloat = 56, showRing: Bool = false) {
        self.gradient = group.gradient.gradient
        self.initials = group.initials
        self.size = size
        self.showRing = showRing
    }
    
    var body: some View {
        ZStack {
            if showRing {
                RoundedRectangle(cornerRadius: size * 0.32)
                    .fill(YGColors.rainbowRingGradient)
                    .frame(width: size + 6, height: size + 6)
            }

            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(gradient)
                .frame(width: size, height: size)
                .overlay {
                    if showRing {
                        RoundedRectangle(cornerRadius: size * 0.28)
                            .strokeBorder(Color.white, lineWidth: 2)
                    }
                }
                .overlay {
                    Text(initials)
                        .font(.system(size: size * 0.4, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        }
    }
}

// MARK: - Group Avatar (logo or fallback)
//
// Renders a youth-group avatar from a `logoUrl`. If the URL is nil/empty/invalid,
// or the image hasn't loaded yet, shows the provided fallback (typically initials
// or the existing YGGroupIcon). Keeps a consistent outer frame + corner radius
// so callers can wrap their own border/shadow around it.
//
// Uses `RemoteImageCache` so once a logo loads it's reused instantly from memory
// on subsequent renders — no flicker when revisiting the map after the public
// profile, no re-decoding, no extra network roundtrip.

struct GroupAvatar<Fallback: View>: View {
    let logoUrl: String?
    let size: CGFloat
    let cornerRadius: CGFloat
    @ViewBuilder var fallback: () -> Fallback

    var body: some View {
        if let s = logoUrl, !s.isEmpty, let url = URL(string: s) {
            CachedRemoteImage(url: url, fallback: fallback)
                .frame(width: size, height: size)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            fallback()
        }
    }
}

// MARK: - Cached Remote Image
//
// Drop-in replacement for `AsyncImage` that:
//   1. Checks an in-memory NSCache for the decoded UIImage — synchronous hit on
//      every subsequent render means no flicker after the first fetch.
//   2. Falls back to URLSession with `URLCache.shared` (persistent across app
//      launches) and `.returnCacheDataElseLoad` so cached responses skip the
//      network entirely.
//   3. Renders the fallback view while loading or on failure.

struct CachedRemoteImage<Fallback: View>: View {
    let url: URL
    @ViewBuilder var fallback: () -> Fallback

    /// Seed @State synchronously from the cache so a cache hit renders the
    /// image on the FIRST frame, with no fallback flash.
    @State private var image: UIImage?

    init(url: URL, @ViewBuilder fallback: @escaping () -> Fallback) {
        self.url = url
        self.fallback = fallback
        self._image = State(initialValue: RemoteImageCache.shared.image(for: url))
    }

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallback()
            }
        }
        .task(id: url) {
            // If we already have it in memory, nothing to do.
            if RemoteImageCache.shared.image(for: url) != nil { return }
            if let loaded = await RemoteImageCache.shared.load(url) {
                image = loaded
            }
        }
    }
}

// MARK: - Remote Image Cache

@MainActor
final class RemoteImageCache {
    static let shared = RemoteImageCache()

    private let memoryCache = NSCache<NSURL, UIImage>()

    private init() {
        memoryCache.countLimit = 200
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // ~50 MB of decoded images in RAM
    }

    /// Synchronous lookup. Returns the cached image immediately if present.
    func image(for url: URL) -> UIImage? {
        memoryCache.object(forKey: url as NSURL)
    }

    /// Async fetch. Hits the memory cache first, then URLCache.shared (disk),
    /// then network. Decoded images are pinned in memory for the rest of the
    /// session.
    func load(_ url: URL) async -> UIImage? {
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let img = UIImage(data: data) else { return nil }
            let cost = Int(img.size.width * img.size.height * 4) // 4 bytes/pixel rough estimate
            memoryCache.setObject(img, forKey: url as NSURL, cost: cost)
            return img
        } catch {
            return nil
        }
    }
}

// MARK: - Tab Bar
struct YGTabBar: View {
    @Binding var selectedTab: AppTab
    var dark: Bool = false
    var onTabChange: ((AppTab) -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    dark: dark
                ) {
                    selectedTab = tab
                    onTabChange?(tab)
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 64)
        .background {
            if dark {
                Color.black.opacity(0.62)
            } else {
                Color.white.opacity(0.7)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .overlay {
            RoundedRectangle(cornerRadius: 32)
                .strokeBorder(
                    dark ? Color.white.opacity(0.1) : Color.white.opacity(0.6),
                    lineWidth: 0.5
                )
        }
        .shadow(
            color: dark ? .black.opacity(0.4) : .black.opacity(0.1),
            radius: dark ? 16 : 8,
            y: 8
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
    }
}

private struct TabBarButton: View {
    let tab: AppTab
    let isSelected: Bool
    let dark: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                tab.icon(isActive: isSelected)
                    .font(.system(size: 24))
                
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(
                isSelected
                    ? (dark ? Color.white : YGColors.ink)
                    : (dark ? Color.white.opacity(0.55) : YGColors.ink.opacity(0.5))
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .offset(y: isSelected ? -1 : 0)
            .animation(.spring(response: 0.15), value: isSelected)
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case plans
    case bible
    case messages
    case profile
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .plans: return "Plans"
        case .bible: return "Bible"
        case .messages: return "Messages"
        case .profile: return "Me"
        }
    }
    
    @ViewBuilder
    func icon(isActive: Bool) -> some View {
        switch self {
        case .home:
            Image(systemName: isActive ? "house.fill" : "house")
        case .plans:
            Image(systemName: isActive ? "leaf.fill" : "leaf")
        case .bible:
            Image(systemName: isActive ? "book.fill" : "book")
        case .messages:
            Image(systemName: isActive ? "message.fill" : "message")
        case .profile:
            Image(systemName: isActive ? "person.fill" : "person")
        }
    }
}

// MARK: - Stat Pill Component
struct StatPill: View {
    let icon: String
    let value: String
    let color: Color
    var dark: Bool = false
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
            
            Text(value)
                .font(.lilitaOne(size: 15))
                .foregroundStyle(dark ? .white : YGColors.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(dark ? Color.black.opacity(0.4) : Color.white)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(
                    dark ? Color.white.opacity(0.15) : Color.black.opacity(0.05),
                    lineWidth: 0.5
                )
        }
    }
}

// MARK: - Section Title
struct SectionTitle: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil
    var dark: Bool = false
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.lilitaOne(size: 24))
                .foregroundStyle(dark ? .white : YGColors.ink)
            
            Spacer()
            
            if let action = action, let onAction = onAction {
                Button(action: onAction) {
                    Text(action)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(YGColors.violet)
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 10)
    }
}

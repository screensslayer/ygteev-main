//
//  AppearanceManager.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/7/26.
//

import SwiftUI

@Observable
class AppearanceManager {
    static let shared = AppearanceManager()
    
    var isDarkMode: Bool = false
    
    private init() {}
}

// MARK: - Theme Colors
struct ThemeColors {
    // Background colors
    static func background(isDark: Bool) -> Color {
        isDark ? .black : YGColors.paper
    }
    
    static func cardBackground(isDark: Bool) -> Color {
        isDark ? Color(hex: "1C1C1E") : .white
    }
    
    static func secondaryBackground(isDark: Bool) -> Color {
        isDark ? Color(hex: "2C2C2E") : Color(hex: "F0EDF8")
    }
    
    // Text colors
    static func primaryText(isDark: Bool) -> Color {
        isDark ? .white : YGColors.ink
    }
    
    static func secondaryText(isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.6) : YGColors.ink.opacity(0.55)
    }
    
    static func tertiaryText(isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.4) : YGColors.ink.opacity(0.35)
    }
    
    // Border colors
    static func border(isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }
    
    // Divider colors
    static func divider(isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }
}

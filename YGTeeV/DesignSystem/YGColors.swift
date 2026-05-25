//
//  YGColors.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import SwiftUI

// YGTeeV color palette - youthful, vibrant, electric purple/blue
struct YGColors {
    // MARK: - Core Electric Palette
    static let violet = Color(hex: "6B2BFF")
    static let violetDeep = Color(hex: "3D0FB8")
    static let violetSoft = Color(hex: "B79FFF")
    static let blue = Color(hex: "0066FF")
    static let blueElectric = Color(hex: "2D7BFF")
    static let cyan = Color(hex: "00E0FF")
    static let pink = Color(hex: "FF3DA5")
    static let yellow = Color(hex: "FFD60A")
    static let lime = Color(hex: "B4FF3C")
    static let orange = Color(hex: "FF6B35")
    
    // MARK: - Garden / Pixel Palette
    static let pixSky = Color(hex: "A0E5FF")
    static let pixSkyDusk = Color(hex: "C8B5FF")
    static let pixGrass = Color(hex: "4CC65A")
    static let pixGrassDark = Color(hex: "2B8A3E")
    static let pixSoil = Color(hex: "6B3F1A")
    static let pixWater = Color(hex: "3DAEFF")
    static let pixTree = Color(hex: "1F7A2B")
    
    // MARK: - Neutrals
    static let ink = Color(hex: "0A0712")
    static let ink2 = Color(hex: "1A1428")
    static let ink3 = Color(hex: "2D2542")
    static let paper = Color(hex: "FAF8FF")
    static let paper2 = Color(hex: "F0EDF8")
    
    // MARK: - Semantic Colors
    static let xp = Color(hex: "FFD60A")
    static let water = Color(hex: "3DAEFF")
    static let streak = Color(hex: "FF6B35")
    
    // MARK: - Gradients
    static let violetGradient = LinearGradient(
        colors: [violet, violetDeep],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let violetPinkGradient = LinearGradient(
        colors: [violet, pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cyanBlueGradient = LinearGradient(
        colors: [cyan, blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let yellowOrangeGradient = LinearGradient(
        colors: [yellow, orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let limeGreenGradient = LinearGradient(
        colors: [lime, pixGrassDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let rainbowRingGradient = AngularGradient(
        colors: [pink, yellow, cyan, violet, pink],
        center: .center,
        startAngle: .zero,
        endAngle: .degrees(360)
    )
}

// MARK: - Color Extension for Hex Initialization
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

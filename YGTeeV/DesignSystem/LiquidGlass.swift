//
//  LiquidGlass.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import SwiftUI

// Liquid Glass effect - ultra-modern iOS design with blur and vibrancy
struct LiquidGlassModifier: ViewModifier {
    var dark: Bool = false
    var borderOpacity: Double = 0.6
    
    func body(content: Content) -> some View {
        content
            .background {
                if dark {
                    Color.black.opacity(0.45)
                } else {
                    Color.white.opacity(0.55)
                }
            }
            .background(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(
                        dark ? Color.white.opacity(0.12) : Color.white.opacity(borderOpacity),
                        lineWidth: 0.5
                    )
            }
            .shadow(
                color: dark ? Color.black.opacity(0.3) : Color.black.opacity(0.06),
                radius: dark ? 16 : 8,
                y: 4
            )
    }
}

extension View {
    func liquidGlass(dark: Bool = false, borderOpacity: Double = 0.6) -> some View {
        modifier(LiquidGlassModifier(dark: dark, borderOpacity: borderOpacity))
    }
}

// MARK: - Pixel Card Style (for garden/gamified UI)
struct PixelCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(YGColors.ink, lineWidth: 3)
            }
            .shadow(color: YGColors.ink, radius: 0, x: 4, y: 4)
    }
}

extension View {
    func pixelCard() -> some View {
        modifier(PixelCardModifier())
    }
}

// MARK: - Primary Button Style
struct PrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient = YGColors.violetGradient
    var textColor: Color = .white
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("SF Pro Display", size: 17).weight(.bold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(gradient)
            .clipShape(Capsule())
            .shadow(color: configuration.isPressed ? .clear : YGColors.violet.opacity(0.35), radius: 20, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.08, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle {
        PrimaryButtonStyle()
    }
    
    static func primary(gradient: LinearGradient, textColor: Color = .white) -> PrimaryButtonStyle {
        PrimaryButtonStyle(gradient: gradient, textColor: textColor)
    }
}

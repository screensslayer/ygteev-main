//
//  YGFonts.swift
//  YGTeeV
//
//  Created by Jim Jacob on 5/6/26.
//

import SwiftUI
import UIKit

extension Font {
    static func lilitaOne(size: CGFloat) -> Font {
        // Try the PostScript name first, then family name
        // Based on console: CGFont registered as "LilitaOne"
        if UIFont(name: "LilitaOne-Regular", size: size) != nil {
            return Font.custom("LilitaOne-Regular", size: size)
        } else if UIFont(name: "LilitaOne", size: size) != nil {
            return Font.custom("LilitaOne", size: size)
        }
        // Fallback
        return Font.custom("LilitaOne-Regular", size: size)
    }
}

// Helper to register custom fonts
struct FontLoader {
    static func loadFonts() {
        registerFont(name: "LilitaOne-Regular", extension: "ttf")
    }
    
    private static func registerFont(name: String, extension ext: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("❌ Font file not found: \(name).\(ext)")
            print("📁 Bundle resources:", Bundle.main.paths(forResourcesOfType: ext, inDirectory: nil))
            return
        }
        
        guard let fontDataProvider = CGDataProvider(url: url as CFURL),
              let font = CGFont(fontDataProvider) else {
            print("❌ Failed to load font from: \(url)")
            return
        }
        
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterGraphicsFont(font, &error) {
            print("✅ Successfully registered font: \(name)")
            if let postScriptName = font.postScriptName as String? {
                print("   PostScript name: \(postScriptName)")
            }
        } else {
            let errorDescription = error?.takeRetainedValue()
            if let errorDescription = errorDescription {
                let errorMessage = String(describing: errorDescription)
                // Font might already be registered, which is fine
                if errorMessage.contains("already registered") {
                    print("ℹ️ Font already registered: \(name)")
                } else {
                    print("❌ Error registering font: \(errorMessage)")
                }
            }
        }
    }
}

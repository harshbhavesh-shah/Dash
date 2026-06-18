//
//  Theme.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI

// Keeping this around as a fallback in case other files still call Color.babyPink!
extension Color {
    static let babyPink = Color(red: 1.0, green: 0.75, blue: 0.85)
}

// --- YOUR CUSTOM GLASS AESTHETIC ---
struct PolishedGlass: ViewModifier {
    @AppStorage("accentColorRed") private var r: Double = 0.91
    @AppStorage("accentColorGreen") private var g: Double = 0.80
    @AppStorage("accentColorBlue") private var b: Double = 0.85
    
    var accentColor: Color {
        Color(red: r, green: g, blue: b)
    }

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base AppKit blur
                    LiquidGlass()
                    
                    // The dynamic color tint
                    accentColor.opacity(0.12)
                    
                    // The "Stuff" (Refractions)
                    LinearGradient(
                        gradient: Gradient(colors: [.white.opacity(0.18), .clear, .clear]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.screen)
                    
                    // Specular Edge
                    Color.white.opacity(0.25)
                        .frame(width: 0.5)
                        .blendMode(.screen)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            )
            .shadow(color: .black.opacity(0.1), radius: 15, x: 5, y: 0)
    }
}

extension View {
    func polishedGlassAesthetic() -> some View {
        self.modifier(PolishedGlass())
    }
}

// --- NEW: THE GLOBAL CODESPACE THEME MATRIX ---
enum ShromeTheme: String, CaseIterable, Identifiable, Codable {
    case cosmicPastel  = "Cosmic Pastel"
    case cyberpunkNeon = "Night City"
    case solarFlare    = "Solar Flare"
    case deepOcean     = "Deep Ocean"
    case matrixGreen   = "Digital Rain"
    case monochrome    = "Monochrome Slate"
    case auroraBorealis = "Northern Lights"
    case amethystGlow  = "Amethyst"
    case moltenGold    = "Midas Touch"
    case volcanicAsh   = "Magma Core"
    
    var id: String { self.rawValue }
    
    var accentColor: Color {
        switch self {
        case .cosmicPastel:   return Color(red: 0.96, green: 0.55, blue: 0.72)
        case .cyberpunkNeon:  return Color(red: 0.00, green: 0.95, blue: 1.00)
        case .solarFlare:     return Color(red: 1.00, green: 0.40, blue: 0.00)
        case .deepOcean:      return Color(red: 0.00, green: 0.50, blue: 1.00)
        case .matrixGreen:    return Color(red: 0.00, green: 1.00, blue: 0.30)
        case .monochrome:     return .primary
        case .auroraBorealis: return Color(red: 0.20, green: 0.85, blue: 0.55)
        case .amethystGlow:   return Color(red: 0.65, green: 0.40, blue: 1.00)
        case .moltenGold:     return Color(red: 0.95, green: 0.75, blue: 0.20)
        case .volcanicAsh:    return Color(red: 1.00, green: 0.25, blue: 0.25)
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .cosmicPastel:   return [accentColor.opacity(0.65), Color.purple.opacity(0.4), accentColor.opacity(0.65)]
        case .cyberpunkNeon:  return [Color.cyan.opacity(0.7), Color.purple.opacity(0.6), Color.pink.opacity(0.7)]
        case .solarFlare:     return [Color.orange.opacity(0.7), Color.red.opacity(0.5), Color.yellow.opacity(0.6)]
        case .deepOcean:      return [Color.blue.opacity(0.7), Color.indigo.opacity(0.6), Color.teal.opacity(0.5)]
        case .matrixGreen:    return [Color.green.opacity(0.8), Color.black.opacity(0.3), Color.green.opacity(0.5)]
        case .monochrome:     return [Color.secondary.opacity(0.4), Color.primary.opacity(0.1), Color.secondary.opacity(0.4)]
        case .auroraBorealis: return [Color.green.opacity(0.6), Color.blue.opacity(0.5), Color.teal.opacity(0.6)]
        case .amethystGlow:   return [Color.purple.opacity(0.7), Color.pink.opacity(0.4), Color.indigo.opacity(0.6)]
        case .moltenGold:     return [Color.yellow.opacity(0.7), Color.orange.opacity(0.5), Color.yellow.opacity(0.6)]
        case .volcanicAsh:    return [Color.red.opacity(0.7), Color.black.opacity(0.5), Color.orange.opacity(0.6)]
        }
    }
}

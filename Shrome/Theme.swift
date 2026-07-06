//
//  Theme.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI

extension Color {
    static let babyPink = Color(red: 1.0, green: 0.75, blue: 0.85)
    static let shromePrivate = Color(red: 0.64, green: 0.42, blue: 0.96)
}

// BUG FIX: FloatingAddressBar and GravityLandingView each declared their own
// @AppStorage("customFavoritesJSON") default value — FloatingAddressBar used
// an empty string, GravityLandingView used the real starter set below. For a
// brand new user, whichever view wrote to the shared key *first* (typically
// FloatingAddressBar, via the very first favorite-toggle tap) would silently
// overwrite the starter favorites with its own, different default before
// they'd ever actually been persisted. Both views now reference this single
// constant instead of declaring their own.
enum ShromeDefaults {
    static let favoritesJSON: String = """
    [
        {"name": "Apple", "url": "apple.com", "icon": "apple.logo"},
        {"name": "GitHub", "url": "github.com", "icon": "terminal.fill"},
        {"name": "YouTube", "url": "youtube.com", "icon": "play.rectangle.fill"},
        {"name": "Dribbble", "url": "dribbble.com", "icon": "paintpalette.fill"}
    ]
    """
}

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
                    LiquidGlass()
                    accentColor.opacity(0.12)
                    
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

extension Animation {
    static var shromeBouncy: Animation {
        .spring(response: 0.42, dampingFraction: 0.68)
    }
    static var shromeSnappy: Animation {
        .spring(response: 0.3, dampingFraction: 0.62)
    }
    static var shromePop: Animation {
        .spring(response: 0.22, dampingFraction: 0.55)
    }
}
struct BouncyButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.9

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1.0)
            .animation(.shromePop, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BouncyButtonStyle {
    static var bouncy: BouncyButtonStyle { BouncyButtonStyle() }
    static func bouncy(scale: CGFloat) -> BouncyButtonStyle { BouncyButtonStyle(pressedScale: scale) }
}

enum ShromeTheme: String, CaseIterable, Identifiable, Codable {
    case cosmicPastel   = "Cosmic Pastel"
    case cyberpunkNeon  = "Night City"
    case solarFlare     = "Solar Flare"
    case deepOcean      = "Deep Ocean"
    case matrixGreen    = "Digital Rain"
    case monochrome     = "Monochrome Slate"
    case auroraBorealis = "Northern Lights"
    case amethystGlow   = "Amethyst"
    case moltenGold     = "Midas Touch"
    case volcanicAsh    = "Magma Core"
    case cherryBlossom  = "Cherry Blossom"
    case mintFrost      = "Mint Frost"
    case desertSand     = "Desert Sand"
    case midnightInk    = "Midnight Ink"
    case flamingoPop    = "Flamingo Pop"
    case arcticBlue     = "Arctic Blue"
    case forestCanopy   = "Forest Canopy"
    case sunsetBoulevard = "Sunset Boulevard"
    case lavenderDream  = "Lavender Dream"
    case crimsonTide    = "Crimson Tide"
    case tealReef       = "Teal Reef"
    case roseGold       = "Rose Gold"
    case electricLime   = "Electric Lime"
    case plumWine       = "Plum Wine"
    case skylineGray    = "Skyline Gray"
    case tangerineDream = "Tangerine Dream"
    case oceanMist      = "Ocean Mist"
    case blushPetal     = "Blush Petal"
    case coffeeBean      = "Coffee Bean"
    case royalIndigo    = "Royal Indigo"

    var id: String { self.rawValue }
    
    var accentColor: Color {
        switch self {
        case .cosmicPastel:    return Color(red: 0.96, green: 0.55, blue: 0.72)
        case .cyberpunkNeon:   return Color(red: 0.00, green: 0.95, blue: 1.00)
        case .solarFlare:      return Color(red: 1.00, green: 0.40, blue: 0.00)
        case .deepOcean:       return Color(red: 0.00, green: 0.50, blue: 1.00)
        case .matrixGreen:     return Color(red: 0.00, green: 1.00, blue: 0.30)
        case .monochrome:      return .primary
        case .auroraBorealis:  return Color(red: 0.20, green: 0.85, blue: 0.55)
        case .amethystGlow:    return Color(red: 0.65, green: 0.40, blue: 1.00)
        case .moltenGold:      return Color(red: 0.95, green: 0.75, blue: 0.20)
        case .volcanicAsh:     return Color(red: 1.00, green: 0.25, blue: 0.25)
        case .cherryBlossom:   return Color(red: 1.00, green: 0.72, blue: 0.78)
        case .mintFrost:       return Color(red: 0.55, green: 0.95, blue: 0.80)
        case .desertSand:      return Color(red: 0.88, green: 0.75, blue: 0.55)
        case .midnightInk:     return Color(red: 0.18, green: 0.22, blue: 0.45)
        case .flamingoPop:     return Color(red: 1.00, green: 0.30, blue: 0.55)
        case .arcticBlue:      return Color(red: 0.55, green: 0.85, blue: 1.00)
        case .forestCanopy:    return Color(red: 0.13, green: 0.45, blue: 0.25)
        case .sunsetBoulevard: return Color(red: 1.00, green: 0.45, blue: 0.35)
        case .lavenderDream:   return Color(red: 0.78, green: 0.68, blue: 0.95)
        case .crimsonTide:     return Color(red: 0.80, green: 0.10, blue: 0.20)
        case .tealReef:        return Color(red: 0.00, green: 0.65, blue: 0.62)
        case .roseGold:        return Color(red: 0.90, green: 0.62, blue: 0.55)
        case .electricLime:    return Color(red: 0.70, green: 1.00, blue: 0.10)
        case .plumWine:        return Color(red: 0.50, green: 0.18, blue: 0.38)
        case .skylineGray:     return Color(red: 0.55, green: 0.62, blue: 0.70)
        case .tangerineDream:  return Color(red: 1.00, green: 0.58, blue: 0.15)
        case .oceanMist:       return Color(red: 0.55, green: 0.85, blue: 0.85)
        case .blushPetal:      return Color(red: 0.95, green: 0.68, blue: 0.70)
        case .coffeeBean:      return Color(red: 0.45, green: 0.32, blue: 0.22)
        case .royalIndigo:     return Color(red: 0.28, green: 0.18, blue: 0.70)
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .cosmicPastel:    return [accentColor.opacity(0.65), Color.purple.opacity(0.4), accentColor.opacity(0.65)]
        case .cyberpunkNeon:   return [Color.cyan.opacity(0.7), Color.purple.opacity(0.6), Color.pink.opacity(0.7)]
        case .solarFlare:      return [Color.orange.opacity(0.7), Color.red.opacity(0.5), Color.yellow.opacity(0.6)]
        case .deepOcean:       return [Color.blue.opacity(0.7), Color.indigo.opacity(0.6), Color.teal.opacity(0.5)]
        case .matrixGreen:     return [Color.green.opacity(0.8), Color.black.opacity(0.3), Color.green.opacity(0.5)]
        case .monochrome:      return [Color.secondary.opacity(0.4), Color.primary.opacity(0.1), Color.secondary.opacity(0.4)]
        case .auroraBorealis:  return [Color.green.opacity(0.6), Color.blue.opacity(0.5), Color.teal.opacity(0.6)]
        case .amethystGlow:    return [Color.purple.opacity(0.7), Color.pink.opacity(0.4), Color.indigo.opacity(0.6)]
        case .moltenGold:      return [Color.yellow.opacity(0.7), Color.orange.opacity(0.5), Color.yellow.opacity(0.6)]
        case .volcanicAsh:     return [Color.red.opacity(0.7), Color.black.opacity(0.5), Color.orange.opacity(0.6)]
        case .cherryBlossom:   return [accentColor.opacity(0.8), Color.white.opacity(0.5), accentColor.opacity(0.5)]
        case .mintFrost:       return [accentColor.opacity(0.8), Color.white.opacity(0.4), Color.teal.opacity(0.4)]
        case .desertSand:      return [accentColor.opacity(0.8), Color.brown.opacity(0.35), accentColor.opacity(0.5)]
        case .midnightInk:     return [accentColor.opacity(0.85), Color.black.opacity(0.5), Color.indigo.opacity(0.5)]
        case .flamingoPop:     return [accentColor.opacity(0.85), Color.orange.opacity(0.4), accentColor.opacity(0.55)]
        case .arcticBlue:      return [accentColor.opacity(0.8), Color.white.opacity(0.45), Color.blue.opacity(0.4)]
        case .forestCanopy:    return [accentColor.opacity(0.85), Color.black.opacity(0.3), Color.green.opacity(0.5)]
        case .sunsetBoulevard: return [Color.orange.opacity(0.7), Color.pink.opacity(0.5), Color.purple.opacity(0.55)]
        case .lavenderDream:   return [accentColor.opacity(0.8), Color.white.opacity(0.4), Color.purple.opacity(0.4)]
        case .crimsonTide:     return [accentColor.opacity(0.85), Color.black.opacity(0.4), Color.red.opacity(0.5)]
        case .tealReef:        return [accentColor.opacity(0.8), Color.blue.opacity(0.4), Color.green.opacity(0.4)]
        case .roseGold:        return [accentColor.opacity(0.8), Color.yellow.opacity(0.3), accentColor.opacity(0.5)]
        case .electricLime:    return [accentColor.opacity(0.85), Color.green.opacity(0.4), Color.yellow.opacity(0.5)]
        case .plumWine:        return [accentColor.opacity(0.85), Color.black.opacity(0.4), Color.pink.opacity(0.35)]
        case .skylineGray:     return [accentColor.opacity(0.75), Color.white.opacity(0.3), Color.blue.opacity(0.3)]
        case .tangerineDream:  return [accentColor.opacity(0.8), Color.red.opacity(0.4), Color.yellow.opacity(0.55)]
        case .oceanMist:       return [accentColor.opacity(0.75), Color.white.opacity(0.4), Color.teal.opacity(0.4)]
        case .blushPetal:      return [accentColor.opacity(0.8), Color.white.opacity(0.45), Color.pink.opacity(0.4)]
        case .coffeeBean:      return [accentColor.opacity(0.85), Color.black.opacity(0.35), Color.brown.opacity(0.5)]
        case .royalIndigo:     return [accentColor.opacity(0.85), Color.blue.opacity(0.4), Color.purple.opacity(0.5)]
        }
    }
}

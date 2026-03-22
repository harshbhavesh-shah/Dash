//
//  Theme.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

//
//  Theme.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

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
    // Tap directly into the preferences you already built!
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

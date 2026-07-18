//
//  OnboardingOrbBackground.swift
//  Shrome
//
//  Created by Harsh Shah on 15/07/26.
//

//
//  OnboardingOrbBackground.swift
//  Shrome
//

import SwiftUI
import AppKit

private struct Orb: Identifiable {
    let id = UUID()
    let size: CGFloat
    let color: Color
    let startPosition: CGPoint // as a fraction of the screen, 0...1
    let driftRadius: CGFloat
    let duration: Double
    let opacity: Double
}

/// Soft, blurred, drifting color washes behind the onboarding flow.
///
/// BUG FIX: previously drove motion with a single boolean toggle +
/// repeatForever — that pattern is known to be unreliable specifically
/// inside Xcode's Preview canvas (often just doesn't loop). This drives
/// position from actual continuously-elapsed time via TimelineView, with
/// each orb's x/y on different sine frequencies so they drift in organic,
/// desynchronized paths rather than a mechanical back-and-forth.
struct OnboardingOrbBackground: View {
    var accentColor: Color = Color(red: 0.96, green: 0.55, blue: 0.72)

    private var orbs: [Orb] {
        [
            Orb(size: 260, color: accentColor, startPosition: CGPoint(x: 0.12, y: 0.15), driftRadius: 50, duration: 11, opacity: 0.6),
            Orb(size: 180, color: accentColor.hueShifted(by: 45), startPosition: CGPoint(x: 0.85, y: 0.20), driftRadius: 40, duration: 9, opacity: 0.5),
            Orb(size: 150, color: accentColor.hueShifted(by: -30), startPosition: CGPoint(x: 0.78, y: 0.80), driftRadius: 55, duration: 13, opacity: 0.5),
            Orb(size: 210, color: accentColor.hueShifted(by: 20), startPosition: CGPoint(x: 0.15, y: 0.85), driftRadius: 45, duration: 10, opacity: 0.45),
            Orb(size: 110, color: accentColor.hueShifted(by: -55), startPosition: CGPoint(x: 0.50, y: 0.06), driftRadius: 35, duration: 8, opacity: 0.4),
        ]
    }

    var body: some View {
        TimelineView(.animation) { context in
            GeometryReader { geo in
                ZStack {
                    ForEach(orbs) { orb in
                        let elapsed = context.date.timeIntervalSinceReferenceDate
                        let angleX = elapsed / orb.duration * 2 * .pi
                        let angleY = elapsed / (orb.duration * 1.4) * 2 * .pi
                        let dx = cos(angleX) * orb.driftRadius
                        let dy = sin(angleY) * orb.driftRadius

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [orb.color.opacity(orb.opacity), orb.color.opacity(0)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: orb.size / 2
                                )
                            )
                            .frame(width: orb.size, height: orb.size)
                            .position(
                                x: geo.size.width * orb.startPosition.x + dx,
                                y: geo.size.height * orb.startPosition.y + dy
                            )
                            // BUG FIX: was 60 — strong enough that orbs lost
                            // almost all presence/color. 35 keeps them soft
                            // without erasing them.
                            .blur(radius: 35)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

private extension Color {
    /// Generates a coordinated "family" color by shifting hue while
    /// preserving saturation/brightness — this is what fixes the mismatched
    /// palette. Every orb now derives from the same accent color instead of
    /// mixing in unrelated system colors like .blue/.purple/.pink.
    func hueShifted(by degrees: Double) -> Color {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        var newHue = hue + degrees / 360.0
        newHue = newHue.truncatingRemainder(dividingBy: 1.0)
        if newHue < 0 { newHue += 1 }
        return Color(hue: newHue, saturation: saturation, brightness: brightness)
    }
}

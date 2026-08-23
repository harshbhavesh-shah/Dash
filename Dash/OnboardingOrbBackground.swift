//
//  OnboardingOrbBackground.swift
//  Dash
//
//  Created by Harsh Shah on 15/07/26.
//


import SwiftUI
import AppKit

private struct OrbSpec: Identifiable {
    let id = UUID()
    let size: CGFloat
    let color: Color
    let origin: CGPoint // fraction of screen, 0...1
    let driftRadius: CGFloat
    let cycleDuration: Double
}

/// Flat, softly-glowing glass discs that float and glide smoothly, and
/// gently push apart from each other when they get close instead of
/// overlapping.
struct OnboardingOrbBackground: View {
    var accentColor: Color = Color(red: 0.96, green: 0.55, blue: 0.72)

    private var orbSpecs: [OrbSpec] {
        [
            OrbSpec(size: 220, color: accentColor, origin: CGPoint(x: 0.14, y: 0.18), driftRadius: 45, cycleDuration: 13),
            OrbSpec(size: 150, color: accentColor.hueShifted(by: 45), origin: CGPoint(x: 0.84, y: 0.22), driftRadius: 38, cycleDuration: 10),
            OrbSpec(size: 130, color: accentColor.hueShifted(by: -30), origin: CGPoint(x: 0.78, y: 0.78), driftRadius: 42, cycleDuration: 15),
            OrbSpec(size: 170, color: accentColor.hueShifted(by: 20), origin: CGPoint(x: 0.16, y: 0.82), driftRadius: 40, cycleDuration: 11),
            OrbSpec(size: 95, color: accentColor.hueShifted(by: -55), origin: CGPoint(x: 0.50, y: 0.08), driftRadius: 30, cycleDuration: 9),
        ]
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                let positions = resolvedPositions(
                    time: context.date.timeIntervalSinceReferenceDate,
                    containerSize: geo.size
                )
                ZStack {
                    ForEach(Array(orbSpecs.enumerated()), id: \.element.id) { index, spec in
                        GlassOrbView(spec: spec)
                            .position(positions[index])
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    /// Each orb's "ideal" position is a smooth sine-based drift (a pure
    /// function of elapsed time — no state, no springs). On top of that,
    /// one pass of pairwise separation pushes any orbs that have drifted
    /// close together back apart, so they behave like soft physical
    /// objects instead of passing through each other. Recomputed fresh
    /// every frame from time + repulsion rather than accumulated
    /// velocity/state, which keeps it stable with no drift or blow-up risk.
    private func resolvedPositions(time: TimeInterval, containerSize: CGSize) -> [CGPoint] {
        var positions: [CGPoint] = orbSpecs.map { spec in
            let angleX = time / spec.cycleDuration * 2 * .pi
            let angleY = time / (spec.cycleDuration * 1.4) * 2 * .pi
            let dx = cos(angleX) * spec.driftRadius
            let dy = sin(angleY) * spec.driftRadius
            return CGPoint(
                x: containerSize.width * spec.origin.x + dx,
                y: containerSize.height * spec.origin.y + dy
            )
        }

        for i in 0..<positions.count {
            for j in (i + 1)..<positions.count {
                let a = positions[i]
                let b = positions[j]
                let dx = b.x - a.x
                let dy = b.y - a.y
                let distance = sqrt(dx * dx + dy * dy)
                // BUG FIX: previously used spec.size (the core disc) for
                // this, but what's actually visible is the glow halo at
                // spec.size * 1.35 plus further blur spread on top of
                // that — the discs themselves could be kept apart while
                // the glows, which is most of what's visible, still
                // overlapped. Using the glow's real footprint instead.
                let minDistance = (orbSpecs[i].size * 1.35 + orbSpecs[j].size * 1.35) / 2 * 0.75
                if distance < minDistance && distance > 0.001 {
                    let overlap = minDistance - distance
                    let pushX = (dx / distance) * overlap * 0.5
                    let pushY = (dy / distance) * overlap * 0.5
                    positions[i].x -= pushX
                    positions[i].y -= pushY
                    positions[j].x += pushX
                    positions[j].y += pushY
                }
            }
        }

        return positions
    }
}

/// BUG FIX (balloon → flat glass): dropped the specular highlight, rim
/// stroke, and secondary catch-light entirely — that combination was what
/// read as glossy rubber. This is much closer to the reference: a single
/// soft radial gradient for the disc itself, plus a larger, heavily
/// blurred halo of the same color sitting behind it for the glow.
private struct GlassOrbView: View {
    let spec: OrbSpec

    var body: some View {
        ZStack {
            Circle()
                .fill(spec.color.opacity(0.32))
                .frame(width: spec.size * 1.35, height: spec.size * 1.35)
                .blur(radius: spec.size * 0.22)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [spec.color.opacity(0.52), spec.color.opacity(0.36)],
                        center: UnitPoint(x: 0.4, y: 0.35),
                        startRadius: 0,
                        endRadius: spec.size * 0.65
                    )
                )
                .frame(width: spec.size, height: spec.size)
        }
    }
}

private extension Color {
    /// Generates a coordinated "family" color by shifting hue while
    /// preserving saturation/brightness, so every orb derives from the
    /// same accent color instead of mixing in unrelated system colors.
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

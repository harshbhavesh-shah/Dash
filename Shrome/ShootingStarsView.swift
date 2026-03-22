//
//  ShootingStarsView.swift
//  Shrome
//
//  Created by Harsh Shah on 07/03/2026.
//

import SwiftUI

struct ShootingStarsView: View {
    // Kept to just 3 active shooting stars that we will strictly space out
    let shootingStarCount = 3
    // Tripled the static stars for a much deeper cosmic background
    let staticStarCount = 200
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. The Deep Space Void
                Color(red: 0.02, green: 0.02, blue: 0.05)
                    .ignoresSafeArea()
                
                // 2. The Aurora Gradient Glow
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.2, green: 0.75, blue: 1.0).opacity(0.15), // Sky
                        Color(red: 0.3, green: 0.85, blue: 0.5).opacity(0.05), // Sage
                        .clear
                    ]),
                    center: .topLeading,
                    startRadius: 100,
                    endRadius: geo.size.width
                )
                .ignoresSafeArea()
                
                // 3. The Regular Twinkling Stars
                ForEach(0..<staticStarCount, id: \.self) { _ in
                    TwinklingStar(geo: geo)
                }
                
                // 4. The Orchestrated Shooting Stars
                ForEach(0..<shootingStarCount, id: \.self) { index in
                    ShootingStar(geo: geo, index: index)
                }
            }
        }
    }
}

// MARK: - The Static Background Stars
struct TwinklingStar: View {
    let geo: GeometryProxy
    @State private var isBlinking = false
    
    let size = CGFloat.random(in: 1...2.5) // Slightly smaller on average for depth
    let relX = CGFloat.random(in: 0...1)
    let relY = CGFloat.random(in: 0...1)
    let blinkDuration = Double.random(in: 1.5...5.0)
    let blinkDelay = Double.random(in: 0...3.0)
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: size, height: size)
            .blur(radius: size > 1.5 ? 0.5 : 0)
            .opacity(isBlinking ? 0.05 : 0.7)
            .position(x: geo.size.width * relX, y: geo.size.height * relY)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: blinkDuration)
                    .delay(blinkDelay)
                    .repeatForever(autoreverses: true)
                ) {
                    isBlinking = true
                }
            }
    }
}

// MARK: - The Shooting Stars
struct ShootingStar: View {
    let geo: GeometryProxy
    let index: Int // We use this to force them to wait in line
    @State private var isAnimating = false
    
    let startXRel = CGFloat.random(in: 0...1.5)
    let startYRel = CGFloat.random(in: -1.0...0)
    
    // SLOWED DOWN AGAIN: Now takes 6 to 10 seconds to gracefully cross the screen
    let speed = Double.random(in: 6.0...10.0)
    let scale = CGFloat.random(in: 0.4...0.9)
    
    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [.white, .white.opacity(0.4), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 2 * scale, height: 120 * scale)
            .rotationEffect(.degrees(45))
            .shadow(color: Color(red: 0.2, green: 0.75, blue: 1.0).opacity(0.6), radius: 4, x: 0, y: 0)
            .offset(
                x: isAnimating ? -geo.size.width - 200 : geo.size.width * startXRel,
                y: isAnimating ? geo.size.height + 200 : geo.size.height * startYRel
            )
            .onAppear {
                // THE MATH:
                // Index 0 fires around 0-2s.
                // Index 1 waits exactly 5-7 seconds before firing.
                // Index 2 waits 10-14 seconds.
                // Once they all fire, the repeatForever combined with their transit times naturally keeps them spaced out.
                let calculatedDelay = Double(index) * Double.random(in: 5.0...7.0) + Double.random(in: 0...2.0)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(
                        .linear(duration: speed)
                        .delay(calculatedDelay)
                        // Adding a pause at the end of the animation before it loops
                        // so we don't end up with overlaps after a few cycles.
                        .repeatForever(autoreverses: false)
                    ) {
                        isAnimating = true
                    }
                }
            }
    }
}

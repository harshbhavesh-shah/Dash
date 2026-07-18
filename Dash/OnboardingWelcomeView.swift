//
//  OnboardingWelcomeView.swift
//  Shrome
//
//  Created by Harsh Shah on 15/07/26.
//

import SwiftUI

struct OnboardingWelcomeView: View {
    var accentColor: Color = Color(red: 0.96, green: 0.55, blue: 0.72)
    var onGetStarted: () -> Void
    var onSkip: () -> Void

    @State private var isContentVisible = false

    var body: some View {
        ZStack {
            // BUG FIX: previously hardcoded to black — reads as heavy
            // rather than premium. A light backdrop lets the colorful
            // blurred orbs actually read as color against brightness,
            // closer to how Apple's own onboarding moments (e.g. Apple
            // Intelligence's intro animation) use a light background, not
            // a dark one, specifically so the color washes have somewhere
            // to show up against.
            Color(white: 0.97).ignoresSafeArea()

            OnboardingOrbBackground(accentColor: accentColor)

            VStack {
                HStack {
                    Spacer()
                    Button("Skip", action: onSkip)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.black.opacity(0.4))
                        .padding(20)
                }
                Spacer()
            }

            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Text("Shrome")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundColor(.black.opacity(0.85))

                    Text("Fast, private, beautifully yours.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(accentColor)
                }

                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                // BUG FIX: 0.3 opacity tint read as washy/pale on a light
                // background — this needs to look like a confident,
                // saturated CTA now that it's not floating on black.
                .glassEffect(.regular.tint(accentColor.opacity(0.85)), in: Capsule())
            }
            .padding(40)
            // BUG FIX: this card previously had no tint, no border, and no
            // shadow at all — a glass surface needs a defined edge and some
            // depth to actually read as glass, not just faintly blur
            // whatever's behind it.
            .glassEffect(.regular.tint(accentColor.opacity(0.08)), in: RoundedRectangle(cornerRadius: 32))
            .overlay {
                RoundedRectangle(cornerRadius: 32)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.9), accentColor.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: accentColor.opacity(0.18), radius: 30, x: 0, y: 15)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
            .padding(60)
            .scaleEffect(isContentVisible ? 1 : 0.9)
            .opacity(isContentVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.dashBouncy.delay(0.2)) {
                isContentVisible = true
            }
        }
    }
}

#Preview {
    OnboardingWelcomeView(onGetStarted: {}, onSkip: {})
}

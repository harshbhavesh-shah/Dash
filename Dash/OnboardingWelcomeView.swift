//
//  OnboardingWelcomeView.swift
//  Dash
//

//
//  OnboardingWelcomeView.swift
//  Dash
//

import SwiftUI

struct OnboardingWelcomeView: View {
    var accentColor: Color = Color(red: 0.96, green: 0.55, blue: 0.72)
    var onGetStarted: () -> Void
    var onSkip: () -> Void

    @State private var isContentVisible = false

    var body: some View {
        ZStack {
            Color(white: 0.97).ignoresSafeArea()

            // Blur applies only to this view, not to the text stacked on
            // top of it (which is a sibling, not a child, in this ZStack)
            // — so the whole screen's worth of orbs reads as a soft
            // backdrop while the text in front stays completely sharp.
            OnboardingOrbBackground(accentColor: accentColor)
                .blur(radius: 6)

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

            // BUG FIX (design change): previously wrapped in a
            // .glassEffect() card with padding, border, and shadow — read
            // as a "small boxed container" that fought the floating,
            // weightless feel the orbs are going for. Text now floats
            // directly over the orb background, using a soft white glow
            // behind it for legibility instead of an opaque container. The
            // button stays as its own glass pill since it's an actual
            // control, not just text.
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    // Minimal per-letter entrance — same spirit as the
                    // coming-soon page's animated wordmark, simplified down
                    // to just scale + fade (no glass-transparency effect,
                    // per "minimal"). Each letter's .animation(delay:)
                    // overrides the ambient animation from onAppear below,
                    // so they cascade in slightly staggered rather than
                    // popping in all at once.
                    HStack(spacing: 0) {
                        ForEach(dashCharacters.indices, id: \.self) { index in
                            dashLetter(at: index)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .glassEffect(.regular.tint(accentColor.opacity(0.18)), in: RoundedRectangle(cornerRadius: 24))

                    Text("Allergic to ads. Addicted to speed.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(accentColor)
                        .shadow(color: .white.opacity(0.5), radius: 12, x: 0, y: 0)
                        .multilineTextAlignment(.center)
                }

                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(accentColor.opacity(0.85)), in: Capsule())
            }
            .padding(.horizontal, 40)
            .scaleEffect(isContentVisible ? 1 : 0.9)
            .opacity(isContentVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.dashBouncy.delay(0.2)) {
                isContentVisible = true
            }
        }
    }

    // Simplified per your ask: real .glassEffect() (applied to the HStack
    // above, tinted with accentColor for legibility) does the "liquid
    // glass" work now, instead of approximating it with a manual gradient
    // fill here. Worth knowing what to expect: .glassEffect() is a
    // material/background effect — same as how it's used on the button
    // below and everywhere else in the app — so this renders as a
    // translucent glass panel sitting behind the whole word, not as
    // glass-textured letterforms themselves. That's the same mechanism
    // this app already uses for glass surfaces everywhere else, just
    // applied to text instead of a button/card.
    private var dashCharacters: [Character] {
        Array("Dash")
    }

    // BUG FIX (round 3): the 6-modifier chain, even after simplifying away
    // the gradient, was STILL too much for the type-checker — each
    // chained modifier wraps the previous return type in another generic
    // layer, and by 6+ modifiers combined with inline arithmetic
    // (Double(index) * 0.06 + 0.2) in the same expression, the compiler's
    // inference cost compounds badly. This time: explicit type
    // annotations at every intermediate step (Text's own modifiers return
    // Text, so that's cheap and concrete), and AnyView to fully erase the
    // type after that — guaranteeing the compiler never has to solve a
    // deep nested-generic chain, regardless of how many modifiers follow.
    // AnyView's small runtime cost is completely negligible for 4 letters.
    private func dashLetter(at index: Int) -> some View {
        let delay: Double = Double(index) * 0.06 + 0.2

        let styledText: Text = Text(String(dashCharacters[index]))
            .font(.system(size: 46, weight: .bold, design: .rounded))
            .tracking(-1.5)
            .foregroundColor(.black.opacity(0.85))

        let animatedView: AnyView = AnyView(
            styledText
                .scaleEffect(isContentVisible ? 1 : 0.4)
                .opacity(isContentVisible ? 1 : 0)
        )

        return animatedView.animation(.dashBouncy.delay(delay), value: isContentVisible)
    }
}

#Preview {
    OnboardingWelcomeView(onGetStarted: {}, onSkip: {})
}

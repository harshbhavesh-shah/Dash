//
//  NameOnboardingView.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI

struct NameOnboardingView: View {
    var onComplete: (String) -> Void

    @State private var draftName: String = ""
    @State private var isVisible = false
    @FocusState private var isFieldFocused: Bool

    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72

    private var accentColor: Color { Color(red: r, green: g, blue: b) }

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 64, height: 64)

                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                VStack(spacing: 6) {
                    Text("Welcome to Shrome")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("What should we call you on your landing page?")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.75))
                        .multilineTextAlignment(.center)
                }

                TextField("Your name", text: $draftName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .focused($isFieldFocused)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background {
                        Color.clear
                            .glassEffect(.regular.tint(accentColor.opacity(0.06)), in: Capsule())
                    }
                    .overlay {
                        Capsule().strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
                    }
                    .onSubmit {
                        dismiss(with: draftName.trimmingCharacters(in: .whitespacesAndNewlines))
                    }

                HStack(spacing: 16) {
                    Button("Skip for now") {
                        dismiss(with: "")
                    }
                    .buttonStyle(.bouncy)
                    .foregroundColor(.secondary)
                    .font(.system(size: 13, weight: .medium, design: .rounded))

                    Spacer()

                    Button {
                        dismiss(with: draftName.trimmingCharacters(in: .whitespacesAndNewlines))
                    } label: {
                        Text("Continue")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                            .background {
                                Capsule().fill(accentColor)
                            }
                    }
                    .buttonStyle(.bouncy)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 30)
            .frame(width: 340)
            .background {
                Color.clear
                    .glassEffect(
                        .regular.tint(accentColor.opacity(0.05)),
                        in: RoundedRectangle(cornerRadius: 32, style: .continuous)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 16)
            .scaleEffect(isVisible ? 1 : 0.92)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.dashBouncy) {
                isVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFieldFocused = true
            }
        }
        .onExitCommand {
            dismiss(with: "")
        }
    }

    private func dismiss(with name: String) {
        withAnimation(.dashSnappy) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onComplete(name)
        }
    }
}

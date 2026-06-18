//
//  GravityLandingView.swift
//  Shrome
//

import SwiftUI

// MARK: - Liquid Glass Favourite Tile

private struct GlassFavoriteTile: View {
    let site: (name: String, url: String, icon: String)
    let isPrivateSession: Bool
    let onSubmit: (String) -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                // Base: frosted glass fill — brightens on hover
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                    .overlay {
                        // Hover highlight: a white wash that fades in over the glass
                        Circle()
                            .fill(Color.white.opacity(isHovered ? 0.14 : 0))
                    }

                // Rim light — intensifies on hover like glass catching light
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.75 : 0.40),
                                Color.white.opacity(isHovered ? 0.20 : 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 1.0 : 0.75
                    )
                    .frame(width: 56, height: 56)

                // Icon
                Image(systemName: site.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        isPrivateSession
                            ? Color.purple
                            : Color.primary.opacity(isHovered ? 1.0 : 0.88)
                    )
                    // Nudge icon up very slightly on hover, like a physical press
                    .offset(y: isHovered ? -1 : 0)
            }
            // Shadow deepens on hover to increase the sense of lift
            .shadow(
                color: .black.opacity(isHovered ? 0.28 : 0.18),
                radius: isHovered ? 14 : 8,
                x: 0,
                y: isHovered ? 7 : 4
            )
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
            // Slight scale-up on hover, quick spring snap
            .scaleEffect(isPressed ? 0.93 : (isHovered ? 1.06 : 1.0))
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isHovered)
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isPressed)

            Text(site.name)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary.opacity(isHovered ? 1.0 : 0.8))
                .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .contentShape(Circle())
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        onSubmit(site.url)
                    }
                }
        )
    }
}

// MARK: - Main Landing View

struct GravityLandingView: View {
    @Binding var urlString: String
    var namespace: Namespace.ID
    var onSubmit: (String) -> Void

    @FocusState private var isSearchFieldFocused: Bool

    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72

    @EnvironmentObject var tabManager: TabManager

    var accentColor: Color { Color(red: r, green: g, blue: b) }

    private var isPrivateSession: Bool {
        tabManager.activeTab.isPrivate
    }

    private var dynamicGreeting: String {
        let name = isPrivateSession ? "Stranger" : "Harshie"
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning, \(name)" }
        if hour < 17 { return "Good afternoon, \(name)" }
        return "Good evening, \(name)"
    }

    private var dynamicSubheader: String {
        if isPrivateSession {
            return "No one will know where we are sailing today."
        }
        return "Where are we sailing today?"
    }

    let favorites = [
        (name: "Apple",   url: "apple.com",    icon: "apple.logo"),
        (name: "GitHub",  url: "github.com",   icon: "terminal.fill"),
        (name: "YouTube", url: "youtube.com",  icon: "play.rectangle.fill"),
        (name: "Dribbble",url: "dribbble.com", icon: "paintpalette.fill")
    ]

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 36) {
                // Greeting header
                VStack(spacing: 6) {
                    Text(dynamicGreeting)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(dynamicSubheader)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.bottom, 8)

                // Search bar
                HStack(spacing: 0) {
                    Image(systemName: isPrivateSession ? "shield.fill" : "magnifyingglass")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(accentColor)
                        .padding(.leading, 20)

                    TextField("Search with Shrome...", text: $urlString)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .medium))
                        .multilineTextAlignment(.leading)
                        .focused($isSearchFieldFocused)
                        .onSubmit { onSubmit(urlString) }
                        .padding(.leading, 12)
                        .padding(.trailing, 20)
                }
                .matchedGeometryEffect(id: "sharedAddressBarKey", in: namespace)
                .frame(width: 550, height: 48)
                .background {
                    Color.clear
                        .glassEffect(
                            .regular.tint(accentColor.opacity(0.06)),
                            in: Capsule()
                        )
                }
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.65), accentColor.opacity(0.35), accentColor.opacity(0.65)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 510, height: 24)
                        .blur(radius: 35)
                        .opacity(0.85)
                }
                .shadow(color: .black.opacity(0.02), radius: 15, x: 0, y: 8)

                // Favourite tiles
                HStack(spacing: 32) {
                    ForEach(favorites, id: \.name) { site in
                        GlassFavoriteTile(
                            site: site,
                            isPrivateSession: isPrivateSession,
                            onSubmit: onSubmit
                        )
                    }
                }
                .padding(.top, 12)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if urlString == "about:blank" { urlString = "" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFieldFocused = true
            }
        }
    }
}

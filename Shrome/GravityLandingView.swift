//
//  GravityLandingView.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI

// MARK: - Liquid Glass Favourite Tile

private struct GlassFavoriteTile: View {
    let site: (name: String, url: String, icon: String)
    let isPrivateSession: Bool
    let hasBackgroundPhoto: Bool
    let onSubmit: (String) -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    private var faviconURL: URL? {
        guard !site.url.isEmpty else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?sz=128&domain=\(site.url)")
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Circle()
                            .fill(Color.white.opacity(isHovered ? 0.14 : 0))
                    }

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

                Group {
                    if isPrivateSession {
                        Image(systemName: site.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.shromePrivate)
                    } else {
                        AsyncImage(url: faviconURL) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 26, height: 26)
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            } else {
                                Image(systemName: site.icon)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(Color.primary.opacity(isHovered ? 1.0 : 0.88))
                            }
                        }
                        .id(site.url)
                    }
                }
                .offset(y: isHovered ? -1 : 0)
            }
            .shadow(
                color: .black.opacity(isHovered ? 0.28 : 0.18),
                radius: isHovered ? 14 : 8,
                x: 0,
                y: isHovered ? 7 : 4
            )
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
            // Slight scale-up on hover, quick spring snap
            .scaleEffect(isPressed ? 0.93 : (isHovered ? 1.06 : 1.0))
            .animation(.shromeSnappy, value: isHovered)
            .animation(.shromePop, value: isPressed)

            Text(site.name)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary.opacity(isHovered ? 1.0 : 0.8))
                .shadow(color: .black.opacity(hasBackgroundPhoto ? 0.35 : 0), radius: 6, x: 0, y: 1)
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
                    withAnimation(.shromeBouncy) {
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

    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72

    @AppStorage(BackgroundImageStore.appStorageKey) private var landingBackgroundImagePath: String = ""
    @AppStorage("searchSuggestions") private var searchSuggestions: Bool = true
    @State private var cachedBackgroundImage: NSImage? = nil

    @State private var isGlowPulsing = false

    @AppStorage("userPreferredName") private var userPreferredName: String = ""

    @State private var selectedGreetingPhrase: String = "Good day"

    private static let morningPhrases = [
        "Good morning", "Rise and shine", "Top of the morning", "Morning"
    ]
    private static let afternoonPhrases = [
        "Good afternoon", "Afternoon", "Hope your day's going well", "Hey there"
    ]
    private static let eveningPhrases = [
        "Good evening", "Evening", "Welcome back", "Hope you had a good day"
    ]
    private static let nightPhrases = [
        "Still up", "Burning the midnight oil", "Welcome to the late shift", "Quiet hours"
    ]

    private func randomGreetingPhrase() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let pool: [String]
        switch hour {
        case 5..<12:  pool = Self.morningPhrases
        case 12..<17: pool = Self.afternoonPhrases
        case 17..<22: pool = Self.eveningPhrases
        default:      pool = Self.nightPhrases
        }
        return pool.randomElement() ?? "Hello"
    }

    @EnvironmentObject var tabManager: TabManager

    @State private var topSuggestion: String? = nil
    @State private var debounceTask: Task<Void, Never>? = nil

    var accentColor: Color { Color(red: r, green: g, blue: b) }

    private var effectiveAccentColor: Color {
        isPrivateSession ? .shromePrivate : accentColor
    }

    private var isPrivateSession: Bool {
        tabManager.activeTab.isPrivate
    }

    private var hasBackgroundPhoto: Bool {
        cachedBackgroundImage != nil
    }

    private var dynamicGreeting: String {
        if isPrivateSession { return "\(selectedGreetingPhrase), Stranger" }

        let trimmedName = userPreferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? selectedGreetingPhrase : "\(selectedGreetingPhrase), \(trimmedName)"
    }

    private var dynamicSubheader: String {
        if isPrivateSession {
            return "No one will know where we are sailing today."
        }
        return "Where are we sailing today?"
    }

    @AppStorage("customFavoritesJSON") private var customFavoritesJSON: String = """
    [
        {"name": "Apple", "url": "apple.com", "icon": "apple.logo"},
        {"name": "GitHub", "url": "github.com", "icon": "terminal.fill"},
        {"name": "YouTube", "url": "youtube.com", "icon": "play.rectangle.fill"},
        {"name": "Dribbble", "url": "dribbble.com", "icon": "paintpalette.fill"}
    ]
    """

    private var favorites: [(name: String, url: String, icon: String)] {
        struct FavItem: Codable { let name: String; let url: String; let icon: String }
        guard let data = customFavoritesJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([FavItem].self, from: data) else { return [] }
        return decoded.map { ($0.name, $0.url, $0.icon) }
    }

    var body: some View {
        ZStack {
            if let cachedBackgroundImage {
                GeometryReader { geo in
                    Image(nsImage: cachedBackgroundImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
                .transition(.scale(scale: 1.06).combined(with: .opacity))
            }

            Color.clear
                .background(.ultraThinMaterial)
                .opacity(cachedBackgroundImage != nil ? 0.55 : 1.0)
                .ignoresSafeArea()

            if hasBackgroundPhoto {
                RadialGradient(
                    colors: [Color.black.opacity(0.28), Color.black.opacity(0.0)],
                    center: .center,
                    startRadius: 40,
                    endRadius: 420
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            VStack(spacing: 36) {
                // Greeting header
                VStack(spacing: 6) {
                    Text(dynamicGreeting)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .shadow(color: .black.opacity(hasBackgroundPhoto ? 0.4 : 0), radius: 10, x: 0, y: 2)

                    Text(dynamicSubheader)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary.opacity(0.7))
                        .shadow(color: .black.opacity(hasBackgroundPhoto ? 0.35 : 0), radius: 8, x: 0, y: 1)
                }
                .padding(.bottom, 8)

                // Search bar
                HStack(spacing: 0) {
                    Image(systemName: isPrivateSession ? "shield.fill" : "magnifyingglass")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(effectiveAccentColor)
                        .padding(.leading, 20)

                    InlineCompleteTextField(
                        text: $urlString,
                        suggestion: topSuggestion,
                        placeholder: "Search with Shrome...",
                        font: .systemFont(ofSize: 15, weight: .medium),
                        textColor: NSColor.labelColor,
                        autoFocusOnAppear: true,
                        onCommit: {
                            topSuggestion = nil
                            onSubmit(urlString)
                        },
                        onEscape: {
                            topSuggestion = nil
                        }
                    )
                    .padding(.leading, 12)
                    .padding(.trailing, 20)
                }
                .matchedGeometryEffect(id: "sharedAddressBarKey", in: namespace)
                .frame(width: 550, height: 48)
                .background {
                    ZStack {
                        if hasBackgroundPhoto {
                            Capsule().fill(Color.black.opacity(0.16))
                        }
                        Color.clear
                            .glassEffect(
                                .regular.tint(effectiveAccentColor.opacity(hasBackgroundPhoto ? 0.10 : 0.06)),
                                in: Capsule()
                            )
                    }
                }
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [effectiveAccentColor.opacity(0.65), effectiveAccentColor.opacity(0.35), effectiveAccentColor.opacity(0.65)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 510, height: 24)
                        .blur(radius: 35)
                        .opacity(0.85)
                }
                .background {
                    ZStack {
                        Capsule()
                            .fill(effectiveAccentColor)
                            .frame(width: 580, height: 64)
                            .blur(radius: 32)
                            .opacity(isGlowPulsing ? 0.30 : 0.18)

                        Capsule()
                            .fill(effectiveAccentColor)
                            .frame(width: 660, height: 90)
                            .blur(radius: 60)
                            .opacity(isGlowPulsing ? 0.22 : 0.10)
                    }
                    .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(0.02), radius: 15, x: 0, y: 8)

                // Favourite tiles
                HStack(spacing: 32) {
                    ForEach(favorites, id: \.name) { site in
                        GlassFavoriteTile(
                            site: site,
                            isPrivateSession: isPrivateSession,
                            hasBackgroundPhoto: hasBackgroundPhoto,
                            onSubmit: onSubmit
                        )
                    }
                }
                .padding(.top, 12)
                .transition(.opacity)
            }

            LiquidGlassClockPanel(hasBackgroundPhoto: hasBackgroundPhoto)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            cachedBackgroundImage = BackgroundImageStore.loadImage(at: landingBackgroundImagePath)
            selectedGreetingPhrase = randomGreetingPhrase()
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                isGlowPulsing = true
            }
        }
        .onDisappear {
            // BUG FIX: same reasoning as FloatingAddressBar — tie this
            // task's lifetime to the view instead of letting it run detached.
            debounceTask?.cancel()
        }
        .onChange(of: landingBackgroundImagePath) { _, newPath in
            withAnimation(.shromeBouncy) {
                cachedBackgroundImage = BackgroundImageStore.loadImage(at: newPath)
            }
        }
        .onChange(of: urlString) { _, newValue in
            debounceTask?.cancel()
            // BUG FIX: "Show search suggestions" toggle in Settings previously
            // did nothing — suggestions were always fetched and shown.
            guard searchSuggestions, !newValue.isEmpty else {
                topSuggestion = nil
                return
            }
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 80_000_000)
                guard !Task.isCancelled else { return }
                let results = await tabManager.fetchSuggestions(matching: newValue)
                await MainActor.run {
                    let typed = newValue.lowercased()
                    if let url = results.first?.url, url.lowercased().hasPrefix(typed) {
                        topSuggestion = url
                    } else if let url = results.first?.url,
                              let host = URL(string: url.hasPrefix("http") ? url : "https://\(url)")?.host,
                              host.lowercased().hasPrefix(typed) {
                        topSuggestion = host
                    } else {
                        topSuggestion = nil
                    }
                }
            }
        }
    }
}

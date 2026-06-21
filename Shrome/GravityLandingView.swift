//
//  GravityLandingView.swift
//  Shrome
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

    // `site.url` is stored as a bare host (e.g. "youtube.com"), so it can
    // be handed straight to the favicon service — same approach the
    // sidebar's tab rows already use for their favicons.
    private var faviconURL: URL? {
        guard !site.url.isEmpty else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?sz=128&domain=\(site.url)")
    }

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

                // Icon: the site's real favicon when it loads, falling back
                // to the tile's curated SF Symbol if the fetch fails — and,
                // in private sessions, skipping the network request
                // entirely so browsing intent never leaks via a favicon
                // lookup, using the symbol straight away instead.
                Group {
                    if isPrivateSession {
                        Image(systemName: site.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.purple)
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

    // Path to the user's chosen landing page background photo, set from
    // Preferences > Appearance. We cache the decoded NSImage in @State
    // (loaded on appear / whenever the path changes) instead of reading
    // it from disk on every body re-render.
    @AppStorage(BackgroundImageStore.appStorageKey) private var landingBackgroundImagePath: String = ""
    @State private var cachedBackgroundImage: NSImage? = nil

    // Drives the slow breathing pulse on the search bar's ambient glow —
    // toggled once on appear into a forever-repeating animation, so the
    // glow stays gently alive without ever being told to stop.
    @State private var isGlowPulsing = false

    // Set once via NameOnboardingView on first launch (or left blank if
    // the user skipped it) — falls back to a name-less greeting below.
    @AppStorage("userPreferredName") private var userPreferredName: String = ""

    @EnvironmentObject var tabManager: TabManager

    // --- Inline autocomplete ---
    @State private var topSuggestion: String? = nil
    @State private var debounceTask: Task<Void, Never>? = nil

    var accentColor: Color { Color(red: r, green: g, blue: b) }

    private var isPrivateSession: Bool {
        tabManager.activeTab.isPrivate
    }

    // Drives the readability boosts below — text shadow, vignette, and a
    // touch more glass tint — so none of it affects the default look when
    // there's no custom photo behind the page.
    private var hasBackgroundPhoto: Bool {
        cachedBackgroundImage != nil
    }

    private var dynamicGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: String
        if hour < 12 { timeOfDay = "Good morning" }
        else if hour < 17 { timeOfDay = "Good afternoon" }
        else { timeOfDay = "Good evening" }

        if isPrivateSession { return "\(timeOfDay), Stranger" }

        let trimmedName = userPreferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? timeOfDay : "\(timeOfDay), \(trimmedName)"
    }

    private var dynamicSubheader: String {
        if isPrivateSession {
            return "No one will know where we are sailing today."
        }
        return "Where are we sailing today?"
    }

    // --- REPLACE YOUR HARDCODED 'let favorites = [...]' BLOCK WITH THIS ---
    @AppStorage("customFavoritesJSON") private var customFavoritesJSON: String = """
    [
        {"name": "Apple", "url": "apple.com", "icon": "apple.logo"},
        {"name": "GitHub", "url": "github.com", "icon": "terminal.fill"},
        {"name": "YouTube", "url": "youtube.com", "icon": "play.rectangle.fill"},
        {"name": "Dribbble", "url": "dribbble.com", "icon": "paintpalette.fill"}
    ]
    """

    // A clean computed property to decode the active favorites list seamlessly
    private var favorites: [(name: String, url: String, icon: String)] {
        struct FavItem: Codable { let name: String; let url: String; let icon: String }
        guard let data = customFavoritesJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([FavItem].self, from: data) else { return [] }
        return decoded.map { ($0.name, $0.url, $0.icon) }
    }

    var body: some View {
        ZStack {
            // Custom background photo, if the user has set one in
            // Preferences > Appearance. Sits beneath everything else and
            // fills + crops to the available space.
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

            // Frosted glass wash — full strength over the default window
            // background, dialed back when a custom photo is set so the
            // photo stays visible while text on top stays legible.
            Color.clear
                .background(.ultraThinMaterial)
                .opacity(cachedBackgroundImage != nil ? 0.55 : 1.0)
                .ignoresSafeArea()

            // Soft vignette centered on the content column. Only kicks in
            // with a photo behind it — gives the greeting/search bar/tiles
            // a darker patch to sit on without flattening the whole photo
            // the way a full-screen scrim would.
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
                        .foregroundColor(accentColor)
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
                                .regular.tint(accentColor.opacity(hasBackgroundPhoto ? 0.10 : 0.06)),
                                in: Capsule()
                            )
                    }
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
                // Ambient glow — sits furthest back so it projects outward
                // beyond the capsule's own edges, in the active theme's
                // accent color. Two stacked blurs (tighter + much wider)
                // give it a softer falloff than a single blur would, and a
                // slow breathing pulse keeps it gently alive to draw the
                // eye without being distracting.
                .background {
                    ZStack {
                        Capsule()
                            .fill(accentColor)
                            .frame(width: 580, height: 64)
                            .blur(radius: 32)
                            .opacity(isGlowPulsing ? 0.30 : 0.18)

                        Capsule()
                            .fill(accentColor)
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

            // Liquid glass clock — floats independently of the centered
            // greeting/search column, top-right, roughly the footprint of
            // the Music widget in macOS Control Center.
            LiquidGlassClockPanel(hasBackgroundPhoto: hasBackgroundPhoto)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            cachedBackgroundImage = BackgroundImageStore.loadImage(at: landingBackgroundImagePath)
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                isGlowPulsing = true
            }
        }
        .onChange(of: landingBackgroundImagePath) { _, newPath in
            withAnimation(.shromeBouncy) {
                cachedBackgroundImage = BackgroundImageStore.loadImage(at: newPath)
            }
        }
        .onChange(of: urlString) { _, newValue in
            debounceTask?.cancel()
            guard !newValue.isEmpty else {
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

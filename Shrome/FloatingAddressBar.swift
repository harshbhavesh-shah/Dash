//
//  FloatingAddressBar.swift
//  Shrome
//

import SwiftUI

struct FloatingAddressBar: View {
    @Binding var urlString: String
    @ObservedObject var tabManager: TabManager
    var onSubmit: () -> Void

    @AppStorage("enableAddressBarTint") private var enableAddressBarTint: Bool = true
    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72

    @AppStorage("customFavoritesJSON") private var customFavoritesJSON: String = ""

    // PERF FIX: Cache the decoded favorites list in @State so JSON decoding
    // only runs when customFavoritesJSON actually changes — not on every render.
    // Previously getDecodedFavorites() was called from a computed property
    // (isCurrentPageFavorited) that ran on every body evaluation, meaning
    // JSONDecoder().decode(...) fired on every hover, URL change, and
    // animation tick that touched this view.
    @State private var cachedFavorites: [FavItem] = []

    var accentColor: Color { Color(red: r, green: g, blue: b) }
    private var isPrivate: Bool { tabManager.activeTab.isPrivate }

    // PERF FIX: Reads from the in-memory cache instead of decoding JSON.
    // O(n) scan over a tiny array is negligible; JSONDecoder on every render
    // was the expensive part.
    private var isCurrentPageFavorited: Bool {
        let currentHost = tabManager.activeTab.url.host ?? ""
        guard !currentHost.isEmpty,
              tabManager.activeTab.url.absoluteString != "about:blank" else { return false }
        return cachedFavorites.contains {
            $0.url.contains(currentHost) || currentHost.contains($0.url)
        }
    }

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: isPrivate ? "shield.fill" : "magnifyingglass")
                .font(.system(size: 13, weight: .black))
                .foregroundColor(isPrivate ? .purple : Color(NSColor.labelColor).opacity(0.65))

            TextField("Search or enter website", text: $urlString)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color(NSColor.labelColor))
                .onSubmit(onSubmit)

            Spacer()

            if isPrivate {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.purple.opacity(0.6))
            }

            if tabManager.activeTab.url.absoluteString != "about:blank" {
                Button(action: toggleFavoriteStatus) {
                    Image(systemName: isCurrentPageFavorited ? "heart.fill" : "heart")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(isCurrentPageFavorited ? .red : Color(NSColor.labelColor).opacity(0.6))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            Button(action: onSubmit) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(Color(NSColor.labelColor).opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 16)
        .frame(width: 550)
        .background {
            if enableAddressBarTint {
                Color.clear
                    .glassEffect(
                        .regular.tint(
                            isPrivate
                                ? Color.purple.opacity(0.12)
                                : Color.primary.opacity(0.04)
                        ),
                        in: Capsule()
                    )
            } else {
                Color.clear
                    .glassEffect(.regular, in: Capsule())
                    .background(Capsule().fill(Color(NSColor.controlBackgroundColor).opacity(0.45)))
            }
        }
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
        }
        .shadow(color: isPrivate ? .purple.opacity(0.1) : .black.opacity(0.05), radius: 12, x: 0, y: 6)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCurrentPageFavorited)
        // PERF FIX: Populate the cache once on appear, then only re-decode
        // when the raw JSON string actually changes. This replaces the old
        // pattern of decoding inside a computed property on every render.
        .onAppear {
            cachedFavorites = decodeFavorites(from: customFavoritesJSON)
        }
        .onChange(of: customFavoritesJSON) { _, newValue in
            cachedFavorites = decodeFavorites(from: newValue)
        }
    }

    // MARK: - Favorites Serialization

    struct FavItem: Codable { let name: String; let url: String; let icon: String }

    // Pure function — takes JSON string, returns decoded array.
    // Called only from onAppear and onChange, never from body.
    private func decodeFavorites(from json: String) -> [FavItem] {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([FavItem].self, from: data)
        else { return [] }
        return decoded
    }

    private func toggleFavoriteStatus() {
        let url = tabManager.activeTab.url
        guard let host = url.host, url.absoluteString != "about:blank" else { return }

        var currentList = cachedFavorites

        if isCurrentPageFavorited {
            currentList.removeAll { $0.url.contains(host) || host.contains($0.url) }
        } else {
            var iconName = "globe"
            if host.contains("github")                              { iconName = "terminal.fill" }
            else if host.contains("google")                         { iconName = "g.circle.fill" }
            else if host.contains("twitter") || host.contains("x.com") { iconName = "bird.fill" }

            let displayName = host
                .replacingOccurrences(of: "www.", with: "")
                .components(separatedBy: ".")
                .first?
                .capitalized ?? "Site"

            currentList.append(FavItem(name: displayName, url: host, icon: iconName))
        }

        if let encodedData = try? JSONEncoder().encode(currentList),
           let jsonString = String(data: encodedData, encoding: .utf8) {
            withAnimation(.spring()) {
                // Writing to @AppStorage triggers onChange above,
                // which updates cachedFavorites automatically.
                customFavoritesJSON = jsonString
            }
        }
    }
}

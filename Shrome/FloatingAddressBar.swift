//
//  FloatingAddressBar.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI
import AppKit

struct FloatingAddressBar: View {
    @Binding var urlString: String
    @ObservedObject var tabManager: TabManager
    var onSubmit: () -> Void

    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72
    @AppStorage("customFavoritesJSON") private var customFavoritesJSON: String = ShromeDefaults.favoritesJSON
    @AppStorage("searchSuggestions") private var searchSuggestions: Bool = true
    @State private var cachedFavorites: [FavItem] = []
    @State private var topSuggestion: String? = nil
    @State private var debounceTask: Task<Void, Never>? = nil

    var accentColor: Color { Color(red: r, green: g, blue: b) }
    private var isPrivate: Bool { tabManager.activeTab.isPrivate }

    /// What to show in the address bar when not being edited — just the
    /// host (e.g. "youtube.com") rather than the full URL with path and
    /// query parameters. nil when there's no valid URL to abbreviate (e.g.
    /// while the user is typing a search query before navigating).
    private var urlDisplayHost: String? {
        guard !urlString.isEmpty, urlString != "about:blank",
              !urlString.contains(" ") else { return nil }
        if let url = URL(string: urlString), let host = url.host {
            return host.replacingOccurrences(of: "www.", with: "")
        }
        return nil
    }

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
                .foregroundColor(isPrivate ? .shromePrivate : Color.primary.opacity(0.65))

            InlineCompleteTextField(
                text: $urlString,
                suggestion: topSuggestion,
                placeholder: "Search or enter website",
                font: .systemFont(ofSize: 14, weight: .medium), textColor: .labelColor, displayOverride: urlDisplayHost,
                onCommit: {
                    topSuggestion = nil
                    onSubmit()
                },
                onEscape: {
                    topSuggestion = nil
                }
            )

            Spacer()

            if isPrivate {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.shromePrivate.opacity(0.6))
            }

            if tabManager.activeTab.url.absoluteString != "about:blank" {
                Button(action: toggleFavoriteStatus) {
                    Image(systemName: isCurrentPageFavorited ? "heart.fill" : "heart")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(isCurrentPageFavorited ? .red : Color.primary.opacity(0.6))
                }
                .buttonStyle(.bouncy)
                .transition(.scale.combined(with: .opacity))
            }

            // BUG FIX: this was previously wired to `onSubmit`, which
            // re-runs the full "parse as URL or search query" pipeline on
            // whatever's in the address bar — it never actually reloaded
            // the page, and (before the history fix above) silently logged
            // a duplicate history entry every time it was pressed.
            Button(action: { tabManager.reloadActiveTab() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(Color.primary.opacity(0.6))
            }
            .buttonStyle(.bouncy)
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 16)
        .frame(width: 550)
        // BUG FIX: .glassEffect() was previously applied to an isolated
        // Color.clear view sitting in .background — a separate layer behind
        // the actual content, not integrated with it. Real vibrancy (the
        // thing that makes Safari's chrome auto-adjust to whatever's on the
        // page behind it) only kicks in when content is composited *inside*
        // the glass material itself. Applying .glassEffect directly to this
        // container, with content using vibrancy-aware colors (.primary,
        // .secondary, and AppKit's own .labelColor) instead of fixed
        // values, lets the system do that contrast blending natively —
        // no manual color-scheme branching or opaque scrim required.
        .glassEffect(
            isPrivate ? .regular.tint(Color.shromePrivate.opacity(0.15)) : .regular,
            in: Capsule()
        )
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
        }
        .shadow(color: isPrivate ? .shromePrivate.opacity(0.1) : .black.opacity(0.05), radius: 12, x: 0, y: 6)
        .animation(.shromePop, value: isCurrentPageFavorited)
        .onAppear {
            cachedFavorites = decodeFavorites(from: customFavoritesJSON)
        }
        .onDisappear {
            // BUG FIX: this Task wasn't tied to the view's lifecycle, so it
            // could keep running (and still write to state) even after this
            // address bar instance went away — e.g. during a fast tab switch.
            debounceTask?.cancel()
        }
        .onChange(of: customFavoritesJSON) { _, newValue in
            cachedFavorites = decodeFavorites(from: newValue)
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
                    // Only show a suggestion if the top result actually starts
                    // with what the user typed (so it makes sense as inline text).
                    let best = results.first
                    let typed = newValue.lowercased()
                    if let url = best?.url, url.lowercased().hasPrefix(typed) {
                        topSuggestion = url
                    } else if let url = best?.url,
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

    // MARK: - Favorites Serialization

    struct FavItem: Codable { let name: String; let url: String; let icon: String }

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
            if host.contains("github")                                  { iconName = "terminal.fill" }
            else if host.contains("google")                             { iconName = "g.circle.fill" }
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
            withAnimation(.shromeSnappy) {
                customFavoritesJSON = jsonString
            }
        }
    }
}

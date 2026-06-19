//
//  FloatingAddressBar.swift
//  Shrome
//

import SwiftUI

// MARK: - Shared Autocomplete Dropdown

/// A standalone dropdown that renders history suggestions beneath any address bar.
/// Both FloatingAddressBar and GravityLandingView use this so the UX is identical.
struct AutocompleteSuggestionList: View {
    let suggestions: [TabManager.URLSuggestion]
    let selectedIndex: Int?
    let onSelect: (TabManager.URLSuggestion) -> Void

    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72
    var accentColor: Color { Color(red: r, green: g, blue: b) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                SuggestionRow(
                    suggestion: suggestion,
                    isHighlighted: selectedIndex == index,
                    accentColor: accentColor,
                    onSelect: { onSelect(suggestion) }
                )
            }
        }
        .padding(.vertical, 6)
        .frame(width: 550)
        .background {
            Color.clear
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 8)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
            removal: .scale(scale: 0.96, anchor: .top).combined(with: .opacity)
        ))
    }
}

private struct SuggestionRow: View {
    let suggestion: TabManager.URLSuggestion
    let isHighlighted: Bool
    let accentColor: Color
    let onSelect: () -> Void

    @State private var isHovered = false

    // Pull just the host for the secondary label so long URLs stay readable.
    private var displayHost: String {
        URL(string: suggestion.url)?.host ?? suggestion.url
    }

    // Choose a sensible SF Symbol from the domain name.
    private var faviconURL: URL? {
        guard let host = URL(string: suggestion.url)?.host, !host.isEmpty else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(host)")
    }

    var body: some View {
        HStack(spacing: 12) {
            // Favicon
            AsyncImage(url: faviconURL) { phase in
                if let img = phase.image {
                    img.resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.system(size: 12))
                }
            }
            .frame(width: 16, height: 16)
            .cornerRadius(3)
            .id(URL(string: suggestion.url)?.host ?? suggestion.url)

            // Title + URL
            VStack(alignment: .leading, spacing: 1) {
                Text(suggestion.title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(displayHost)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.75))
                    .lineLimit(1)
            }

            Spacer()

            // Subtle arrow hint on hover/selection
            if isHovered || isHighlighted {
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHighlighted
                      ? accentColor.opacity(0.13)
                      : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
                .padding(.horizontal, 6)
        )
        .animation(.easeOut(duration: 0.12), value: isHighlighted)
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onSelect)
        .contentShape(Rectangle())
    }
}

// MARK: - Floating Address Bar

struct FloatingAddressBar: View {
    @Binding var urlString: String
    @ObservedObject var tabManager: TabManager
    var onSubmit: () -> Void

    @AppStorage("enableAddressBarTint") private var enableAddressBarTint: Bool = true
    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72

    @AppStorage("customFavoritesJSON") private var customFavoritesJSON: String = ""

    // PERF FIX: Cache the decoded favorites list so JSON decoding only runs
    // when customFavoritesJSON actually changes, not on every render.
    @State private var cachedFavorites: [FavItem] = []

    // --- Autocomplete state ---
    @State private var suggestions: [TabManager.URLSuggestion] = []
    @State private var selectedSuggestionIndex: Int? = nil
    @State private var isFocused: Bool = false
    @State private var debounceTask: Task<Void, Never>? = nil

    var accentColor: Color { Color(red: r, green: g, blue: b) }
    private var isPrivate: Bool { tabManager.activeTab.isPrivate }

    private var showSuggestions: Bool {
        isFocused && !suggestions.isEmpty && !urlString.isEmpty
    }

    // PERF FIX: Reads from the in-memory cache instead of decoding JSON.
    private var isCurrentPageFavorited: Bool {
        let currentHost = tabManager.activeTab.url.host ?? ""
        guard !currentHost.isEmpty,
              tabManager.activeTab.url.absoluteString != "about:blank" else { return false }
        return cachedFavorites.contains {
            $0.url.contains(currentHost) || currentHost.contains($0.url)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            // Suggestions appear ABOVE the address bar so they don't overlap
            // the bottom edge of the screen when the bar is near the bottom.
            if showSuggestions {
                AutocompleteSuggestionList(
                    suggestions: suggestions,
                    selectedIndex: selectedSuggestionIndex,
                    onSelect: { suggestion in
                        urlString = suggestion.url
                        dismissSuggestions()
                        onSubmit()
                    }
                )
            }

            // --- The bar itself ---
            HStack(spacing: 15) {
                Image(systemName: isPrivate ? "shield.fill" : "magnifyingglass")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(isPrivate ? .purple : Color(NSColor.labelColor).opacity(0.65))

                TextField("Search or enter website", text: $urlString)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color(NSColor.labelColor))
                    .onSubmit(commitAndDismiss)
                    // Track focus so we know when to show/hide the dropdown.
                    .onReceive(NotificationCenter.default.publisher(
                        for: NSTextField.textDidBeginEditingNotification)
                    ) { _ in isFocused = true }
                    .onReceive(NotificationCenter.default.publisher(
                        for: NSTextField.textDidEndEditingNotification)
                    ) { _ in
                        // Small delay so a tap on a suggestion row fires before
                        // we clear the list.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            dismissSuggestions()
                        }
                    }
                    // Keyboard navigation inside the dropdown.
                    .background(KeyEventInterceptor(
                        onArrowDown: selectNext,
                        onArrowUp: selectPrevious,
                        onEscape: { dismissSuggestions(); isFocused = false }
                    ))

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

                Button(action: commitAndDismiss) {
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
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: showSuggestions)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCurrentPageFavorited)
        .onAppear {
            cachedFavorites = decodeFavorites(from: customFavoritesJSON)
        }
        .onChange(of: customFavoritesJSON) { _, newValue in
            cachedFavorites = decodeFavorites(from: newValue)
        }
        // Debounce: wait 120ms after the last keystroke before hitting Core Data.
        .onChange(of: urlString) { _, newValue in
            debounceTask?.cancel()
            selectedSuggestionIndex = nil
            guard !newValue.isEmpty, isFocused else {
                suggestions = []
                return
            }
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled else { return }
                let results = await tabManager.fetchSuggestions(matching: newValue)
                await MainActor.run {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        suggestions = results
                    }
                }
            }
        }
    }

    // MARK: - Keyboard navigation

    private func selectNext() {
        guard !suggestions.isEmpty else { return }
        let next = (selectedSuggestionIndex ?? -1) + 1
        selectedSuggestionIndex = min(next, suggestions.count - 1)
        previewSelected()
    }

    private func selectPrevious() {
        guard let current = selectedSuggestionIndex else { return }
        selectedSuggestionIndex = current > 0 ? current - 1 : nil
        previewSelected()
    }

    private func previewSelected() {
        if let idx = selectedSuggestionIndex {
            urlString = suggestions[idx].url
        }
    }

    private func commitAndDismiss() {
        dismissSuggestions()
        onSubmit()
    }

    private func dismissSuggestions() {
        debounceTask?.cancel()
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            suggestions = []
        }
        selectedSuggestionIndex = nil
        isFocused = false
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
            withAnimation(.spring()) {
                customFavoritesJSON = jsonString
            }
        }
    }
}

// MARK: - Key Event Interceptor
//
// NSViewRepresentable shim that sits behind the TextField and captures
// ↑ ↓ Escape without swallowing printable characters or Tab.
// This is necessary because SwiftUI's .onKeyPress is macOS 14+ only and
// doesn't reach modifier-less arrow keys inside a TextField.

struct KeyEventInterceptor: NSViewRepresentable {
    var onArrowDown: () -> Void
    var onArrowUp: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> KeyCatcher {
        let v = KeyCatcher()
        v.onArrowDown = onArrowDown
        v.onArrowUp = onArrowUp
        v.onEscape = onEscape
        return v
    }

    func updateNSView(_ nsView: KeyCatcher, context: Context) {
        nsView.onArrowDown = onArrowDown
        nsView.onArrowUp = onArrowUp
        nsView.onEscape = onEscape
    }

    class KeyCatcher: NSView {
        var onArrowDown: (() -> Void)?
        var onArrowUp: (() -> Void)?
        var onEscape: (() -> Void)?

        override var acceptsFirstResponder: Bool { false }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 125: onArrowDown?()   // ↓
            case 126: onArrowUp?()     // ↑
            case 53:  onEscape?()      // Esc
            default:  super.keyDown(with: event)
            }
        }
    }
}

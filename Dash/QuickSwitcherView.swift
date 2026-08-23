//
//  QuickSwitcherView.swift
//  Dash
//

import SwiftUI

private struct QuickSwitchResult: Identifiable {
    enum Kind {
        case tab(UUID)
        case history(url: String)
    }
    let id = UUID()
    let title: String
    let subtitle: String
    let iconName: String
    let isPrivate: Bool
    let kind: Kind
}

struct QuickSwitcherView: View {
    @ObservedObject var tabManager: TabManager
    var onDismiss: () -> Void

    @State private var query: String = ""
    @State private var historyMatches: [TabManager.URLSuggestion] = []
    @State private var selectedIndex: Int = 0
    @State private var searchTask: Task<Void, Never>? = nil
    @FocusState private var isFocused: Bool

    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72
    private var accentColor: Color { Color(red: r, green: g, blue: b) }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Open tabs matching the query always come first (this is a "where did
    /// my tab go" tool first, an address bar second); history results fill
    /// in the rest, skipping URLs that are already open.
    private var results: [QuickSwitchResult] {
        let tabItems = tabManager.tabs
            .filter {
                trimmedQuery.isEmpty ||
                $0.title.localizedCaseInsensitiveContains(trimmedQuery) ||
                $0.urlString.localizedCaseInsensitiveContains(trimmedQuery)
            }
            .map { tab in
                QuickSwitchResult(
                    title: tab.title.isEmpty ? "New Tab" : tab.title,
                    subtitle: tab.url.host ?? tab.urlString,
                    iconName: "square.on.square",
                    isPrivate: tab.isPrivate,
                    kind: .tab(tab.id)
                )
            }

        guard !trimmedQuery.isEmpty else { return tabItems }

        let openURLs = Set(tabManager.tabs.map { $0.urlString })
        let historyItems = historyMatches
            .filter { !openURLs.contains($0.url) }
            .map { suggestion in
                QuickSwitchResult(
                    title: suggestion.title,
                    subtitle: suggestion.url,
                    iconName: "clock",
                    isPrivate: false,
                    kind: .history(url: suggestion.url)
                )
            }

        return Array((tabItems + historyItems).prefix(10))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor)

                    TextField("Search tabs and history", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .focused($isFocused)
                        .onChange(of: query) { _, newValue in
                            selectedIndex = 0
                            searchTask?.cancel()
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else {
                                historyMatches = []
                                return
                            }
                            searchTask = Task {
                                try? await Task.sleep(nanoseconds: 100_000_000)
                                guard !Task.isCancelled else { return }
                                let matches = await tabManager.fetchSuggestions(matching: trimmed)
                                await MainActor.run { historyMatches = matches }
                            }
                        }
                }
                .padding(16)

                Divider().opacity(0.15)

                if results.isEmpty {
                    Text("No matches")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 24)
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                                QuickSwitchRow(item: item, isSelected: index == selectedIndex, accentColor: accentColor)
                                    .contentShape(Rectangle())
                                    .onTapGesture { activate(item) }
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 320)
                }
            }
            .frame(width: 480)
            .background(Color(NSColor.windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.3), radius: 40, x: 0, y: 20)
            .onKeyPress(.downArrow) {
                if !results.isEmpty { selectedIndex = min(selectedIndex + 1, results.count - 1) }
                return .handled
            }
            .onKeyPress(.upArrow) {
                selectedIndex = max(selectedIndex - 1, 0)
                return .handled
            }
            .onKeyPress(.return) {
                if selectedIndex < results.count { activate(results[selectedIndex]) }
                return .handled
            }
        }
        .onExitCommand(perform: onDismiss)
        .onAppear { isFocused = true }
    }

    private func activate(_ item: QuickSwitchResult) {
        switch item.kind {
        case .tab(let id):
            tabManager.activeTabId = id
        case .history(let url):
            tabManager.updateActiveUrl(urlString: url)
        }
        onDismiss()
    }
}

private struct QuickSwitchRow: View {
    let item: QuickSwitchResult
    let isSelected: Bool
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isPrivate ? "shield.fill" : item.iconName)
                .font(.system(size: 12))
                .foregroundColor(item.isPrivate ? .dashPrivate : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isSelected ? accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(8)
    }
}

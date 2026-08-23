//
//  FindBarView.swift
//  Dash
//

import SwiftUI
import WebKit

struct FindBarView: View {
    let webView: WKWebView?
    var onClose: () -> Void

    @State private var query: String = ""
    @State private var noMatches: Bool = false
    @FocusState private var isFocused: Bool

    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72
    private var accentColor: Color { Color(red: r, green: g, blue: b) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            TextField("Find in page", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .frame(width: 160)
                .focused($isFocused)
                .onChange(of: query) { _, newValue in
                    performFind(newValue, backwards: false)
                }
                .onSubmit {
                    // Shift+Return searches backwards, matching the
                    // convention used by every other find-in-page bar.
                    performFind(query, backwards: NSEvent.modifierFlags.contains(.shift))
                }

            if !query.isEmpty && noMatches {
                Text("No results")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize()
            }

            Divider().frame(height: 14)

            Button(action: { performFind(query, backwards: true) }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.bouncy)
            .disabled(query.isEmpty)

            Button(action: { performFind(query, backwards: false) }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.bouncy)
            .disabled(query.isEmpty)

            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .buttonStyle(.bouncy)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(accentColor.opacity(0.06)), in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
        .onAppear { isFocused = true }
        .onExitCommand(perform: dismiss)
    }

    private func performFind(_ text: String, backwards: Bool) {
        guard let webView, !text.isEmpty else {
            noMatches = false
            return
        }
        let config = WKFindConfiguration()
        config.backwards = backwards
        config.caseSensitive = false
        config.wraps = true
        webView.find(text, configuration: config) { result in
            DispatchQueue.main.async {
                noMatches = !result.matchFound
            }
        }
    }

    private func dismiss() {
        // Best-effort: clears the highlighted matches on close.
        webView?.find("", configuration: WKFindConfiguration()) { _ in }
        onClose()
    }
}

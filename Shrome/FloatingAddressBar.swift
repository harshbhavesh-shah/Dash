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
    
    // Connect to the persistent favorites dictionary registry
    @AppStorage("customFavoritesJSON") private var customFavoritesJSON: String = ""
    
    var accentColor: Color { Color(red: r, green: g, blue: b) }
    private var isPrivate: Bool { tabManager.activeTab.isPrivate }

    // Interrogate the serialized data registry to map favorited states
    private var isCurrentPageFavorited: Bool {
        let currentHost = tabManager.activeTab.url.host ?? ""
        if currentHost.isEmpty || tabManager.activeTab.url.absoluteString == "about:blank" { return false }
        return getDecodedFavorites().contains { $0.url.contains(currentHost) || currentHost.contains($0.url) }
    }

    var body: some View {
        HStack(spacing: 15) {
            // LAYER A: LEADING SEARCH ENGINE INDICATOR GLYPH
            Image(systemName: isPrivate ? "shield.fill" : "magnifyingglass")
                .font(.system(size: 13, weight: .black))
                .foregroundColor(isPrivate ? .purple : Color(NSColor.labelColor).opacity(0.65))
            
            // LAYER B: MAIN COMPACT INPUT LAYER
            TextField("Search or enter website", text: $urlString)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(Color(NSColor.labelColor)) // Anchors adaptive contrast levels
                .onSubmit(onSubmit)
            
            Spacer()
            
            // LAYER C: CORE PRIVACY SHIELD BADGING
            if isPrivate {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.purple.opacity(0.6))
            }
            
            // LAYER D: DYNAMIC HEART BOOKMARK TOGGLE SWITCH
            if tabManager.activeTab.url.absoluteString != "about:blank" {
                Button(action: toggleFavoriteStatus) {
                    Image(systemName: isCurrentPageFavorited ? "heart.fill" : "heart")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(isCurrentPageFavorited ? .red : Color(NSColor.labelColor).opacity(0.6))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
            
            // LAYER E: ENGINE REFRESH LOOP RELOAD TERMINAL
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
        // --- OPTION 1: PREMIUM MATERIAL FILTER AND BOUNDARY MATRIX ---
        .background {
            if enableAddressBarTint {
                Color.clear
                    .glassEffect(
                        .regular.tint(
                            isPrivate
                                ? Color.purple.opacity(0.12)
                                : Color.primary.opacity(0.04) // Safe protection over white content canvases
                        ),
                        in: Capsule()
                    )
            } else {
                Color.clear
                    .glassEffect(.regular, in: Capsule())
                    .background(Capsule().fill(Color(NSColor.controlBackgroundColor).opacity(0.45)))
            }
        }
        // Micro-edge line divider vectors prevent the bar shape from melting into matching background color sets
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
        }
        .shadow(color: isPrivate ? .purple.opacity(0.1) : .black.opacity(0.05), radius: 12, x: 0, y: 6)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCurrentPageFavorited)
    }
    
    // MARK: - Core Favorites Serialization Mechanics
    
    struct FavItem: Codable { let name: String; let url: String; let icon: String }
    
    private func getDecodedFavorites() -> [FavItem] {
        guard let data = customFavoritesJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([FavItem].self, from: data) else { return [] }
        return decoded
    }
    
    private func toggleFavoriteStatus() {
        let url = tabManager.activeTab.url
        guard let host = url.host, url.absoluteString != "about:blank" else { return }
        
        var currentList = getDecodedFavorites()
        
        if isCurrentPageFavorited {
            currentList.removeAll { $0.url.contains(host) || host.contains($0.url) }
        } else {
            var iconName = "globe"
            if host.contains("github") { iconName = "terminal.fill" }
            else if host.contains("google") { iconName = "g.circle.fill" }
            else if host.contains("twitter") || host.contains("x.com") { iconName = "bird.fill" }
            
            let displayName = host.replacingOccurrences(of: "www.", with: "").components(separatedBy: ".").first?.capitalized ?? "Site"
            
            let newItem = FavItem(name: displayName, url: host, icon: iconName)
            currentList.append(newItem)
        }
        
        if let encodedData = try? JSONEncoder().encode(currentList),
           let jsonString = String(data: encodedData, encoding: .utf8) {
            withAnimation(.spring()) {
                customFavoritesJSON = jsonString
            }
        }
    }
}

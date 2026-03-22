//
//  FloatingAddressBar.swift
//  Shrome
//

import SwiftUI

struct FloatingAddressBar: View {
    @Binding var urlString: String
    @ObservedObject var tabManager: TabManager // NEW: Need access to the tab state
    var onSubmit: () -> Void
    
    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72
    
    var accentColor: Color { Color(red: r, green: g, blue: b) }
    
    // Check if we are in stealth mode
    private var isPrivate: Bool { tabManager.activeTab.isPrivate }

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: isPrivate ? "shield.fill" : "magnifyingglass")
                .font(.system(size: 13, weight: .black))
                .foregroundColor(isPrivate ? .purple : .secondary)
            
            TextField("Search or enter website", text: $urlString)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .onSubmit(onSubmit)
            
            Spacer()
            
            if isPrivate {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.purple.opacity(0.6))
            }
            
            Button(action: onSubmit) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 16)
        .frame(width: 550)
        .background(
            ZStack {
                LiquidGlass()
                
                // The Privacy Tint
                if isPrivate {
                    Color.purple.opacity(0.08)
                }

                // Polished Specular Rim with Dynamic Color
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.7),
                                isPrivate ? .purple.opacity(0.5) : accentColor.opacity(0.35),
                                .clear,
                                isPrivate ? .indigo.opacity(0.3) : accentColor.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
        )
        .clipShape(Capsule())
        // Purple "Privacy Glow" shadow
        .shadow(color: isPrivate ? .purple.opacity(0.12) : .black.opacity(0.06), radius: 10, x: 0, y: 5)
    }
}

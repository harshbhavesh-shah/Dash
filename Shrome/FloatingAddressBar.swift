//
//  FloatingAddressBar.swift
//  Shrome
//

import SwiftUI

struct FloatingAddressBar: View {
    @Binding var urlString: String
    @ObservedObject var tabManager: TabManager
    var onSubmit: () -> Void
    
    // Listen to the preference toggle we just created
    @AppStorage("enableAddressBarTint") private var enableAddressBarTint: Bool = true
    
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
        // --- DYNAMIC LIQUID GLASS CONTROLLER ---
        .background {
            if enableAddressBarTint {
                // If tint is enabled, pass our ultra-faint calibrated profile into the native layer
                Color.clear
                    .glassEffect(
                        .regular.tint(isPrivate ? Color.purple.opacity(0.12) : accentColor.opacity(0.15)),
                        in: Capsule()
                    )
            } else {
                // If turned off, give us pure, crystalline unobstructed Apple system glass
                Color.clear
                    .glassEffect(in: Capsule())
            }
        }
        .shadow(color: isPrivate ? .purple.opacity(0.12) : .black.opacity(0.08), radius: 15, x: 0, y: 8)
    }
}

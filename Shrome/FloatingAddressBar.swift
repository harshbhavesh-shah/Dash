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
    
    var accentColor: Color { Color(red: r, green: g, blue: b) }
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
        // --- FIXED: Permanent Native Liquid Glass implementation ---
        .background {
            if enableAddressBarTint {
                Color.clear
                    .glassEffect(
                        .regular.tint(isPrivate ? Color.purple.opacity(0.12) : accentColor.opacity(0.15)),
                        in: Capsule()
                    )
            } else {
                Color.clear
                    .glassEffect(in: Capsule())
            }
        }
        .shadow(color: isPrivate ? .purple.opacity(0.1) : .black.opacity(0.06), radius: 15, x: 0, y: 8)
    }
}

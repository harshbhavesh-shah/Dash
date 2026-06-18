//
//  SidebarView.swift
//  Shrome
//
//  Created by Harsh Shah on 07/03/2026.
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var tabManager: TabManager
    @Binding var isVisible: Bool

    // --- FIXED: Bind directly to the user's preferred sidebar width ---
    @AppStorage("sidebarWidth") private var sidebarWidth: Double = 260
    
    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72
    
    var accentColor: Color { Color(red: r, green: g, blue: b) }

    var body: some View {
        HStack(spacing: 0) {
            // --- THE CONTROL STRIP ---
            VStack(spacing: 25) {
                DynamicTrafficLights(isVertical: !isVisible)
                    .frame(width: isVisible ? 80 : 55)
                    .padding(.top, 30)
                
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isVisible.toggle()
                    }
                }) {
                    Image(systemName: isVisible ? "sidebar.left" : "sidebar.right")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.primary.opacity(0.6)) // Adaptive
                        .frame(width: isVisible ? 80 : 55, height: 35)
                }
                .buttonStyle(.plain)
                
                Button(action: { tabManager.createNewTab() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(accentColor)
                        .shadow(color: accentColor.opacity(0.5), radius: 8)
                        .frame(width: isVisible ? 80 : 55)
                }
                .buttonStyle(.plain)
                
                // --- COMPACT COLLAPSED DECK ELEMENT ---
                // Slides neatly below your creation button when the sidebar collapses down
                if !isVisible {
                    Spacer().frame(height: 10)
                    
                    CollapsedSidebarGroupsDeck(tabManager: tabManager)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
            }
            .frame(width: isVisible ? 80 : 55)
            
            // --- THE TAB DRAWER ---
            if isVisible {
                tabContent
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .polishedGlassAesthetic()
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(.vertical, 16)
        .padding(.leading, 16)
        // Apply the dynamic width frame to the entire container when open
        .frame(width: isVisible ? CGFloat(sidebarWidth) : 55)
    }
    
    private var tabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // SECTOR A: UNASSIGNED STANDARD FLAT ACTIVE LIST
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TABS")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.primary.opacity(0.4))
                            .padding(.leading, 12)
                        
                        // Filters out items that are already managed inside group decks
                        let unassignedTabs = tabManager.tabs.filter { $0.groupId == nil }
                        
                        if unassignedTabs.isEmpty {
                            Text("No unassigned tabs")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.4))
                                .padding(.leading, 12)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(unassignedTabs) { tab in
                                TabRow(tabManager: tabManager, tab: tab, isActive: tabManager.activeTabId == tab.id) {
                                    withAnimation(.spring()) {
                                        tabManager.closeTab(id: tab.id)
                                    }
                                }
                                .onTapGesture {
                                    withAnimation(.snappy) {
                                        tabManager.activeTabId = tab.id
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider().opacity(0.1).padding(.horizontal, 10)
                    
                    // --- NESTED EXTENDED OPEN GROUPS DECK VIEW ---
                    OpenSidebarGroupsDeck(tabManager: tabManager)
                }
                .padding(.horizontal, 10)
                .padding(.top, 34)
            }
        }
        .frame(width: max(0, CGFloat(sidebarWidth) - 80))
    }
}

// --- TAB ROW ---
struct TabRow: View {
    @ObservedObject var tabManager: TabManager
    let tab: Tab
    let isActive: Bool
    var onClose: () -> Void
    
    @State private var isHovered = false
    
    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72
    
    var accentColor: Color { Color(red: r, green: g, blue: b) }
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(tab.url.host ?? "")")) { phase in
                if let image = phase.image {
                    image.resizable()
                } else {
                    Image(systemName: "globe")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 18, height: 18)
            .cornerRadius(4)
            
            Text(tab.url.host ?? "New Tab")
                .font(.system(size: 12, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? .primary : .primary.opacity(0.7)) // Adaptive
                .lineLimit(1)
            
            Spacer()
            
            ZStack {
                if isHovered {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.primary.opacity(0.3)) // Adaptive
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                } else if isActive {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: accentColor, radius: 4)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            ZStack {
                if isActive {
                    Color.primary.opacity(0.1)
                } else if isHovered {
                    Color.primary.opacity(0.05)
                }
            }
        )
        .cornerRadius(14)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
        .contentShape(Rectangle())
        // --- DYNAMIC CONTEXT ROUTING MATRIX ---
        .contextMenu {
            Menu("Move Tab to Group") {
                Button("Unassigned (General)") {
                    if let idx = tabManager.tabs.firstIndex(where: { $0.id == tab.id }) {
                        tabManager.tabs[idx].groupId = nil
                        tabManager.saveSession()
                    }
                }
                
                Divider()
                
                ForEach(tabManager.groups) { group in
                    Button(action: {
                        if let idx = tabManager.tabs.firstIndex(where: { $0.id == tab.id }) {
                            tabManager.tabs[idx].groupId = group.id
                            tabManager.saveSession()
                        }
                    }) {
                        Label(group.name, systemImage: group.icon)
                    }
                }
            }
            
            Button("Close Tab", role: .destructive) {
                tabManager.closeTab(id: tab.id)
            }
        }
    }
}

// --- DYNAMIC TRAFFIC LIGHTS ---
struct DynamicTrafficLights: View {
    let isVertical: Bool
    
    let closeColor = Color(red: 255/255, green: 95/255, blue: 86/255)
    let minColor = Color(red: 255/255, green: 189/255, blue: 46/255)
    let maxColor = Color(red: 39/255, green: 201/255, blue: 63/255)

    var body: some View {
        let layout = isVertical ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        
        layout {
            CircleButton(color: closeColor, iconName: "xmark") { NSApplication.shared.keyWindow?.close() }
            CircleButton(color: minColor, iconName: "minus") { NSApplication.shared.keyWindow?.miniaturize(nil) }
            CircleButton(color: maxColor, iconName: "plus") { NSApplication.shared.keyWindow?.toggleFullScreen(nil) }
        }
    }
}

struct CircleButton: View {
    let color: Color
    let iconName: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isHovered ? color.opacity(0.9) : color)
            
            Image(systemName: iconName)
                .font(.system(size: 6, weight: .black))
                .foregroundColor(.black.opacity(0.5))
                .opacity(isHovered ? 1.0 : 0.0)
        }
        .frame(width: 12, height: 12)
        .scaleEffect(isHovered ? 1.25 : 1.0)
        .shadow(color: color.opacity(isHovered ? 0.6 : 0), radius: isHovered ? 6 : 0, x: 0, y: 2)
        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
        .onTapGesture(perform: action)
    }
}

//
//  SidebarView.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var tabManager: TabManager
    @Binding var isVisible: Bool

    private let sidebarWidth: CGFloat = 260

    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72
    @Environment(\.isPrivateWindow) private var isPrivateWindow

    var accentColor: Color { Color(red: r, green: g, blue: b) }

    var body: some View {
        HStack(spacing: 0) {
            // --- THE CONTROL STRIP ---
            VStack(spacing: 25) {
                DynamicTrafficLights(isVertical: !isVisible)
                    .frame(width: isVisible ? 80 : 55)
                    .padding(.top, 30)

                Button(action: {
                    withAnimation(.shromeSnappy) {
                        isVisible.toggle()
                    }
                }) {
                    Image(systemName: isVisible ? "sidebar.left" : "sidebar.right")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.primary.opacity(0.6))
                        .frame(width: isVisible ? 80 : 55, height: 35)
                }
                .buttonStyle(.bouncy)

                Button(action: {
                    withAnimation(.shromeBouncy) {                        tabManager.createNewTab(isPrivate: isPrivateWindow)
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(isPrivateWindow ? .shromePrivate : accentColor)
                        .shadow(color: (isPrivateWindow ? Color.shromePrivate : accentColor).opacity(0.5), radius: 8)
                        .frame(width: isVisible ? 80 : 55)
                }
                .buttonStyle(.bouncy)

                if !isVisible {
                    Spacer().frame(height: 10)
                    CollapsedSidebarGroupsDeck(tabManager: tabManager)
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()
            }
            .frame(width: isVisible ? 80 : 55)

            if isVisible {
                tabContent
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .polishedGlassAesthetic()
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(.vertical, 16)
        .padding(.leading, 16)
        .frame(width: isVisible ? sidebarWidth : 55)
    }

    private var tabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // SECTOR A: UNASSIGNED TABS
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TABS")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.primary.opacity(0.4))
                            .padding(.leading, 12)

                        let unassignedTabs = tabManager.tabs.filter { $0.groupId == nil }

                        if unassignedTabs.isEmpty {
                            Text("No unassigned tabs")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.4))
                                .padding(.leading, 12)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(unassignedTabs) { tab in
                                TabRow(
                                    tab: tab,
                                    isActive: tabManager.activeTabId == tab.id,
                                    groups: tabManager.groups,
                                    onActivate: {
                                        withAnimation(.shromeSnappy) {
                                            tabManager.activeTabId = tab.id
                                        }
                                    },
                                    onClose: {
                                        withAnimation(.shromeSnappy) {
                                            tabManager.closeTab(id: tab.id)
                                        }
                                    },
                                    onMoveToGroup: { groupId in
                                        if let idx = tabManager.tabs.firstIndex(where: { $0.id == tab.id }) {
                                            withAnimation(.shromeSnappy) {
                                                tabManager.tabs[idx].groupId = groupId
                                            }
                                            tabManager.saveSession()
                                        }
                                    }
                                )
                            }
                        }
                    }

                    Divider().opacity(0.1).padding(.horizontal, 10)

                    OpenSidebarGroupsDeck(tabManager: tabManager)
                }
                .padding(.horizontal, 10)
                .padding(.top, 34)
            }
        }
        .frame(width: max(0, sidebarWidth - 80))
    }
}

// MARK: - Tab Row

struct TabRow: View {
    let tab: Tab
    let isActive: Bool
    let groups: [TabGroup]
    var onActivate: () -> Void
    var onClose: () -> Void
    var onMoveToGroup: (UUID?) -> Void

    @State private var isHovered = false

    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72

    var accentColor: Color { Color(red: r, green: g, blue: b) }

    private var faviconURL: URL? {
        guard let host = tab.url.host, !host.isEmpty else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(host)")
    }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: faviconURL) { phase in
                if let image = phase.image {
                    image.resizable()
                } else {
                    Image(systemName: "globe")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 18, height: 18)
            .cornerRadius(4)
            .id(tab.url.host ?? "blank")

            Text(tab.url.host ?? "New Tab")
                .font(.system(size: 12, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? .primary : .primary.opacity(0.7))
                .lineLimit(1)

            Spacer()

            ZStack {
                if isHovered {
                    Button(action: {
                        ShromeHaptics.confirmationTap()
                        onClose()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.primary.opacity(0.3))
                    }
                    .buttonStyle(.bouncy)
                    .transition(.scale.combined(with: .opacity))
                } else if isActive {
                    Circle()
                        .fill(tab.isPrivate ? .shromePrivate : accentColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: tab.isPrivate ? .shromePrivate : accentColor, radius: 4)
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
        .scaleEffect(isHovered ? 1.035 : 1.0)
        .animation(.shromeSnappy, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onActivate)
        .contextMenu {
            Menu("Move Tab to Group") {
                Button("Unassigned (General)") {
                    onMoveToGroup(nil)
                }

                Divider()
                ForEach(groups) { group in
                    Button(action: { onMoveToGroup(group.id) }) {
                        Label(group.name, systemImage: group.icon)
                    }
                }
            }

            Button("Close Tab", role: .destructive, action: onClose)
        }
    }
}

// MARK: - Dynamic Traffic Lights

struct DynamicTrafficLights: View {
    let isVertical: Bool

    let closeColor = Color(red: 255/255, green: 95/255, blue: 86/255)
    let minColor   = Color(red: 255/255, green: 189/255, blue: 46/255)
    let maxColor   = Color(red: 39/255,  green: 201/255, blue: 63/255)

    var body: some View {
        if isVertical {
            VStack(spacing: 8) { buttons }
        } else {
            HStack(spacing: 8) { buttons }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        CircleButton(color: closeColor, iconName: "xmark") {
            NSApplication.shared.keyWindow?.close()
        }
        CircleButton(color: minColor, iconName: "minus") {
            NSApplication.shared.keyWindow?.miniaturize(nil)
        }
        CircleButton(color: maxColor, iconName: "plus") {
            NSApplication.shared.keyWindow?.toggleFullScreen(nil)
        }
    }
}

// MARK: - Circle Button

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
        .animation(.shromePop, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
        .onTapGesture(perform: action)
    }
}

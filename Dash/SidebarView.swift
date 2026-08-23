//
//  SidebarView.swift
//  Dash
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
                    withAnimation(.dashSnappy) {
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
                    withAnimation(.dashBouncy) {                        tabManager.createNewTab(isPrivate: isPrivateWindow)
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(isPrivateWindow ? .dashPrivate : accentColor)
                        .shadow(color: (isPrivateWindow ? Color.dashPrivate : accentColor).opacity(0.5), radius: 8)
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
        // BUG FIX: without a bounded height here, this view (and everything
        // inside it, including tabContent's ScrollView) just sized itself to
        // fit its own content — a ScrollView needs a *bounded* parent height
        // to actually clip and scroll, otherwise it reports its full content
        // height upward and nothing scrolls. That's why adding tabs pushed
        // the tab-groups deck down and eventually off the top/bottom of the
        // window instead of scrolling. Filling the available height here
        // lets tabContent split that fixed height between a flexible scroll
        // region and a fixed-size groups deck pinned at the bottom.
        .frame(maxHeight: .infinity)
    }

    // BUG FIX: the tab-groups deck used to live inside the same ScrollView
    // as the pinned/unassigned tabs, and that whole VStack had no bounded
    // height (see the fix on the outer body above) — so it just grew
    // forever, pushing the groups deck down and eventually off-screen as
    // more tabs were added instead of scrolling. Splitting the groups deck
    // out as a fixed-size sibling *below* the ScrollView (rather than
    // inside it) makes it a non-flexible footer: SwiftUI gives it its
    // natural size first and lets the ScrollView above absorb whatever
    // space is left, scrolling internally once the tab list no longer
    // fits — so the groups deck now stays pinned at the bottom instead of
    // being pushed away.
    private var tabContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // SECTOR A0: PINNED TABS
                    let pinnedTabs = tabManager.tabs.filter { $0.isPinned }
                    if !pinnedTabs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PINNED")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.primary.opacity(0.4))
                                .padding(.leading, 12)

                            ForEach(pinnedTabs) { tab in
                                tabRow(for: tab)
                            }
                        }
                    }

                    // SECTOR A: UNASSIGNED TABS
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TABS")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.primary.opacity(0.4))
                            .padding(.leading, 12)

                        let unassignedTabs = tabManager.tabs.filter { $0.groupId == nil && !$0.isPinned }

                        if unassignedTabs.isEmpty {
                            Text("No unassigned tabs")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary.opacity(0.4))
                                .padding(.leading, 12)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(unassignedTabs) { tab in
                                tabRow(for: tab)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 34)
                .padding(.bottom, 12)
            }

            Divider().opacity(0.1).padding(.horizontal, 10)

            OpenSidebarGroupsDeck(tabManager: tabManager)
                .padding(.horizontal, 10)
                .padding(.top, 12)
                .padding(.bottom, 16)
        }
        .frame(width: max(0, sidebarWidth - 80))
        .frame(maxHeight: .infinity)
    }

    private func tabRow(for tab: Tab) -> some View {
        TabRow(
            tab: tab,
            isActive: tabManager.activeTabId == tab.id,
            groups: tabManager.groups,
            onActivate: {
                withAnimation(.dashSnappy) {
                    tabManager.activeTabId = tab.id
                }
            },
            onClose: {
                withAnimation(.dashSnappy) {
                    tabManager.closeTab(id: tab.id)
                }
            },
            onMoveToGroup: { groupId in
                if let idx = tabManager.tabs.firstIndex(where: { $0.id == tab.id }) {
                    withAnimation(.dashSnappy) {
                        tabManager.tabs[idx].groupId = groupId
                    }
                    tabManager.saveSession()
                }
            },
            onTogglePin: {
                withAnimation(.dashSnappy) {
                    tabManager.togglePin(id: tab.id)
                }
            }
        )
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
    var onTogglePin: () -> Void

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
                        DashHaptics.confirmationTap()
                        onClose()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.primary.opacity(0.3))
                    }
                    .buttonStyle(.bouncy)
                    .transition(.scale.combined(with: .opacity))
                } else if tab.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.primary.opacity(0.35))
                } else if isActive {
                    Circle()
                        .fill(tab.isPrivate ? .dashPrivate : accentColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: tab.isPrivate ? .dashPrivate : accentColor, radius: 4)
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
        // BUG FIX: `.contentShape` + `.onHover` used to sit *after*
        // `.scaleEffect`, so the hover hit-test region was the animated,
        // growing/shrinking geometry itself. As the (underdamped, slightly
        // overshooting) spring grew this row on hover, its edge swept past
        // the mouse, ending hover, which shrank it back, which re-entered
        // hover, which grew it again — a self-sustaining oscillation that
        // fired push/pop dozens of times a second and made the cursor
        // visibly stutter between arrow and pointing-hand. Fixing the hit
        // region to the pre-scale geometry (by hoisting these two above
        // `.scaleEffect`) makes hover state stable regardless of the
        // decorative scale animation.
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            // BUG FIX: `.push()`/`.pop()` is a stack that requires every
            // push to be matched by exactly one pop. Clicking this row's
            // close button while hovering removes the Tab from the array,
            // which destroys this view immediately — the `onHover(false)`
            // that would fire `.pop()` never runs, so the pushed cursor is
            // orphaned on the stack permanently. Repeat that a few times in
            // a session and later, unrelated `.pop()` calls elsewhere start
            // popping the wrong layer, producing cursor state that looks
            // "random." `.set()` is idempotent — no stack, no orphaning.
            (hovering ? NSCursor.pointingHand : NSCursor.arrow).set()
        }
        .scaleEffect(isHovered ? 1.035 : 1.0)
        .animation(.dashSnappy, value: isHovered)
        .onTapGesture(perform: onActivate)
        .contextMenu {
            Button(action: onTogglePin) {
                Label(tab.isPinned ? "Unpin Tab" : "Pin Tab", systemImage: tab.isPinned ? "pin.slash" : "pin")
            }

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
        // BUG FIX: see TabRow above — same self-induced hover-oscillation
        // and cursor-stack-orphaning bugs (this button growing under the
        // cursor as it scales, plus stacked push/pop). Fixed the same way:
        // a stable pre-scale hit region, and `.set()` instead of push/pop.
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            (hovering ? NSCursor.pointingHand : NSCursor.arrow).set()
        }
        .scaleEffect(isHovered ? 1.25 : 1.0)
        .shadow(color: color.opacity(isHovered ? 0.6 : 0), radius: isHovered ? 6 : 0, x: 0, y: 2)
        .animation(.dashPop, value: isHovered)
        .onTapGesture(perform: action)
    }
}

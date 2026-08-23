//
//  TabGroupsDeckView.swift
//  Dash
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI

// MARK: - EXTENDED OPEN SIDEBAR VIEW COMPONENT
struct OpenSidebarGroupsDeck: View {
    @ObservedObject var tabManager: TabManager
    @State private var expandedGroups: Set<UUID> = []
    @Environment(\.isPrivateWindow) private var isPrivateWindow

    @State private var showCreationPopover = false
    @State private var newGroupName = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColorName = "Rose"
    
    let availableIcons = ["folder.fill", "briefcase.fill", "person.fill", "gamecontroller.fill", "book.fill", "bookmark.fill", "heart.fill", "star.fill"]
    let availableColors = ["Rose", "Sage", "Peach", "Lilac", "Sky"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TAB GROUPS")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.leading, 12)
            
            ForEach(tabManager.groups) { group in
                let isExpanded = expandedGroups.contains(group.id)
                let groupTabs = tabManager.tabs.filter { $0.groupId == group.id }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Group Header Row
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: group.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(getGroupColor(group.colorName))
                            
                            Text(group.name)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                            
                            Text("\(groupTabs.count)")
                                .font(.system(size: 10, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            if isExpanded { expandedGroups.remove(group.id) }
                            else { expandedGroups.insert(group.id) }
                        }
                    }
                    .contextMenu {
                        Button("Add New Tab to \(group.name)") {
                            tabManager.createNewTab(isPrivate: isPrivateWindow, targetGroupId: group.id)
                        }
                    }
                    
                    if isExpanded {
                        VStack(spacing: 2) {
                            if groupTabs.isEmpty {
                                Text("No tabs in this group")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(.leading, 32)
                                    .padding(.vertical, 4)
                            } else {
                                ForEach(groupTabs) { tab in
                                    HStack {
                                        Image(systemName: "globe")
                                            .font(.system(size: 11))
                                            .foregroundColor(tabManager.activeTabId == tab.id ? getGroupColor(group.colorName) : .secondary)
                                        
                                        Text(tab.title.isEmpty ? "New Tab" : tab.title)
                                            .font(.system(size: 12, weight: tabManager.activeTabId == tab.id ? .semibold : .medium, design: .rounded))
                                            .lineLimit(1)
                                        
                                        Spacer()
                                    }
                                    .padding(.leading, 32)
                                    .padding(.trailing, 12)
                                    .padding(.vertical, 6)
                                    .background(tabManager.activeTabId == tab.id ? Color.primary.opacity(0.05) : Color.clear)
                                    .cornerRadius(6)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        tabManager.activeTabId = tab.id
                                    }
                                }
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }
            
            Button(action: { showCreationPopover = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 12, weight: .semibold))
                    Text("New Group")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showCreationPopover, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Create Tab Group")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    
                    TextField("Group Name...", text: $newGroupName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    
                    Text("Icon")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.system(size: 12))
                                .foregroundColor(selectedIcon == icon ? .primary : .secondary)
                                .frame(width: 24, height: 24)
                                .background(selectedIcon == icon ? Color.primary.opacity(0.1) : Color.clear)
                                .cornerRadius(6)
                                .onTapGesture { selectedIcon = icon }
                        }
                    }
                    
                    Text("Color Accent")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    HStack(spacing: 10) {
                        ForEach(availableColors, id: \.self) { colorName in
                            Circle()
                                .fill(getGroupColor(colorName))
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColorName == colorName ? 1.5 : 0)
                                        .frame(width: 22, height: 22)
                                )
                                .onTapGesture { selectedColorName = colorName }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Button(action: {
                        if !newGroupName.trimmingCharacters(in: .whitespaces).isEmpty {
                            tabManager.createCustomGroup(name: newGroupName, icon: selectedIcon, colorName: selectedColorName)
                            newGroupName = ""
                            showCreationPopover = false
                        }
                    }) {
                        Text("Create Group")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.small)
                }
                .padding(14)
                .frame(width: 260)
            }
        }
    }
}

// MARK: - COMPACT COLLAPSED SIDEBAR VIEW COMPONENT
struct CollapsedSidebarGroupsDeck: View {
    @ObservedObject var tabManager: TabManager
    @Environment(\.isPrivateWindow) private var isPrivateWindow

    var body: some View {
        VStack(spacing: 12) {
            ForEach(tabManager.groups) { group in
                let groupTabs = tabManager.tabs.filter { $0.groupId == group.id }
                let isCurrentlyActiveGroup = groupTabs.contains { $0.id == tabManager.activeTabId }
                
                ZStack {
                    Circle()
                        .fill(getGroupColor(group.colorName).opacity(isCurrentlyActiveGroup ? 0.2 : 0.06))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: group.icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(getGroupColor(group.colorName))
                    
                    if !groupTabs.isEmpty {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 5, height: 5)
                            .offset(x: 10, y: -10)
                    }
                }
                .help("\(group.name) (\(groupTabs.count) tabs)")
                .contentShape(Rectangle())
                .onTapGesture {
                    if let firstTab = groupTabs.first {
                        tabManager.activeTabId = firstTab.id
                    } else {
                        tabManager.createNewTab(isPrivate: isPrivateWindow, targetGroupId: group.id)
                    }
                }
            }
        }
    }
}

func getGroupColor(_ name: String) -> Color {
    switch name {
    case "Rose":  return Color(red: 0.96, green: 0.55, blue: 0.72)
    case "Sage":  return Color(red: 0.3,  green: 0.85, blue: 0.5)
    case "Peach": return Color(red: 1.0,  green: 0.55, blue: 0.25)
    case "Lilac": return Color(red: 0.75, green: 0.35, blue: 1.0)
    case "Sky":   return Color(red: 0.2,  green: 0.75, blue: 1.0)
    default:      return .purple
    }
}

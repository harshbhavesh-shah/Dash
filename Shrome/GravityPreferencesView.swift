//
//  GravityPreferencesView.swift
//  Shrome
//

import SwiftUI
import Combine

// --- STARTUP BEHAVIOR ENUM ---
enum StartupBehavior: String, CaseIterable {
    case leftOff = "Continue where I left off"
    case firstGroupTab = "First tab of a tab group"
    case newTab = "Start at the new tab page"
}

// MARK: - Preferences Data Model
class GravityPreferences: ObservableObject {
    @AppStorage("homepage") var homepage: String = ""
    @AppStorage("startupBehavior") var startupBehavior: StartupBehavior = .leftOff
    @AppStorage("showTabCount") var showTabCount: Bool = false

    @AppStorage("accentColorRed") var accentColorRed: Double = 0.96
    @AppStorage("accentColorGreen") var accentColorGreen: Double = 0.55
    @AppStorage("accentColorBlue") var accentColorBlue: Double = 0.72
    @AppStorage("useDarkMode") var useDarkMode: Bool = false
    @AppStorage("useMagicMode") var useMagicMode: Bool = false
    @AppStorage("sidebarWidth") var sidebarWidth: Double = 260
    @AppStorage("autoHideSidebar") var autoHideSidebar: Bool = false
    
    // --- NEW: Master toggle for address bar glass tinting ---
    @AppStorage("enableAddressBarTint") var enableAddressBarTint: Bool = true

    @AppStorage("searchEngine") var searchEngine: String = "Google"
    @AppStorage("searchSuggestions") var searchSuggestions: Bool = true

    @AppStorage("blockTrackers") var blockTrackers: Bool = true
    @AppStorage("clearOnQuit") var clearOnQuit: Bool = false
    @AppStorage("saveHistory") var saveHistory: Bool = true

    var accentColor: Color {
        Color(red: accentColorRed, green: accentColorGreen, blue: accentColorBlue)
    }
}

enum PrefsSection: String, CaseIterable {
    case general = "General"
    case appearance = "Appearance"
    case search = "Search"
    case privacy = "Privacy"

    var icon: String {
        switch self {
        case .general:    return "house"
        case .appearance: return "paintpalette"
        case .search:     return "magnifyingglass"
        case .privacy:    return "lock.shield"
        }
    }
}

// MARK: - Main Preferences Window
struct GravityPreferencesView: View {
    @StateObject private var prefs = GravityPreferences()
    @State private var selectedSection: PrefsSection = .general
    
    private var sidebarColor: Color {
        prefs.accentColor
    }

    var body: some View {
        HStack(spacing: 0) {
            // MARK: Sidebar
            VStack(alignment: .leading, spacing: 4) {
                Text("Preferences")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                ForEach(PrefsSection.allCases, id: \.self) { section in
                    SidebarRow(
                        section: section,
                        isSelected: selectedSection == section,
                        accentColor: prefs.accentColor
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedSection = section
                        }
                    }
                }

                Spacer()
            }
            .frame(width: 180)
            .background(sidebarColor.opacity(0.15))

            Divider()
                .opacity(0.15)

            // MARK: Content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch selectedSection {
                    case .general:    GeneralSection(prefs: prefs)
                    case .appearance: AppearanceSection(prefs: prefs)
                    case .search:     SearchSection(prefs: prefs)
                    case .privacy:    PrivacySection(prefs: prefs)
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 620, height: 440)
        .preferredColorScheme(prefs.useDarkMode ? .dark : .light)
    }
}

// MARK: - Sidebar Row
struct SidebarRow: View {
    let section: PrefsSection
    let isSelected: Bool
    let accentColor: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: section.icon)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? accentColor : .primary.opacity(0.45))
                .frame(width: 18)

            Text(section.rawValue)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundColor(isSelected ? .primary.opacity(0.9) : .primary.opacity(0.6))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? accentColor.opacity(0.2) : Color.clear)
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Section Header
struct PrefsSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundColor(.primary.opacity(0.8))
            .padding(.bottom, 20)
    }
}

// MARK: - Prefs Group Card
struct PrefsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.bottom, 20)
    }
}

// MARK: - Prefs Row
struct PrefsRow<Content: View>: View {
    let label: String
    var sublabel: String? = nil
    var isLast: Bool = false
    @ViewBuilder var control: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary.opacity(0.85))
                    if let sub = sublabel {
                        Text(sub)
                            .font(.system(size: 11))
                            .foregroundColor(.primary.opacity(0.45))
                    }
                }
                Spacer()
                control
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast {
                Divider()
                    .padding(.leading, 16)
                    .opacity(0.4)
            }
        }
    }
}

// MARK: - General Section
struct GeneralSection: View {
    @ObservedObject var prefs: GravityPreferences

    var body: some View {
        PrefsSectionHeader(title: "General")

        PrefsCard {
            TextField("https://", text: $prefs.homepage)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .font(.system(size: 12))

            PrefsRow(label: "On startup", sublabel: "Choose how Gravity boots up") {
                Picker("", selection: $prefs.startupBehavior) {
                    ForEach(StartupBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.rawValue).tag(behavior)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 220)
                .labelsHidden()
            }

            PrefsRow(label: "Show tab count in sidebar", isLast: true) {
                Toggle("", isOn: $prefs.showTabCount)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }
}

// MARK: - Appearance Section
struct AppearanceSection: View {
    @ObservedObject var prefs: GravityPreferences

    var body: some View {
        PrefsSectionHeader(title: "Appearance")

        PrefsCard {
            PrefsRow(label: "Sidebar accent color", sublabel: "Controls the sidebar and search glow tint") {
                HStack(spacing: 12) {
                    ForEach(colorPresets, id: \.0) { name, r, g, b in
                        Circle()
                            .fill(Color(red: r, green: g, blue: b))
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
                            .background(
                                Circle()
                                    .stroke(Color(red: r, green: g, blue: b), lineWidth: (prefs.accentColorRed == r && prefs.accentColorGreen == g && prefs.accentColorBlue == b) ? 3 : 0)
                                    .frame(width: 32, height: 32)
                                    .opacity(0.5)
                            )
                            .scaleEffect((prefs.accentColorRed == r && prefs.accentColorGreen == g && prefs.accentColorBlue == b) ? 1.1 : 1.0)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    prefs.accentColorRed = r
                                    prefs.accentColorGreen = g
                                    prefs.accentColorBlue = b
                                }
                            }
                    }
                }
                .padding(.vertical, 4)
            }

            PrefsRow(label: "Dark mode", sublabel: "Switch Gravity to a dark appearance") {
                Toggle("", isOn: $prefs.useDarkMode)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            
            PrefsRow(label: "Magic Mode", sublabel: "Enable deep-space starry background and aurora gradients") {
                Toggle("", isOn: $prefs.useMagicMode)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            // --- FIXED/NEW: Dynamic Glass Tint Control ---
            PrefsRow(label: "Address bar liquid tint", sublabel: "Infuse custom accent profiles into the native glass layer") {
                Toggle("", isOn: $prefs.enableAddressBarTint)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            PrefsRow(label: "Sidebar width", sublabel: "Controls the width of the tab sidebar") {
                HStack(spacing: 8) {
                    Slider(value: $prefs.sidebarWidth, in: 200...360, step: 10)
                        .frame(width: 120)
                    Text("\(Int(prefs.sidebarWidth))px")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.5))
                        .frame(width: 38, alignment: .trailing)
                }
            }
            
            PrefsRow(label: "Ghost Mode", sublabel: "Auto-hide the sidebar when not hovered", isLast: true) {
                Toggle("", isOn: $prefs.autoHideSidebar)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }

    private var colorPresets: [(String, Double, Double, Double)] {
        [
            ("Rose",    0.96, 0.55, 0.72),
            ("Lilac",   0.75, 0.35, 1.0),
            ("Sky",     0.2,  0.75, 1.0),
            ("Sage",    0.3,  0.85, 0.5),
            ("Peach",   1.0,  0.55, 0.25),
        ]
    }
}

// MARK: - Search Section
struct SearchSection: View {
    @ObservedObject var prefs: GravityPreferences
    private let engines = ["Google", "DuckDuckGo", "Bing", "Brave Search", "Ecosia"]

    var body: some View {
        PrefsSectionHeader(title: "Search")

        PrefsCard {
            PrefsRow(label: "Default search engine") {
                Picker("", selection: $prefs.searchEngine) {
                    ForEach(engines, id: \.self) { engine in
                        Text(engine).tag(engine)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
                .labelsHidden()
            }

            PrefsRow(label: "Show search suggestions", sublabel: "Display suggestions as you type in the address bar", isLast: true) {
                Toggle("", isOn: $prefs.searchSuggestions)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }
}

// MARK: - Privacy Section
struct PrivacySection: View {
    @ObservedObject var prefs: GravityPreferences

    var body: some View {
        PrefsSectionHeader(title: "Privacy")

        PrefsCard {
            PrefsRow(label: "Block trackers", sublabel: "Prevent cross-site tracking scripts from loading") {
                Toggle("", isOn: $prefs.blockTrackers)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            PrefsRow(label: "Save browsing history") {
                Toggle("", isOn: $prefs.saveHistory)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            PrefsRow(label: "Clear history & cache on quit", sublabel: "All data will be wiped when Gravity closes", isLast: true) {
                Toggle("", isOn: $prefs.clearOnQuit)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }

        HStack {
            Spacer()
            Button(role: .destructive) {
                // Wipe the mainframe
            } label: {
                Label("Clear All Data Now", systemImage: "trash")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red.opacity(0.8))
        }
    }
}

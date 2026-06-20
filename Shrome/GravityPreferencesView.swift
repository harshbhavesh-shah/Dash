//
//  GravityPreferencesView.swift
//  Shrome
//

import SwiftUI
import AppKit
import Combine

// --- STARTUP BEHAVIOR ENUM ---
enum StartupBehavior: String, CaseIterable {
    case leftOff       = "Continue where I left off"
    case firstGroupTab = "First tab of a tab group"
    case newTab        = "Start at the new tab page"
}

// MARK: - Preferences Data Model
class GravityPreferences: ObservableObject {
    // Same key NameOnboardingView writes to on first launch — editing it
    // here just lets the user revisit that choice later instead of being
    // stuck with whatever they entered (or skipped) on day one.
    @AppStorage("userPreferredName") var userPreferredName: String = ""

    @AppStorage("homepage")         var homepage: String = ""
    @AppStorage("startupBehavior") var startupBehavior: StartupBehavior = .leftOff
    @AppStorage("showTabCount")    var showTabCount: Bool = false

    @AppStorage("accentColorRed")   var accentColorRed:   Double = 0.96
    @AppStorage("accentColorGreen") var accentColorGreen: Double = 0.55
    @AppStorage("accentColorBlue")  var accentColorBlue:  Double = 0.72

    @AppStorage("selectedShromeTheme") var selectedTheme: ShromeTheme = .cosmicPastel

    @AppStorage(BackgroundImageStore.appStorageKey) var landingBackgroundImagePath: String = ""

    @AppStorage("useDarkMode")          var useDarkMode: Bool = false
    @AppStorage("sidebarWidth")         var sidebarWidth: Double = 260
    @AppStorage("autoHideSidebar")      var autoHideSidebar: Bool = false
    @AppStorage("enableAddressBarTint") var enableAddressBarTint: Bool = true

    @AppStorage("searchEngine")      var searchEngine: String = "Google"
    @AppStorage("searchSuggestions") var searchSuggestions: Bool = true

    @AppStorage("blockTrackers") var blockTrackers: Bool = true
    @AppStorage("clearOnQuit")   var clearOnQuit: Bool = false
    @AppStorage("saveHistory")   var saveHistory: Bool = true

    var accentColor: Color { selectedTheme.accentColor }

    func updateTheme(to theme: ShromeTheme) {
        selectedTheme = theme
        // PERF FIX: Guard against nil for wide-gamut P3 colors
        guard let components = NSColor(theme.accentColor).usingColorSpace(.sRGB) else { return }
        accentColorRed   = Double(components.redComponent)
        accentColorGreen = Double(components.greenComponent)
        accentColorBlue  = Double(components.blueComponent)
    }
}

enum PrefsSection: String, CaseIterable {
    case general    = "General"
    case appearance = "Appearance"
    case search     = "Search"
    case privacy    = "Privacy"

    var icon: String {
        switch self {
        case .general:    return "house"
        case .appearance: return "paintpalette"
        case .search:     return "magnifyingglass"
        case .privacy:    return "lock.shield"
        }
    }
}

// MARK: - Window Titlebar Hider
// UI FIX: The Settings scene always renders a macOS titlebar above the SwiftUI
// view frame. No SwiftUI background modifier can paint into that zone, so the
// sidebar tint always stops short of the top of the window — making the title
// look like it's floating between two uncoloured sections.
// This NSViewRepresentable reaches into the NSWindow on appear and sets
// titlebarAppearsTransparent = true, which merges the titlebar region into the
// view's drawable area. The sidebar background can then fill the full height
// from top to bottom with no gap, and the title text sits cleanly inside it.
private struct PrefsTitlebarHider: NSViewRepresentable {
    let accentColor: Color

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        // Keep the traffic lights so the window is still closeable
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
    }
}

// MARK: - Main Preferences Window
struct GravityPreferencesView: View {
    @StateObject private var prefs = GravityPreferences()
    @State private var selectedSection: PrefsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            // MARK: Sidebar
            // UI FIX: Sidebar is now 210pt wide (up from 180) so "Shrome Settings"
            // fits comfortably without wrapping, and the section rows have
            // breathing room. The title sits at padding(.top, 44) to clear the
            // traffic light buttons now that the titlebar is transparent and
            // merged into this view's frame.
            VStack(alignment: .leading, spacing: 4) {
                Text("Shrome Settings")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary.opacity(1))
                    .padding(.horizontal, 16)
                    .padding(.top, 44)   // clears the traffic lights
                    .padding(.bottom, 10)

                ForEach(PrefsSection.allCases, id: \.self) { section in
                    SidebarRow(
                        section: section,
                        isSelected: selectedSection == section,
                        accentColor: prefs.accentColor
                    )
                    .onTapGesture {
                        withAnimation(.shromeSnappy) {
                            selectedSection = section
                        }
                    }
                }

                Spacer()
            }
            .frame(width: 210)
            .background(prefs.accentColor.opacity(0.12))
            // Attach the titlebar hider here so it reads the window as soon
            // as the sidebar column appears on screen.
            .background(
                PrefsTitlebarHider(accentColor: prefs.accentColor)
                    .frame(width: 0, height: 0)
            )

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
        .frame(width: 680, height: 480)
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
                .fill(isSelected ? accentColor.opacity(0.15) : Color.clear)
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

// MARK: - Prefs Card
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
            PrefsRow(label: "Your name", sublabel: "Used for the greeting on your landing page") {
                TextField("Skipped", text: $prefs.userPreferredName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .font(.system(size: 12))
            }

            PrefsRow(label: "Homepage", sublabel: "Set your default launch portal") {
                TextField("https://", text: $prefs.homepage)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                    .font(.system(size: 12))
            }

            PrefsRow(label: "On startup", sublabel: "Choose how Shrome boots up") {
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

    private let themeColumns = [
        GridItem(.adaptive(minimum: 65, maximum: 80), spacing: 12)
    ]

    var body: some View {
        PrefsSectionHeader(title: "Appearance")

        Text("Liquid Glass Color Themes")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.bottom, 8)

        LazyVGrid(columns: themeColumns, spacing: 14) {
            ForEach(ShromeTheme.allCases) { theme in
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: theme.gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .shadow(color: theme.accentColor.opacity(0.2), radius: 4, x: 0, y: 2)

                        if prefs.selectedTheme == theme {
                            Circle()
                                .stroke(Color.primary, lineWidth: 2)
                                .frame(width: 44, height: 44)
                        }
                    }

                    Text(theme.rawValue)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(prefs.selectedTheme == theme ? .primary : .secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.shromeBouncy) {
                        prefs.updateTheme(to: theme)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06), lineWidth: 1))
        .padding(.bottom, 20)

        PrefsCard {
            PrefsRow(label: "Dark mode", sublabel: "Switch Shrome to a dark appearance") {
                Toggle("", isOn: $prefs.useDarkMode)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

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

        Text("Landing Page Background")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.top, 20)
            .padding(.bottom, 8)

        PrefsCard {
            PrefsRow(
                label: "Custom background photo",
                sublabel: prefs.landingBackgroundImagePath.isEmpty
                    ? "Show a photo behind your new tab page"
                    : "Your photo replaces the default glass backdrop",
                isLast: prefs.landingBackgroundImagePath.isEmpty
            ) {
                HStack(spacing: 10) {
                    if !prefs.landingBackgroundImagePath.isEmpty,
                       let preview = BackgroundImageStore.loadImage(at: prefs.landingBackgroundImagePath) {
                        Image(nsImage: preview)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 30)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }

                    Button("Choose Image…") {
                        if let path = BackgroundImageStore.pickAndSaveImage() {
                            withAnimation(.shromeSnappy) {
                                prefs.landingBackgroundImagePath = path
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.system(size: 12))
                }
            }

            if !prefs.landingBackgroundImagePath.isEmpty {
                PrefsRow(label: "Remove background photo", isLast: true) {
                    Button(role: .destructive) {
                        BackgroundImageStore.clearStoredFile()
                        withAnimation(.shromeSnappy) {
                            prefs.landingBackgroundImagePath = ""
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bouncy)
                    .foregroundColor(.red.opacity(0.8))
                }
            }
        }
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

            PrefsRow(label: "Clear history & cache on quit", sublabel: "All data will be wiped when Shrome closes", isLast: true) {
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
            .buttonStyle(.bouncy)
            .foregroundColor(.red.opacity(0.8))
        }
    }
}

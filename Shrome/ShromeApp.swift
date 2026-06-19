//
//  ShromeApp.swift
//  Shrome
//

import SwiftUI

private struct PrivateWindowKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isPrivateWindow: Bool {
        get { self[PrivateWindowKey.self] }
        set { self[PrivateWindowKey.self] = newValue }
    }
}

@main
struct ShromeApp: App {
    let persistenceController = PersistenceController.shared
    @Environment(\.openWindow) private var openWindow

    init() {
        // PERF FIX: Fire up the underlying WebKit process subsystems immediately on boot
        WebViewPool.shared.warmUp()
    }

    var body: some Scene {
        WindowGroup(id: "ShromeWindow") {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.isPrivateWindow, false)
        }
        .commands {
            // FIX: These used to be built with `CommandMenu("File")` /
            // `CommandMenu("View")`. CommandMenu always creates a brand-new
            // top-level menu appended after ALL standard system menus
            // (File, Edit, View, Window) and before Help — it does NOT
            // merge with the real File/View menus just because it shares
            // their name. That left the actual File menu empty (so macOS
            // collapsed/hid it), making Edit appear to be the first menu,
            // while a second, oddly-placed "File" and "View" menu sat near
            // the end of the bar. Using CommandGroup(replacing:)/(after:)
            // instead folds these items into the real, correctly-ordered
            // system menus: App, File, Edit, View, Window, History, Help.

            // --- FILE MENU ---
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionNewTab"), object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("New Window") {
                    openWindow(id: "ShromeWindow")
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Private Window") {
                    openWindow(id: "PrivateShromeWindow")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(after: .newItem) {
                Divider()

                Button("Close Tab") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionCloseTab"), object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)
            }

            // --- VIEW MENU ---
            // Anchored on .sidebar (the same placement SidebarCommands()
            // itself uses) so these land inside the real View menu
            // regardless of whether this window has an NSToolbar.
            CommandGroup(after: .sidebar) {
                Divider()

                Button("Reload Page") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionReload"), object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Toggle Sidebar Visibility") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionToggleSidebar"), object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }

            SidebarCommands()

            // --- HISTORY MENU ---
            // CommandMenu is the correct tool here: macOS has no default
            // History menu to fold into, so this genuinely should be a new
            // top-level menu (same pattern Safari/Chrome use).
            CommandMenu("History") {
                Button("Show Complete History Logs...") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionShowHistory"), object: nil)
                }
                .keyboardShortcut("y", modifiers: .command)
            }
        }

        WindowGroup(id: "PrivateShromeWindow") {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.isPrivateWindow, true)
        }
        
        Settings {
            GravityPreferencesView()
        }
    }
}

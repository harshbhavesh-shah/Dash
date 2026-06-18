//
//  ShromeApp.swift
//  Shrome
//

import SwiftUI

// --- REGISTERING CUSTOM PRIVACY VALUES IN THE SWIFTUI ENVIRONMENT SYSTEM ---
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
    
    // Trigger system environment actions natively across windows
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // SCENE 1: STANDARD USER PROFILE BROWSER SPACE
        WindowGroup(id: "ShromeWindow") {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.isPrivateWindow, false)
        }
        .commands {
            // 1. CLEAN UP DEFAULT APP UTILITIES
            CommandGroup(replacing: .newItem) { }
            
            // 2. FILE MENU: NAVIGATION CORE
            CommandMenu("File") {
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
                
                Divider()
                
                Button("Close Tab") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionCloseTab"), object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            
            // 3. VIEW MENU: INTERFACE AND ACTIONS
            CommandMenu("View") {
                Button("Reload Page") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionReload"), object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Divider()
                
                Button("Toggle Sidebar Visibility") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionToggleSidebar"), object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }
            
            // --- FIXED: PULL THIS OUT OF THE CUSTOM VIEW DROPDOWN ---
            // This natively adds Apple's default window presentation utilities right where they belong!
            SidebarCommands()
            // 4. HISTORY MENU: PERSISTENCE LOOKBACK
            CommandMenu("History") {
                Button("Show Complete History Logs...") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionShowHistory"), object: nil)
                }
                .keyboardShortcut("y", modifiers: .command)
            }
        }

        // SCENE 2: COMPLETELY ISOLATED PRIVATE WINDOW SCENE CONTAINER
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

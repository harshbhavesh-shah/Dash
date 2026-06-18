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
    // Shared Core Data persistent controller instance
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        // SCENE 1: STANDARD USER PROFILE BROWSER SPACE
        WindowGroup(id: "ShromeWindow") {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.isPrivateWindow, false)
        }
        .commands {
            SidebarCommands()
        }

        // SCENE 2: COMPLETELY ISOLATED PRIVATE WINDOW SCENE CONTAINER
        WindowGroup(id: "PrivateShromeWindow") {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.isPrivateWindow, true)
        }
        
        // --- FIXED: THE NATIVE PREFERENCES ROUTING BLOCK ---
        // This tells macOS to bind your custom view to the standard App Menu and Cmd + , keybind!
        Settings {
            GravityPreferencesView()
        }
    }
}

//
//  ShromeApp.swift
//  Shrome
//

import SwiftUI
import AppKit

// --- NEW: THE QUIT INTERCEPTOR ---
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let alert = NSAlert()
        alert.messageText = "Abandon Ship?"
        alert.informativeText = "Are you sure you want to quit Shrome? Your cosmic journey will be paused."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        // Pop the alert!
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // User confirmed. Tell TabManager to pack up the data.
            NotificationCenter.default.post(name: .saveBrowserSession, object: nil)
            return .terminateNow
        } else {
            // User cancelled. Keep the engines running.
            return .terminateCancel
        }
    }
}

@main
struct ShromeApp: App {
    let persistenceController = PersistenceController.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Spin up the compiler engine the exact millisecond the app launches
        _ = AdBlocker.shared
    }
    var body: some Scene {
        WindowGroup(id: "ShromeWindow") {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .windowStyle(.hiddenTitleBar)

        WindowGroup(id: "PrivateShromeWindow") {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.isPrivateWindow, true)
        }
        .windowStyle(.hiddenTitleBar)
        
        Settings {
            GravityPreferencesView()
        }
    }
}

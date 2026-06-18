//
//  ShromeApp.swift
//  Shrome
//

import SwiftUI
import AppKit

// --- THE QUIT INTERCEPTOR ---
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let alert = NSAlert()
        alert.messageText = "Abandon Ship?"
        alert.informativeText = "Are you sure you want to quit Shrome? Your cosmic journey will be paused."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            NotificationCenter.default.post(name: .saveBrowserSession, object: nil)
            return .terminateNow
        } else {
            return .terminateCancel
        }
    }
}

@main
struct ShromeApp: App {
    let persistenceController = PersistenceController.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
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
                // --- FIXED: Inject view context here to protect the history sheets from crashing ---
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

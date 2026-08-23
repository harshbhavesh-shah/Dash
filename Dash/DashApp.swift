//
//  DashApp.swift
//  Dash
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI
import AppKit
import CoreData
import WebKit

private struct PrivateWindowKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isPrivateWindow: Bool {
        get { self[PrivateWindowKey.self] }
        set { self[PrivateWindowKey.self] = newValue }
    }
}

// BUG FIX: "Clear history & cache on quit" in Settings previously did
// nothing except suppress writing the next tab session to disk —
// `TabManager._commitSessionToDisk()` checked the flag, but nothing ever
// actually deleted browsing history or website data (cookies/cache) at
// quit time, despite the setting's own label promising "All data will be
// wiped when Dash closes." This delegate hooks real app termination and
// performs that wipe, holding termination open (`.terminateLater`) until
// the async website-data removal actually completes.
class DashAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard UserDefaults.standard.bool(forKey: "clearOnQuit") else { return .terminateNow }

        let ctx = PersistenceController.shared.container.viewContext
        let historyFetch = NSFetchRequest<HistoryItem>(entityName: "HistoryItem")
        if let items = try? ctx.fetch(historyFetch) {
            for item in items { ctx.delete(item) }
            try? ctx.save()
        }

        UserDefaults.standard.removeObject(forKey: "savedTabs")
        UserDefaults.standard.removeObject(forKey: "activeTabId")

        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) {
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

@main
struct DashApp: App {
    @NSApplicationDelegateAdaptor(DashAppDelegate.self) private var appDelegate
    let persistenceController = PersistenceController.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL

    init() {
        WebViewPool.shared.warmUp()
        UpdateChecker.shared.checkForUpdatesIfNeeded()
        TabCycleKeyMonitor.shared.start()
        NotificationCenter.default.addObserver(
            forName: .openNewWindowWithURL,
            object: nil,
            queue: .main
        ) { notification in
            guard let url = notification.object as? URL else { return }
            // Relay via URLWithNewWindow so the App body's environment
            // (where openURL IS available) can handle it.
            NotificationCenter.default.post(
                name: .openURLInNewWindow,
                object: url
            )
        }
    }

    var body: some Scene {
        WindowGroup(id: "DashWindow", for: URL.self) { $url in
            ContentView(initialURL: url)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.isPrivateWindow, false)
                .onReceive(NotificationCenter.default.publisher(for: .openURLInNewWindow)) { note in
                    guard let url = note.object as? URL else { return }
                    openWindow(id: "DashWindow", value: url)
                }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    UpdateChecker.shared.checkForUpdatesManually()
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionNewTab"), object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("New Window") {
                    openWindow(id: "DashWindow")
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Private Window") {
                    openWindow(id: "PrivateDashWindow")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(after: .newItem) {
                Divider()

                Button("Close Tab") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionCloseTab"), object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)

                Button("Reopen Closed Tab") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionReopenClosedTab"), object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
            CommandGroup(after: .pasteboard) {
                Divider()

                Button("Find in Page...") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionFindInPage"), object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
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

            // --- TABS MENU ---
            CommandMenu("Tabs") {
                Button("Quick Switcher...") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionQuickSwitcher"), object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                // BUG FIX: these used to both share ⌘] / ⌘[ with Back/Forward
                // below — four menu items, two key combos, in the same app.
                // Moved to Safari's convention (⇧⌘]/⇧⌘[ for tab cycling)
                // instead, which also frees up plain ⌘]/⌘[ for Back/Forward
                // to work unambiguously.
                Button("Next Tab") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionNextTab"), object: nil)
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Button("Previous Tab") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionPreviousTab"), object: nil)
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Divider()

                ForEach(1...8, id: \.self) { n in
                    Button("Tab \(n)") {
                        NotificationCenter.default.post(name: Notification.Name("MenuActionSelectTab"), object: n)
                    }
                    .keyboardShortcut(KeyEquivalent(Character(String(n))), modifiers: .command)
                }

                Button("Last Tab") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionSelectLastTab"), object: nil)
                }
                .keyboardShortcut("9", modifiers: .command)

                Divider()

                Button("Back") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionGoBack"), object: nil)
                }
                .keyboardShortcut("[", modifiers: [.command])

                Button("Forward") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionGoForward"), object: nil)
                }
                .keyboardShortcut("]", modifiers: [.command])
            }
            CommandMenu("History") {
                Button("Show Complete History Logs...") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionShowHistory"), object: nil)
                }
                .keyboardShortcut("y", modifiers: .command)
            }
            CommandMenu("Downloads") {
                Button("Show Downloads...") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionShowDownloads"), object: nil)
                }
                .keyboardShortcut("l", modifiers: [.command, .option])
            }
        }

        WindowGroup(id: "PrivateDashWindow") {
            ContentView(isPrivate: true)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.isPrivateWindow, true)
        }
        
        Settings {
            GravityPreferencesView()
        }
    }
}

// MARK: - Tab Cycle Key Monitor
class TabCycleKeyMonitor {
    static let shared = TabCycleKeyMonitor()
    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 48,
                  event.modifierFlags.contains(.control) else { return event }

            if event.modifierFlags.contains(.shift) {
                NotificationCenter.default.post(
                    name: Notification.Name("MenuActionPreviousTab"), object: nil
                )
            } else {
                NotificationCenter.default.post(
                    name: Notification.Name("MenuActionNextTab"), object: nil
                )
            }
            return nil
        }
    }
}

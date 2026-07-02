//
//  ShromeApp.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI
import AppKit

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
    @Environment(\.openURL) private var openURL

    init() {
        WebViewPool.shared.warmUp()
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
        WindowGroup(id: "ShromeWindow", for: URL.self) { $url in
            ContentView(initialURL: url)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.isPrivateWindow, false)
                .onReceive(NotificationCenter.default.publisher(for: .openURLInNewWindow)) { note in
                    guard let url = note.object as? URL else { return }
                    openWindow(id: "ShromeWindow", value: url)
                }
        }
        .commands {
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
                Button("Next Tab") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionNextTab"), object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)

                Button("Previous Tab") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionPreviousTab"), object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)

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

// MARK: - Tab Cycle Key Monitor
class TabCycleKeyMonitor {
    static let shared = TabCycleKeyMonitor()
    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Tab key (keyCode 48) with Control held
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
            // Returning nil swallows the event so it doesn't also trigger
            // system focus navigation.
            return nil
        }
    }
}

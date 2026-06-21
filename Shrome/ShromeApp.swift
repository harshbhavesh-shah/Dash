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

    private let tabCycleMonitor = TabCycleKeyMonitor()

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false

        WebViewPool.shared.warmUp()
    }

    var body: some Scene {
        WindowGroup(id: "ShromeWindow") {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.isPrivateWindow, false)
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

                Divider()
                Button("Open Location...") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionFocusAddressBar"), object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)
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
            CommandMenu("Tabs") {
                Button("Show Next Tab") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionNextTab"), object: nil)
                }
                .keyboardShortcut(.tab, modifiers: .control)

                Button("Show Previous Tab") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionPreviousTab"), object: nil)
                }
                .keyboardShortcut(.tab, modifiers: [.control, .shift])

                Divider()
                ForEach(1...8, id: \.self) { number in
                    Button("Select Tab \(number)") {
                        NotificationCenter.default.post(name: Notification.Name("MenuActionSelectTab"), object: number)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command)
                }

                Button("Select Last Tab") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionSelectLastTab"), object: nil)
                }
                .keyboardShortcut("9", modifiers: .command)
            }
            CommandMenu("History") {
                Button("Back") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionGoBack"), object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Forward") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionGoForward"), object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)

                Divider()

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
final class TabCycleKeyMonitor {
    private var monitor: Any?

    init() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 48 else { return event }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            if flags == [.control, .shift] {
                NotificationCenter.default.post(name: Notification.Name("MenuActionPreviousTab"), object: nil)
                return nil // swallow it — don't let it fall through to focus navigation
            } else if flags == [.control] {
                NotificationCenter.default.post(name: Notification.Name("MenuActionNextTab"), object: nil)
                return nil
            }

            return event
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

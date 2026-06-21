//
//  ShromeApp.swift
//  Shrome
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

    // FIX: SwiftUI's `.keyboardShortcut(.tab, modifiers: .control)` on the
    // "Tabs" menu commands turned out not to be reliable on macOS — Tab is
    // handled specially by AppKit's focus-navigation machinery before a
    // key event ever reaches NSMenuItem key-equivalent matching, so the
    // Commands-based binding silently never fires no matter what else is
    // going on with window tabbing. A local NSEvent monitor intercepts the
    // raw keyDown directly — ahead of focus navigation and any responder's
    // own key bindings — which sidesteps the problem entirely. Must be
    // retained (held as a stored property) for the app's lifetime, or
    // ARC deallocates it and the monitor stops firing immediately.
    private let tabCycleMonitor = TabCycleKeyMonitor()

    init() {
        // Belt-and-suspenders: macOS's native window-tabbing feature can
        // also reserve ⌃⇥ / ⌃⇧⇥ system-wide for cycling between merged
        // native window tabs. Shrome never uses native window tabbing, so
        // this has no visible effect on its own, but disabling it removes
        // one more thing that could compete for the same keystroke.
        NSWindow.allowsAutomaticWindowTabbing = false

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

                Divider()

                // Classic Safari/Chrome "Open Location" shortcut — jumps
                // focus straight to the address bar with its contents
                // selected, ready to type over.
                Button("Open Location...") {
                    NotificationCenter.default.post(name: Notification.Name("MenuActionFocusAddressBar"), object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)
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

            // --- TABS MENU ---
            // No default system menu for tab navigation to fold into, so —
            // same reasoning as History below — this is a genuine new
            // top-level menu rather than a CommandGroup anchor.
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

                // ⌘1 through ⌘8 jump straight to that tab position; ⌘9 is
                // conventionally "last tab" rather than "tab 9" so it still
                // works sensibly with fewer than 9 tabs open.
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

            // --- HISTORY MENU ---
            // CommandMenu is the correct tool here: macOS has no default
            // History menu to fold into, so this genuinely should be a new
            // top-level menu (same pattern Safari/Chrome use).
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

/// Intercepts ⌃Tab / ⌃⇧Tab directly at the event level instead of going
/// through SwiftUI's `Commands` menu-shortcut binding, which doesn't
/// reliably fire for Tab-based key equivalents on macOS (see the comment
/// on `tabCycleMonitor` above). Posts the same notifications the menu
/// items themselves post, so `ContentView`'s existing handlers don't need
/// to know or care which path the action came from.
final class TabCycleKeyMonitor {
    private var monitor: Any?

    init() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // keyCode 48 is the physical Tab key on every Mac keyboard
            // layout — matching on the key code rather than
            // charactersIgnoringModifiers avoids layout-dependent
            // surprises (Control can remap what character gets produced
            // on some layouts).
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

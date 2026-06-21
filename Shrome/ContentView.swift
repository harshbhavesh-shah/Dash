//
//  ContentView.swift
//  Shrome
//

import SwiftUI
import AppKit
import LocalAuthentication
import WebKit

struct ContentView: View {
    @StateObject private var tabManager = TabManager()
    @State private var isSidebarVisible = false
    @State private var showHistoryPanel = false

    @Namespace private var addressBarNamespace

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .light
    @AppStorage("autoHideSidebar") private var autoHideSidebar: Bool = false
    @AppStorage("searchEngine") private var searchEngine: String = "Google"

    // Live day/night state, only consulted when appearanceMode == .automatic
    // — see SunAppearance.swift.
    @ObservedObject private var sunAppearance = SunAppearanceManager.shared

    // The name shown in the landing page greeting, captured once via
    // NameOnboardingView on first launch. hasCompletedNameOnboarding is
    // tracked separately from the name itself so skipping (leaving the
    // name blank) doesn't cause the prompt to keep reappearing.
    @AppStorage("userPreferredName") private var userPreferredName: String = ""
    @AppStorage("hasCompletedNameOnboarding") private var hasCompletedNameOnboarding: Bool = false

    @Environment(\.isPrivateWindow) private var isPrivateWindow
    @Environment(\.openWindow) private var openWindow
    @Environment(\.managedObjectContext) private var viewContext

    @State private var isEdgeHovered = false
    @State private var hideTask: Task<Void, Never>? = nil

    @State private var isPrivateWindowUnlocked = false
    @State private var biometricErrorMessage: String? = nil

    // Reference to this window, resolved via WindowHacker — needed so
    // "close the last tab" can close the actual window rather than just
    // mutating tab state.
    @State private var hostWindow: NSWindow?

    // PERF FIX: Separate the text the user is actively typing from the URL
    // the WebView should load. Previously both shared the same urlString
    // binding on Tab, which meant every keystroke in the address bar mutated
    // tab.url and triggered updateNSView in WebView — potentially firing a
    // mid-typed URL load on every character. displayURLString is local to
    // ContentView and only committed to the tab model when the user submits.
    @State private var displayURLString: String = ""

    private var isLandingPage: Bool {
        tabManager.activeTab.url.absoluteString == "about:blank"
    }

    private var isDarkModeActive: Bool {
        switch appearanceMode {
        case .light:     return false
        case .dark:      return true
        case .automatic: return sunAppearance.isNightTime
        }
    }

    private var sidebarOffset: CGFloat {
        if !autoHideSidebar { return 0 }
        if isSidebarVisible { return 0 }
        if isEdgeHovered { return 0 }
        return -350
    }

    private var shouldUseNativeButtons: Bool {
        autoHideSidebar && !isSidebarVisible && !isEdgeHovered
    }

    // PERF FIX: addressBarBinding now drives displayURLString, not
    // tab.urlString directly. The WebView only sees committed URLs.
    private var addressBarBinding: Binding<String> {
        Binding(
            get: { displayURLString },
            set: { displayURLString = $0 }
        )
    }

    private var browserSidebarBinding: Binding<Bool> {
        Binding(
            get: { isSidebarVisible },
            set: { isSidebarVisible = $0 }
        )
    }

    private func handleHover(isHovering: Bool) {
        guard autoHideSidebar && !isSidebarVisible else { return }
        hideTask?.cancel()

        if isHovering {
            withAnimation(.shromeSnappy) {
                isEdgeHovered = true
            }
        } else {
            hideTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if !Task.isCancelled {
                    await MainActor.run {
                        withAnimation(.shromeSnappy) {
                            isEdgeHovered = false
                        }
                    }
                }
            }
        }
    }

    private func executeAddressBarSubmit() {
        // Commit the display string into the tab model, which is what
        // triggers the actual WebView navigation.
        tabManager.updateActiveUrl(urlString: displayURLString, searchEngine: searchEngine)

        // Sync display string back to the resolved URL after commit
        // so the bar shows the canonical form (e.g. https:// prepended).
        DispatchQueue.main.async {
            displayURLString = tabManager.activeTab.urlString
        }

        withAnimation(.shromeBouncy) { }

        if autoHideSidebar && !isSidebarVisible {
            hideTask?.cancel()
            withAnimation(.shromeSnappy) {
                isEdgeHovered = false
            }
        }
    }

    private func triggerTouchIDPrompt() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "unlock your private Shrome session"
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        withAnimation(.shromeBouncy) {
                            self.isPrivateWindowUnlocked = true
                        }
                    } else {
                        self.biometricErrorMessage = authError?.localizedDescription ?? "Authentication failed"
                    }
                }
            }
        } else {
            biometricErrorMessage = error?.localizedDescription ?? "Biometrics unavailable"
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // LAYER 1: Core Web Render
            BrowserView(
                tabManager: tabManager,
                isSidebarVisible: browserSidebarBinding,
                namespace: addressBarNamespace
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // LAYER 2: Sliding Sidebar
            SidebarView(tabManager: tabManager, isVisible: browserSidebarBinding)
                .offset(x: sidebarOffset)
                .onHover { hovering in
                    handleHover(isHovering: hovering)
                }
                .zIndex(10)

            if autoHideSidebar && !isSidebarVisible && !isEdgeHovered {
                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: 15)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        handleHover(isHovering: hovering)
                    }
                    .zIndex(11)
            }

            // LAYER 3: Floating Address Bar
            bottomBarLayer

            // LAYER 4: Private Session Lock Shield
            if isPrivateWindow && !isPrivateWindowUnlocked {
                ZStack {
                    Color.clear
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.purple)

                        Text("Private Session Locked")
                            .font(.system(size: 18, weight: .bold, design: .rounded))

                        Text("Please authenticate to reveal your tabs.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button(action: triggerTouchIDPrompt) {
                            Label("Unlock with Touch ID", systemImage: "touchid")
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .keyboardShortcut(.defaultAction)

                        if let errorMsg = biometricErrorMessage {
                            Text(errorMsg)
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                                .padding(.top, 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(100)
            }

            // LAYER 5: First-Launch Name Onboarding
            // Regular windows only — a private window has nothing to
            // personalize, since it always greets as "Stranger" regardless
            // of the stored name.
            if !isPrivateWindow && !hasCompletedNameOnboarding {
                NameOnboardingView { name in
                    withAnimation(.shromeBouncy) {
                        userPreferredName = name
                        hasCompletedNameOnboarding = true
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(200)
            }
        }
        .background(
            WindowHacker(showNativeButtons: shouldUseNativeButtons) { window in
                if hostWindow !== window { hostWindow = window }
            }
            .frame(width: 0, height: 0)
        )
        .onAppear {
            // Seed the display string from the active tab on first appear.
            displayURLString = tabManager.activeTab.urlString == "about:blank"
                ? ""
                : tabManager.activeTab.urlString

            if appearanceMode == .automatic {
                SunAppearanceManager.shared.activate()
            }

            if isPrivateWindow {
                if tabManager.tabs.isEmpty {
                    tabManager.createNewTab(isPrivate: true)
                } else {
                    for i in 0..<tabManager.tabs.count {
                        tabManager.tabs[i].isPrivate = true
                    }
                }
                triggerTouchIDPrompt()
            }
        }
        // PERF FIX: Cancel the pending hide timer if the view disappears
        // (e.g. window closed while hover delay is in flight). Without this
        // the Task holds a reference keeping the view alive and may fire
        // a UI update on a deallocated context.
        .onDisappear {
            hideTask?.cancel()
        }
        // FIX: WebViewPool's per-tab registry is a long-lived singleton
        // that outlives any individual window — closing a tab releases its
        // own webview (see TabManager.closeTab), but closing the entire
        // WINDOW (without closing each tab first) previously left every
        // one of its tabs' WKWebViews leaked in the registry forever, since
        // nothing told the pool "this whole window, and everything in it,
        // is gone."
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            guard let closingWindow = notification.object as? NSWindow, closingWindow === hostWindow else { return }
            for tab in tabManager.tabs {
                WebViewPool.shared.releaseWebView(for: tab.id)
            }
        }
        // Sync displayURLString whenever the active tab changes externally
        // (tab switch, back/forward navigation, link click opening new tab).
        .onChange(of: tabManager.activeTabId) { _, _ in
            let urlStr = tabManager.activeTab.urlString
            displayURLString = urlStr == "about:blank" ? "" : urlStr
        }
        .onChange(of: tabManager.activeTab.urlString) { _, newValue in
            // Keep display bar in sync when WebView navigates on its own
            // (redirects, in-page link clicks) — but only if the user isn't
            // actively editing (i.e. the committed URL changed, not a draft).
            if newValue != "about:blank" {
                displayURLString = newValue
            }
        }
        .animation(.shromeBouncy, value: isLandingPage)
        .preferredColorScheme((isDarkModeActive || tabManager.activeTab.isPrivate) ? .dark : .light)
        .sheet(isPresented: $showHistoryPanel) {
            HistoryView(tabManager: tabManager) {
                showHistoryPanel = false
            }
            .environment(\.managedObjectContext, viewContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionNewTab"))) { _ in
            withAnimation(.shromeBouncy) {
                tabManager.createNewTab(isPrivate: isPrivateWindow)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionCloseTab"))) { _ in
            // FIX: This used to just no-op once only one tab was left
            // (guarded out inside closeTab itself), which is why "closing
            // the tab" appeared to do nothing at all. Classic Mac behavior
            // is that closing the last tab closes the window — so once
            // there's nothing left to close *within* the window, close the
            // window itself instead of swallowing the shortcut.
            if tabManager.tabs.count <= 1 {
                (hostWindow ?? NSApplication.shared.keyWindow)?.close()
            } else {
                tabManager.closeTab(id: tabManager.activeTabId)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionReload"))) { _ in
            tabManager.reloadActiveTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionToggleSidebar"))) { _ in
            withAnimation(.shromeSnappy) {
                isSidebarVisible.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionShowHistory"))) { _ in
            showHistoryPanel = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionNextTab"))) { _ in
            withAnimation(.shromeSnappy) {
                tabManager.selectNextTab()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionPreviousTab"))) { _ in
            withAnimation(.shromeSnappy) {
                tabManager.selectPreviousTab()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionSelectTab"))) { notification in
            guard let number = notification.object as? Int else { return }
            withAnimation(.shromeSnappy) {
                tabManager.selectTab(number: number)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionSelectLastTab"))) { _ in
            withAnimation(.shromeSnappy) {
                tabManager.selectLastTab()
            }
        }
        // FIX: Now that every tab owns its own persistent webview (see
        // WebViewPool), Back/Forward can just ask for the ACTIVE tab's
        // instance directly instead of broadcasting to every open tab's
        // webview and hoping only the right one reacts — existingWebView
        // never creates one, so this is also a no-op for a tab that's
        // still on the landing page and has no webview yet.
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionGoBack"))) { _ in
            guard let webView = WebViewPool.shared.existingWebView(for: tabManager.activeTabId), webView.canGoBack else { return }
            webView.goBack()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionGoForward"))) { _ in
            guard let webView = WebViewPool.shared.existingWebView(for: tabManager.activeTabId), webView.canGoForward else { return }
            webView.goForward()
        }
    }

    @ViewBuilder
    private var bottomBarLayer: some View {
        if !isLandingPage {
            VStack {
                Spacer()
                FloatingAddressBar(
                    urlString: addressBarBinding,
                    tabManager: tabManager,
                    onSubmit: executeAddressBarSubmit
                )
                .matchedGeometryEffect(id: "sharedAddressBarKey", in: addressBarNamespace)
                .padding(.bottom, 40)
                .transition(.asymmetric(insertion: .identity, removal: .opacity))
            }
            .frame(maxWidth: .infinity)
            .zIndex(5)
        }
    }
}

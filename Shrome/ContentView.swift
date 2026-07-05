//
//  ContentView.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI
import AppKit
import LocalAuthentication
import WebKit

struct ContentView: View {
    var initialURL: URL? = nil

    @StateObject private var tabManager = TabManager()
    @State private var isSidebarVisible = false
    @State private var showHistoryPanel = false

    @Namespace private var addressBarNamespace

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .light
    @AppStorage("autoHideSidebar") private var autoHideSidebar: Bool = false
    @AppStorage("searchEngine") private var searchEngine: String = "Google"
    @AppStorage("userPreferredName") private var userPreferredName: String = ""
    @AppStorage("hasCompletedNameOnboarding") private var hasCompletedNameOnboarding: Bool = false

    @Environment(\.isPrivateWindow) private var isPrivateWindow
    @Environment(\.openWindow) private var openWindow
    @Environment(\.managedObjectContext) private var viewContext

    @State private var isEdgeHovered = false
    @State private var hideTask: Task<Void, Never>? = nil

    @State private var isPrivateWindowUnlocked = false
    @AppStorage("requirePrivateWindowAuth") private var requirePrivateWindowAuth: Bool = true
    @State private var biometricErrorMessage: String? = nil
    @State private var hostWindow: NSWindow?
    @State private var displayURLString: String = ""

    private var isLandingPage: Bool {
        tabManager.activeTab.url.absoluteString == "about:blank"
    }

    // BUG FIX: previously derived from SunAppearanceManager's sunset/sunrise
    // calculation. "System" now just passes `nil` to .preferredColorScheme,
    // which tells SwiftUI to defer to macOS's own appearance setting instead
    // of us tracking it ourselves.
    private var colorSchemeOverride: ColorScheme? {
        switch appearanceMode {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
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
        tabManager.updateActiveUrl(urlString: displayURLString, searchEngine: searchEngine)
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

            bottomBarLayer

            if isPrivateWindow && requirePrivateWindowAuth && !isPrivateWindowUnlocked {
                ZStack {
                    Color.clear
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.shromePrivate)

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
                        .tint(.shromePrivate)
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
            if let url = initialURL {
                tabManager.createNewTab(urlString: url.absoluteString, isPrivate: isPrivateWindow)
                if let blankTab = tabManager.tabs.first(where: { $0.url.absoluteString == "about:blank" && $0.id != tabManager.activeTabId }) {
                    tabManager.tabs.removeAll { $0.id == blankTab.id }
                }
                displayURLString = url.absoluteString
            } else {
                displayURLString = tabManager.activeTab.urlString == "about:blank"
                    ? ""
                    : tabManager.activeTab.urlString
            }

            if isPrivateWindow {
                if tabManager.tabs.isEmpty {
                    tabManager.createNewTab(isPrivate: true)
                } else {
                    for i in 0..<tabManager.tabs.count {
                        tabManager.tabs[i].isPrivate = true
                    }
                }
                if requirePrivateWindowAuth {
                    triggerTouchIDPrompt()
                }
            }
        }
        .onDisappear {
            hideTask?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            guard let closingWindow = notification.object as? NSWindow, closingWindow === hostWindow else { return }
            for tab in tabManager.tabs {
                WebViewPool.shared.releaseWebView(for: tab.id)
            }
        }
        .onChange(of: tabManager.activeTabId) { _, _ in
            let urlStr = tabManager.activeTab.urlString
            displayURLString = urlStr == "about:blank" ? "" : urlStr
        }
        .onChange(of: tabManager.activeTab.urlString) { _, newValue in
            if newValue != "about:blank" {
                displayURLString = newValue
            }
        }
        .animation(.shromeBouncy, value: isLandingPage)
        .preferredColorScheme(tabManager.activeTab.isPrivate ? .dark : colorSchemeOverride)
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
        .onReceive(NotificationCenter.default.publisher(for: .openNewTabFromLink)) { note in
            guard let url = note.object as? URL else { return }
            withAnimation(.shromeBouncy) {
                tabManager.createNewTab(urlString: url.absoluteString, isPrivate: isPrivateWindow)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionCloseTab"))) { _ in
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

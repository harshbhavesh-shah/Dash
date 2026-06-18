//
//  ContentView.swift
//  Shrome
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var tabManager = TabManager()
    @State private var isSidebarVisible = false
    @State private var showHistoryPanel = false
    
    @Namespace private var addressBarNamespace
    
    @AppStorage("useDarkMode") private var useDarkMode: Bool = false
    @AppStorage("useMagicMode") private var useMagicMode: Bool = false
    @AppStorage("autoHideSidebar") private var autoHideSidebar: Bool = false
    
    // Apple native system window context checks
    @Environment(\.isPrivateWindow) private var isPrivateWindow
    @Environment(\.openWindow) private var openWindow
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var isEdgeHovered = false
    @State private var hideTask: Task<Void, Never>? = nil
    
    private var isLandingPage: Bool {
        return tabManager.activeTab.url.absoluteString == "about:blank"
    }
    
    private var sidebarOffset: CGFloat {
        if !autoHideSidebar { return 0 }
        if isSidebarVisible { return 0 }
        if isEdgeHovered { return 0 }
        return -350
    }
    
    private var shouldUseNativeButtons: Bool {
        return autoHideSidebar && !isSidebarVisible && !isEdgeHovered
    }
    
    private var addressBarBinding: Binding<String> {
        Binding(
            get: { tabManager.activeTab.urlString },
            set: { newValue in
                if let index = tabManager.tabs.firstIndex(where: { $0.id == tabManager.activeTabId }) {
                    tabManager.tabs[index].urlString = newValue
                }
            }
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
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isEdgeHovered = true
            }
        } else {
            hideTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if !Task.isCancelled {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            isEdgeHovered = false
                        }
                    }
                }
            }
        }
    }
    
    private func executeAddressBarSubmit() {
        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
            tabManager.updateActiveUrl(urlString: tabManager.activeTab.urlString)
        }
        
        if autoHideSidebar && !isSidebarVisible {
            hideTask?.cancel()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isEdgeHovered = false
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // LAYER 1: Core Web Render view matrices
            BrowserView(tabManager: tabManager, isSidebarVisible: browserSidebarBinding, namespace: addressBarNamespace)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // LAYER 2: Sliding Sidebar Management View
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
            
            // LAYER 3: Dynamic Bottom Pill Address Bar
            bottomBarLayer
        }
        .background(WindowHacker(showNativeButtons: shouldUseNativeButtons).frame(width: 0, height: 0))
        .onAppear {
            // Force strict privacy context mapping on environment birth
            if isPrivateWindow {
                if tabManager.tabs.isEmpty {
                    tabManager.createNewTab(isPrivate: true)
                } else {
                    for i in 0..<tabManager.tabs.count {
                        tabManager.tabs[i].isPrivate = true
                    }
                }
            }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.82), value: isLandingPage)
        .preferredColorScheme((useDarkMode || useMagicMode || tabManager.activeTab.isPrivate) ? .dark : .light)
        .sheet(isPresented: $showHistoryPanel) {
            HistoryView(tabManager: tabManager) {
                showHistoryPanel = false
            }
            .environment(\.managedObjectContext, viewContext)
        }
        .background {
            Group {
                // Keyboard Action Targets
                Button("New Tab") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        // Dynamically scale privacy state based on host window profile
                        tabManager.createNewTab(isPrivate: isPrivateWindow)
                    }
                }
                .keyboardShortcut("t", modifiers: .command)
                
                Button("New Private Window") {
                    openWindow(id: "PrivateShromeWindow")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Button("New Window") {
                    openWindow(id: "ShromeWindow")
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Reload") {
                    tabManager.reloadActiveTab()
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button("Show History") {
                    showHistoryPanel = true
                }
                .keyboardShortcut("y", modifiers: .command)
            }
            // Connect menu items to internal view processes
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionNewTab"))) { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    tabManager.createNewTab(isPrivate: isPrivateWindow)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionCloseTab"))) { _ in
                tabManager.closeTab(id: tabManager.activeTabId)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionReload"))) { _ in
                tabManager.reloadActiveTab()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionToggleSidebar"))) { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isSidebarVisible.toggle()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MenuActionShowHistory"))) { _ in
                showHistoryPanel = true
            }
            .hidden()
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

//
//  ContentView.swift
//  Shrome
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var tabManager = TabManager()
    @State private var isSidebarVisible = false
    
    @AppStorage("useDarkMode") private var useDarkMode: Bool = false
    @AppStorage("useMagicMode") private var useMagicMode: Bool = false
    @AppStorage("autoHideSidebar") private var autoHideSidebar: Bool = false
    
    @Environment(\.isPrivateWindow) private var isPrivateWindow
    @Environment(\.openWindow) private var openWindow
    
    @State private var isEdgeHovered = false
    
    // --- NEW: THE COUNTDOWN TIMER ---
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
    
    // --- NEW: THE PHYSICS & TIMING CONTROLLER ---
    private func handleHover(isHovering: Bool) {
        guard autoHideSidebar && !isSidebarVisible else { return }
        
        // Always cancel the countdown if the mouse moves in or out
        hideTask?.cancel()
        
        if isHovering {
            // Instantly snap open with a snappy spring
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isEdgeHovered = true
            }
        } else {
            // Start the 1.5-second countdown to hide
            hideTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                
                // If the user hasn't hovered back in, tuck it away!
                if !Task.isCancelled {
                    await MainActor.run {
                        // A slightly slower, softer spring for the exit
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            isEdgeHovered = false
                        }
                    }
                }
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // LAYER 1: THE CORE
            BrowserView(tabManager: tabManager, isSidebarVisible: $isSidebarVisible)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // LAYER 2: THE SIDEBAR
                        SidebarView(tabManager: tabManager, isVisible: $isSidebarVisible)
                            .offset(x: sidebarOffset)
                            // --- THE PHYSICS FIX: Force it to glide whenever the offset changes ---
                            .onHover { hovering in
                                handleHover(isHovering: hovering)
                            }
                            .zIndex(10)
            
            // LAYER 2.5: THE INVISIBLE TRIPWIRE
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
            
            // LAYER 3: THE BOTTOM BAR
            if !isLandingPage {
                VStack {
                    Spacer()
                    FloatingAddressBar(
                        urlString: Binding(
                            get: { tabManager.activeTab.urlString },
                            set: { newValue in
                                if let index = tabManager.tabs.firstIndex(where: { $0.id == tabManager.activeTabId }) {
                                    tabManager.tabs[index].urlString = newValue
                                }
                            }
                        ),
                        tabManager: tabManager,
                        onSubmit: {
                            tabManager.updateActiveUrl(urlString: tabManager.activeTab.urlString)
                            if autoHideSidebar && !isSidebarVisible {
                                // Instantly hide without delay when searching
                                hideTask?.cancel()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isEdgeHovered = false
                                }
                            }
                        }
                    )
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .frame(maxWidth: .infinity)
                .zIndex(5)
            }
        }
        .background(WindowHacker(showNativeButtons: shouldUseNativeButtons).frame(width: 0, height: 0))
        .onAppear {
            if isPrivateWindow && tabManager.tabs.count == 1 {
                tabManager.tabs[0].isPrivate = true
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isLandingPage)
        .preferredColorScheme((useDarkMode || useMagicMode || tabManager.activeTab.isPrivate) ? .dark : .light)
        .background {
            Group {
                Button("New Tab") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        tabManager.createNewTab()
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
            }
            .hidden()
        }
    }
}
#Preview{
    ContentView()
}


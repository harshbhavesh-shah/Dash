//
//  BrowserView.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI

struct BrowserView: View {
    @ObservedObject var tabManager: TabManager
    @Binding var isSidebarVisible: Bool
    
    // --- TRACKING THE COSMIC FLOTILLA ---
    @State private var animatedTabIds: Set<UUID> = []
    
    // Internal state to kick off the scale transformation on render
    @State private var entranceScale: CGFloat = 0.3
    @State private var entranceOpacity: Double = 0.0
    
    private var activeTabBinding: Binding<Tab> {
        Binding(
            get: { tabManager.activeTab },
            set: { newValue in
                if let index = tabManager.tabs.firstIndex(where: { $0.id == tabManager.activeTabId }) {
                    tabManager.tabs[index] = newValue
                }
            }
        )
    }
    
    var body: some View {
        ZStack {
            if tabManager.activeTab.url.absoluteString == "about:blank" {
                GravityLandingView(urlString: Binding(
                    get: { tabManager.activeTab.urlString },
                    set: { newValue in
                        if let index = tabManager.tabs.firstIndex(where: { $0.id == tabManager.activeTabId }) {
                            tabManager.tabs[index].urlString = newValue
                        }
                    }
                )) { newUrl in
                    tabManager.updateActiveUrl(urlString: newUrl)
                    
                    // Collapse the sidebar when searching
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isSidebarVisible = false
                    }
                }
                // --- HARDWARE OPTIMIZED TRANSFORMATIONS ---
                .scaleEffect(animatedTabIds.contains(tabManager.activeTabId) ? 1.0 : entranceScale)
                .opacity(animatedTabIds.contains(tabManager.activeTabId) ? 1.0 : entranceOpacity)
                
            } else {
                // The actual web engine core
                WebView(tab: activeTabBinding)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: tabManager.activeTabId) { _, newId in
            triggerCenterBurst(for: newId)
        }
        .onAppear {
            triggerCenterBurst(for: tabManager.activeTabId)
        }
    }
    
    // --- THE APEX ANIMATOR ---
    private func triggerCenterBurst(for tabId: UUID) {
        guard !animatedTabIds.contains(tabId) else { return }
        
        if tabManager.activeTab.url.absoluteString == "about:blank" {
            // Drop initial state just a tiny bit lower so the scaling journey is clearer
            entranceScale = 0.5
            entranceOpacity = 0.0
            
            // --- CINEMATIC SMOOTHING CALIBRATION ---
            // Shifting response to 0.42 expands the duration window by ~50%
            // DampingFraction at 0.76 cleanly rounds out the deceleration phase
            withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                entranceScale = 1.0
                entranceOpacity = 1.0
            }
            
            animatedTabIds.insert(tabId)
        } else {
            animatedTabIds.insert(tabId)
        }
    }
}

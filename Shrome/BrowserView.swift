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
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                // The actual web engine
                WebView(tab: activeTabBinding)
                    .ignoresSafeArea()
            }
        }
        // Animate the switch between landing page and website
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: tabManager.activeTab.url)
    }
}

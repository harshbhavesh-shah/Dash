//
//  BrowserView.swift
//  Shrome
//

import SwiftUI

struct BrowserView: View {
    @ObservedObject var tabManager: TabManager
    @Binding var isSidebarVisible: Bool
    
    // --- CONNECT THE COUPLING NAMESPACE ---
    var namespace: Namespace.ID
    
    var body: some View {
        ZStack {
            if tabManager.activeTab.url.absoluteString == "about:blank" {
                GravityLandingView(
                    urlString: Binding(
                        get: { tabManager.activeTab.urlString },
                        set: { newValue in
                            if let index = tabManager.tabs.firstIndex(where: { $0.id == tabManager.activeTabId }) {
                                tabManager.tabs[index].urlString = newValue
                            }
                        }
                    ),
                    namespace: namespace // Pass down safely
                ) { newUrl in
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                        tabManager.updateActiveUrl(urlString: newUrl)
                        isSidebarVisible = false
                    }
                }
                // --- FIXED: THIS IS THE GOLDEN LINK ---
                // This injects the tab manager into the environment so GravityLandingView can read it safely!
                .environmentObject(tabManager)
                
            } else {
                WebView(tab: Binding(
                    get: { tabManager.activeTab },
                    set: { newValue in
                        if let index = tabManager.tabs.firstIndex(where: { $0.id == tabManager.activeTabId }) {
                            tabManager.tabs[index] = newValue
                        }
                    }
                ))
                .ignoresSafeArea()
            }
        }
    }
}

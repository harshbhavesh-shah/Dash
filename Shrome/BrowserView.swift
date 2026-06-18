//
//  BrowserView.swift
//  Shrome
//

import SwiftUI

struct BrowserView: View {
    @ObservedObject var tabManager: TabManager
    @Binding var isSidebarVisible: Bool
    var namespace: Namespace.ID
    
    // --- ADD THIS LINE ---
    @AppStorage("searchEngine") private var searchEngine: String = "Google"
    
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
                    namespace: namespace
                ) { newUrl in
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
                        // --- FIXED: Pass the storage token here too ---
                        tabManager.updateActiveUrl(urlString: newUrl, searchEngine: searchEngine)
                        isSidebarVisible = false
                    }
                }
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

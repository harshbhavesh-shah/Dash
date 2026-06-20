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
                        get: {
                            // Map "about:blank" to "" here rather than
                            // mutating the tab's stored urlString on
                            // appear — GravityLandingView doesn't remount
                            // when switching between two blank tabs (it's
                            // the same view identity), so a one-time
                            // appear-based clear only ever worked for the
                            // first blank tab anyone visited.
                            let current = tabManager.activeTab.urlString
                            return current == "about:blank" ? "" : current
                        },
                        set: { newValue in
                            if let index = tabManager.tabs.firstIndex(where: { $0.id == tabManager.activeTabId }) {
                                tabManager.tabs[index].urlString = newValue
                            }
                        }
                    ),
                    namespace: namespace
                ) { newUrl in
                    withAnimation(.shromeBouncy) {
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

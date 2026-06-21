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
    var namespace: Namespace.ID
    
    // --- ADD THIS LINE ---
    @AppStorage("searchEngine") private var searchEngine: String = "Google"
    
    var body: some View {
        ZStack {
            ForEach(tabManager.tabs.filter { $0.url.absoluteString != "about:blank" }) { tab in
                WebView(tab: bindingForTab(id: tab.id))
                    .id(tab.id)
                    .ignoresSafeArea()
                    .opacity(tab.id == tabManager.activeTabId ? 1 : 0)
                    .allowsHitTesting(tab.id == tabManager.activeTabId)
                    .zIndex(tab.id == tabManager.activeTabId ? 1 : 0)
            }

            if tabManager.activeTab.url.absoluteString == "about:blank" {
                GravityLandingView(
                    urlString: Binding(
                        get: {
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
                .zIndex(2)
            }
        }
    }

    private func bindingForTab(id: UUID) -> Binding<Tab> {
        Binding(
            get: {
                tabManager.tabs.first(where: { $0.id == id })
                    ?? Tab(id: id, url: URL(string: "about:blank")!, urlString: "about:blank", title: "New Tab", isPrivate: false)
            },
            set: { newValue in
                if let index = tabManager.tabs.firstIndex(where: { $0.id == id }) {
                    tabManager.tabs[index] = newValue
                }
            }
        )
    }
}

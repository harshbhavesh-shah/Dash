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
            // FIX: Every open (non-blank) tab now renders its own
            // persistent WebView, kept mounted (just hidden) in the
            // background via .id(tab.id) instead of a single shared
            // WebView that got re-navigated every time the active tab
            // changed. Combined with bindingForTab(id:) below — which is
            // scoped to one FIXED tab id rather than "whichever tab is
            // active" — this is the actual fix for tabs cloning each
            // other's content: each WebView only ever reads/writes its own
            // tab, and the underlying WKWebView (see WebViewPool) is never
            // handed to a different tab. As a bonus, switching tabs is now
            // instant (no re-navigation) and preserves scroll position/
            // zoom/in-page state per tab, the way a real browser tab does.
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
                .zIndex(2)
            }
        }
    }

    /// A Binding scoped to one SPECIFIC tab id — not "whichever tab is
    /// currently active." The old binding always resolved to
    /// tabManager.activeTab regardless of which tab's WebView was asking,
    /// which is exactly how a stale background navigation could end up
    /// overwriting a different tab's stored URL. This is the other half of
    /// the structural fix (see WebViewPool's comment for the other half).
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

//
//  WebViewPool.swift
//  Shrome
//

import WebKit
import Foundation
import Combine

class WebViewPool {
    static let shared = WebViewPool()

    // FIX: This used to be a small pool of generic, interchangeable
    // WKWebViews shared across EVERY tab in a window — whichever tab was
    // active simply got handed whatever webview was dequeued and had it
    // re-navigated to that tab's URL. That meant there was no such thing
    // as "this tab's webview": a navigation kicked off for Tab A could
    // still be resolving (or fire a stale KVO update) after the user
    // switched to Tab B, and since the webview itself carried no concept
    // of which tab it belonged to, the result could land on whichever tab
    // happened to be active by the time the callback fired — the actual
    // root cause of tabs visibly "cloning" each other's content. No amount
    // of timing/race patching in WindowUtils.swift could fix that, because
    // the shared instance was the bug, not the timing.
    //
    // tabWebViews now gives each tab its own dedicated, persistent
    // WKWebView for as long as that tab stays open. The structural fix:
    // there's no longer any shared mutable navigation state for two tabs
    // to race over.
    private var tabWebViews: [UUID: WKWebView] = [:]

    // Warm, not-yet-claimed webviews ready to be handed to whichever tab
    // needs one next — same pre-warming idea as before, just scoped to
    // "ready for the next NEW tab" rather than "shared across all open
    // tabs simultaneously."
    private var standardPool: [WKWebView] = []
    private var privatePool: [WKWebView] = []
    private let maxPoolSize = 3
    
    // FIX: AdBlocker.compileContentRuleList(...) is async and can take long
    // enough (especially on cold launch) that the very first WebViews created
    // by warmUp() get built before `AdBlocker.shared.ruleList` is non-nil.
    // Those WebViews silently skip `userContentController.add(ruleList)` and
    // never get network-level ad blocking — which is exactly why the first
    // video/tab leaks ads while every subsequent one (created after rules
    // finish compiling) is clean.
    //
    // We track every WebView created before the rule list was ready —
    // whether it's still sitting in the pool OR has already been dequeued
    // and handed to a live tab — using a weak hash table so we never retain
    // a closed WebView. The moment AdBlocker finishes compiling, we backfill
    // the rule list onto all of them.
    private var pendingRuleListTargets = NSHashTable<WKWebView>.weakObjects()
    private var ruleListCancellable: AnyCancellable?
    
    private init() {
        ruleListCancellable = AdBlocker.shared.$ruleList
            .compactMap { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ruleList in
                self?.backfillRuleList(ruleList)
            }
    }
    
    /// Retroactively attaches the compiled rule list to any WebView that was
    /// created before compilation finished. Safe to call once; pending set
    /// is cleared after.
    private func backfillRuleList(_ ruleList: WKContentRuleList) {
        let targets = pendingRuleListTargets.allObjects
        for webView in targets {
            webView.configuration.userContentController.add(ruleList)
        }
        pendingRuleListTargets.removeAllObjects()
        print("🛡️ Deflector Shields backfilled onto \(targets.count) pre-existing WebView(s).")
    }
    
    /// Pre-instantiates background processes so they are ready before the user requests a tab.
    func warmUp() {
        DispatchQueue.main.async {
            while self.standardPool.count < self.maxPoolSize {
                self.standardPool.append(self.createFreshWebView(isPrivate: false))
            }
            while self.privatePool.count < self.maxPoolSize {
                self.privatePool.append(self.createFreshWebView(isPrivate: true))
            }
            print("⚡️ Shrome Process Pool Warmed: Standard (\(self.standardPool.count)), Private (\(self.privatePool.count))")
        }
    }

    /// Returns the persistent WKWebView for this specific tab, claiming a
    /// pre-warmed one (or creating a fresh one) the first time the tab
    /// needs it. The SAME instance is returned every time for the same tab
    /// id, for as long as that tab stays open — this is the core of the
    /// per-tab fix. Switching tabs just shows/hides the right instance
    /// instead of re-navigating a shared one.
    func webView(for tabId: UUID, isPrivate: Bool) -> WKWebView {
        if let existing = tabWebViews[tabId] {
            return existing
        }
        let webView = dequeueWebView(isPrivate: isPrivate)
        tabWebViews[tabId] = webView
        return webView
    }

    /// Non-creating lookup for callers (e.g. Back/Forward menu actions)
    /// that need to check or act on a tab's webview without accidentally
    /// spinning up a brand new one for a tab that doesn't have one yet
    /// (e.g. it's still sitting on the landing page).
    func existingWebView(for tabId: UUID) -> WKWebView? {
        tabWebViews[tabId]
    }

    /// Call when a tab is actually closed, so its webview is released
    /// instead of leaking in the registry forever.
    func releaseWebView(for tabId: UUID) {
        guard let webView = tabWebViews.removeValue(forKey: tabId) else { return }
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }
    
    /// Pops an instantly ready WebView from the pool, or creates an optimized fallback if depleted.
    private func dequeueWebView(isPrivate: Bool) -> WKWebView {
        if isPrivate {
            if !privatePool.isEmpty {
                let view = privatePool.removeFirst()
                replenish(isPrivate: true)
                return view
            }
            return createFreshWebView(isPrivate: true)
        } else {
            if !standardPool.isEmpty {
                let view = standardPool.removeFirst()
                replenish(isPrivate: false)
                return view
            }
            return createFreshWebView(isPrivate: false)
        }
    }
    
    private func replenish(isPrivate: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if isPrivate {
                if self.privatePool.count < self.maxPoolSize {
                    self.privatePool.append(self.createFreshWebView(isPrivate: true))
                }
            } else {
                if self.standardPool.count < self.maxPoolSize {
                    self.standardPool.append(self.createFreshWebView(isPrivate: false))
                }
            }
        }
    }
    
    private func createFreshWebView(isPrivate: Bool) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        if isPrivate {
            config.websiteDataStore = .nonPersistent()
        } else {
            config.websiteDataStore = .default()
        }
        
        config.preferences.isElementFullscreenEnabled = true
        
        // The JS-based sniper script has no async dependency, so it's always
        // safe to attach immediately.
        config.userContentController.addUserScript(AdBlocker.shared.getYouTubeSniper())
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        // FIX: macOS WKWebView ships with pinch-to-zoom support already
        // built in (it drives the trackpad magnify gesture the same way
        // NSScrollView does) — it's just off by default. Turning this on
        // is the entire fix; no custom gesture recognizer needed.
        webView.allowsMagnification = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        
        // FIX: Attach the rule list if it's ready; otherwise register this
        // WebView for retroactive backfill once AdBlocker finishes compiling.
        // (Adding to userContentController after WKWebView creation works
        // identically to adding it via the config beforehand.)
        if let ruleList = AdBlocker.shared.ruleList {
            webView.configuration.userContentController.add(ruleList)
        } else {
            pendingRuleListTargets.add(webView)
        }
        
        return webView
    }
}

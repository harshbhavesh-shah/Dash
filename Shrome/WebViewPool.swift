//
//  WebViewPool.swift
//  Shrome
//

import WebKit
import Foundation
import Combine

class WebViewPool {
    static let shared = WebViewPool()
    
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
        for webView in pendingRuleListTargets.allObjects {
            webView.configuration.userContentController.add(ruleList)
        }
        pendingRuleListTargets.removeAllObjects()
        print("🛡️ Deflector Shields backfilled onto \(pendingRuleListTargets.count) pre-existing WebView(s).")
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
    
    /// Pops an instantly ready WebView from the pool, or creates an optimized fallback if depleted.
    func dequeueWebView(isPrivate: Bool) -> WKWebView {
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

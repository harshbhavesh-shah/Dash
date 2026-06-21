//
//  WebViewPool.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

import WebKit
import Foundation
import Combine

class WebViewPool {
    static let shared = WebViewPool()
    private var tabWebViews: [UUID: WKWebView] = [:]
    private var standardPool: [WKWebView] = []
    private var privatePool: [WKWebView] = []
    private let maxPoolSize = 3
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
    private func backfillRuleList(_ ruleList: WKContentRuleList) {
        let targets = pendingRuleListTargets.allObjects
        for webView in targets {
            webView.configuration.userContentController.add(ruleList)
        }
        pendingRuleListTargets.removeAllObjects()
        print("🛡️ Deflector Shields backfilled onto \(targets.count) pre-existing WebView(s).")
    }
    
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
    func webView(for tabId: UUID, isPrivate: Bool) -> WKWebView {
        if let existing = tabWebViews[tabId] {
            return existing
        }
        let webView = dequeueWebView(isPrivate: isPrivate)
        tabWebViews[tabId] = webView
        return webView
    }
    func existingWebView(for tabId: UUID) -> WKWebView? {
        tabWebViews[tabId]
    }
    func releaseWebView(for tabId: UUID) {
        guard let webView = tabWebViews.removeValue(forKey: tabId) else { return }
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }
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
        config.userContentController.addUserScript(AdBlocker.shared.getYouTubeSniper())
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        if let ruleList = AdBlocker.shared.ruleList {
            webView.configuration.userContentController.add(ruleList)
        } else {
            pendingRuleListTargets.add(webView)
        }
        
        return webView
    }
}

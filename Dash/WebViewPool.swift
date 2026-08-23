//
//  WebViewPool.swift
//  Dash
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
    private var settingsObserver: NSObjectProtocol?

    // BUG FIX: "Block trackers" in Settings previously did nothing — the ad
    // rule list and YouTube ad-skip script were applied unconditionally to
    // every WebView. This reads the live setting (defaulting to true, same
    // as GravityPreferences) and keeps every known WebView — pooled or
    // already assigned to a tab — in sync with it.
    private var blockTrackersEnabled: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "blockTrackers") == nil { return true }
        return defaults.bool(forKey: "blockTrackers")
    }

    private init() {
        ruleListCancellable = AdBlocker.shared.$ruleList
            .compactMap { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] ruleList in
                self?.backfillRuleList(ruleList)
            }

        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.syncTrackerBlockingAcrossAllWebViews()
        }
    }

    deinit {
        if let settingsObserver { NotificationCenter.default.removeObserver(settingsObserver) }
    }

    private func backfillRuleList(_ ruleList: WKContentRuleList) {
        guard blockTrackersEnabled else {
            pendingRuleListTargets.removeAllObjects()
            return
        }
        let targets = pendingRuleListTargets.allObjects
        for webView in targets {
            webView.configuration.userContentController.add(ruleList)
        }
        pendingRuleListTargets.removeAllObjects()
        print("🛡️ Deflector Shields backfilled onto \(targets.count) pre-existing WebView(s).")
    }

    /// Re-applies (or strips) tracker blocking on every WebView we know
    /// about — pooled and currently assigned to a tab — whenever the
    /// "Block trackers" preference changes.
    ///
    /// Note: the content-rule-list half (network + CSS blocking) applies
    /// immediately, including to future requests on already-open tabs. The
    /// YouTube ad-skip script is injected at document-start, so a
    /// currently-loaded page needs a reload/new navigation before a change
    /// takes effect there.
    private func syncTrackerBlockingAcrossAllWebViews() {
        let enabled = blockTrackersEnabled
        let allWebViews = standardPool + privatePool + Array(tabWebViews.values)

        for webView in allWebViews {
            let controller = webView.configuration.userContentController
            controller.removeAllContentRuleLists()
            controller.removeAllUserScripts()

            guard enabled else { continue }

            controller.addUserScript(AdBlocker.shared.getYouTubeSniper())
            if let ruleList = AdBlocker.shared.ruleList {
                controller.add(ruleList)
            } else {
                pendingRuleListTargets.add(webView)
            }
        }
    }
    
    func warmUp() {
        DispatchQueue.main.async {
            while self.standardPool.count < self.maxPoolSize {
                self.standardPool.append(self.createFreshWebView(isPrivate: false))
            }
            while self.privatePool.count < self.maxPoolSize {
                self.privatePool.append(self.createFreshWebView(isPrivate: true))
            }
            print("⚡️ Dash Process Pool Warmed: Standard (\(self.standardPool.count)), Private (\(self.privatePool.count))")
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

        if blockTrackersEnabled {
            config.userContentController.addUserScript(AdBlocker.shared.getYouTubeSniper())
        }
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

        if blockTrackersEnabled {
            if let ruleList = AdBlocker.shared.ruleList {
                webView.configuration.userContentController.add(ruleList)
            } else {
                pendingRuleListTargets.add(webView)
            }
        }
        
        return webView
    }
}

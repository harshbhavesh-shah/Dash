//
//  WindowUtils.swift
//  Shrome
//

import SwiftUI
import AppKit
import WebKit

extension Notification.Name {
    static let openNewTabFromLink = Notification.Name("openNewTabFromLink")
}

struct WebView: NSViewRepresentable {
    @Binding var tab: Tab
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        // FIX: Each tab now gets its OWN persistent WKWebView, keyed by
        // tab.id, instead of a generic interchangeable instance shared
        // across every tab in the window — see WebViewPool. The same
        // instance is returned every time this tab becomes active again,
        // which is what actually fixes tabs "cloning" each other's
        // content: there's no shared mutable navigation state left for two
        // tabs to race over, structurally, not just patched timing.
        let webView = WebViewPool.shared.webView(for: tab.id, isPrivate: tab.isPrivate)
        
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        context.coordinator.setupUrlObservation(for: webView)
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.parent = self
        
        if let currentViewUrl = nsView.url, currentViewUrl.absoluteString != tab.url.absoluteString {
            // FIX: this WKWebView instance is shared/renavigated across tab
            // switches rather than recreated per tab, so a pinch-zoom level
            // set on the previous tab would otherwise carry over visually
            // onto whatever page loads next. Reset before navigating away.
            nsView.magnification = 1.0
            let request = URLRequest(url: tab.url)
            nsView.load(request)
        } else if nsView.url == nil && tab.url.absoluteString != "about:blank" {
            nsView.magnification = 1.0
            let request = URLRequest(url: tab.url)
            nsView.load(request)
        } else if context.coordinator.lastReloadTrigger != tab.reloadTrigger {
            nsView.reload()
            context.coordinator.lastReloadTrigger = tab.reloadTrigger
        }
    }

    // FIX: The webview must NOT be torn down here. WebViewPool owns it for
    // the tab's full lifetime (until the tab is actually closed), so
    // switching away from this tab and back later reattaches the exact
    // same instance — preserving scroll position, in-page JS state, zoom,
    // etc., the way a real browser tab behaves. Only detach the
    // about-to-be-deallocated Coordinator as this webview's delegate.
    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        if nsView.navigationDelegate === coordinator {
            nsView.navigationDelegate = nil
        }
        if nsView.uiDelegate === coordinator {
            nsView.uiDelegate = nil
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView
        var lastReloadTrigger: UUID
        var urlObservation: NSKeyValueObservation?
        
        init(_ parent: WebView) {
            self.parent = parent
            self.lastReloadTrigger = parent.tab.reloadTrigger
            super.init()
        }

        // Each Coordinator now belongs to exactly one tab for its entire
        // life (a fresh Coordinator is created whenever this tab's WebView
        // is remounted, but the underlying WKWebView and the tab it
        // represents never change out from under it) — so there's no
        // cross-tab attribution ambiguity left to guard against. Writing
        // straight to `self.parent.tab` is correct again, simply because
        // it's now structurally impossible for `parent.tab` to silently
        // resolve to a *different* tab than the one this webview is for.
        func setupUrlObservation(for webView: WKWebView) {
            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] view, _ in
                guard let self = self, let newUrl = view.url else { return }
                DispatchQueue.main.async {
                    if self.parent.tab.url != newUrl {
                        self.parent.tab.url = newUrl
                        self.parent.tab.urlString = newUrl.absoluteString
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let newUrl = webView.url {
                DispatchQueue.main.async {
                    if self.parent.tab.url != newUrl {
                        self.parent.tab.url = newUrl
                        self.parent.tab.urlString = newUrl.absoluteString
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                if let url = navigationAction.request.url {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .openNewTabFromLink, object: url)
                    }
                }
            }
            return nil
        }
    }
}

struct WindowHacker: NSViewRepresentable {
    var showNativeButtons: Bool
    // Hands the resolved NSWindow back to the caller — lets ContentView
    // know which physical window it's hosted in, which menu-action
    // handlers need in order to act only on the focused window (see FIX
    // below).
    var onResolveWindow: ((NSWindow) -> Void)? = nil
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { updateWindow(view.window) }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { updateWindow(nsView.window) }
    }
    
    private func updateWindow(_ window: NSWindow?) {
        guard let window = window else { return }
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.closeButton)?.isHidden = !showNativeButtons
        window.standardWindowButton(.miniaturizeButton)?.isHidden = !showNativeButtons
        window.standardWindowButton(.zoomButton)?.isHidden = !showNativeButtons
        onResolveWindow?(window)
    }
}

struct LiquidGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .withinWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

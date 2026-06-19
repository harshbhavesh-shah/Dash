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
        // PERF FIX: Instead of running an expensive constructor, dequeue a pre-heated viewport process instantly
        let webView = WebViewPool.shared.dequeueWebView(isPrivate: tab.isPrivate)
        
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Setup internal KVO observation channel
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
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView
        var lastReloadTrigger: UUID
        var urlObservation: NSKeyValueObservation?
        
        init(_ parent: WebView) {
            self.parent = parent
            self.lastReloadTrigger = parent.tab.reloadTrigger
            super.init()
        }
        
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

//
//  WindowUtils.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI
import AppKit
import WebKit

extension Notification.Name {
    static let openNewTabFromLink    = Notification.Name("openNewTabFromLink")
    static let openNewWindowWithURL  = Notification.Name("openNewWindowWithURL")
    static let openURLInNewWindow    = Notification.Name("openURLInNewWindow")
}

struct WebView: NSViewRepresentable {
    @Binding var tab: Tab
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WebViewPool.shared.webView(for: tab.id, isPrivate: tab.isPrivate)
        
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        context.coordinator.setupUrlObservation(for: webView)
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.parent = self
        
        if let currentViewUrl = nsView.url, currentViewUrl.absoluteString != tab.url.absoluteString {
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
        
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {

            guard let url = navigationAction.request.url,
                  url.absoluteString != "about:blank" else { return nil }

            DispatchQueue.main.async {
                let wantsNewWindow = (windowFeatures.width != nil ||
                                      windowFeatures.height != nil ||
                                      windowFeatures.x != nil ||
                                      windowFeatures.y != nil)

                if wantsNewWindow {
                    NotificationCenter.default.post(
                        name: .openNewWindowWithURL,
                        object: url
                    )
                } else {
                    NotificationCenter.default.post(
                        name: .openNewTabFromLink,
                        object: url
                    )
                }
            }
            return nil
        }
    }
}

struct WindowHacker: NSViewRepresentable {
    var showNativeButtons: Bool
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

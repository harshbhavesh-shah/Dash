//
//  WindowUtils.swift
//  Dash
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
    static let dashDidClearAllHistory = Notification.Name("dashDidClearAllHistory")
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
                     decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if navigationResponse.canShowMIMEType {
                decisionHandler(.allow)
            } else {
                decisionHandler(.download)
            }
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            DownloadManager.shared.track(download)
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            DownloadManager.shared.track(download)
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
    var windowAutosaveName: String = "DashMainWindow"
    var onResolveWindow: ((NSWindow) -> Void)? = nil

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            applyInitialSizeIfNeeded(to: window)
            updateWindow(window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { updateWindow(nsView.window) }
    }

    private func applyInitialSizeIfNeeded(to window: NSWindow) {
        let restoredFromSavedFrame = window.setFrameAutosaveName(windowAutosaveName)
        guard !restoredFromSavedFrame else { return }

        guard let screen = window.screen ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let targetSize = NSSize(width: screenFrame.width * 0.75, height: screenFrame.height * 0.75)
        let origin = NSPoint(
            x: screenFrame.origin.x + (screenFrame.width - targetSize.width) / 2,
            y: screenFrame.origin.y + (screenFrame.height - targetSize.height) / 2
        )
        window.setFrame(NSRect(origin: origin, size: targetSize), display: true)
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

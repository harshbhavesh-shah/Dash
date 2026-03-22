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
        let config = WKWebViewConfiguration()
        
        // 1. Stealth Mode Check
        // 1. Stealth Mode & Cookie Check
        if tab.isPrivate {
            config.websiteDataStore = .nonPersistent() // Burner phone mode
        } else {
            config.websiteDataStore = .default() // Permanent cookie jar (Stay logged in!)
        }
        // 2. Unlock Fullscreen Video Players
        config.preferences.isElementFullscreenEnabled = true
        
        // 3. Arm Deflector Shields & Snipers
        let blockTrackers = UserDefaults.standard.object(forKey: "blockTrackers") as? Bool ?? true
        
        if blockTrackers {
            if let ruleList = AdBlocker.shared.ruleList {
                config.userContentController.add(ruleList)
            }
            config.userContentController.addUserScript(AdBlocker.shared.getYouTubeSniper())
        }
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        
        // 4. Attach the Brains
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // 5. Masquerade as Modern Safari (Fixes the Google Images bug)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        
        // 6. The Single Page Application (SPA) Observer
        let coordinator = context.coordinator
        coordinator.urlObservation = webView.observe(\.url, options: [.new]) { [weak coordinator] view, _ in
            if let newUrl = view.url {
                DispatchQueue.main.async {
                    if let parent = coordinator?.parent, parent.tab.url != newUrl {
                        coordinator?.parent.tab.url = newUrl
                        coordinator?.parent.tab.urlString = newUrl.absoluteString
                    }
                }
            }
        }
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        if let currentViewUrl = nsView.url, currentViewUrl != tab.url {
            let request = URLRequest(url: tab.url)
            nsView.load(request)
        } else if nsView.url == nil && tab.url.absoluteString != "about:blank" {
            let request = URLRequest(url: tab.url)
            nsView.load(request)
        }
        else if context.coordinator.lastReloadTrigger != tab.reloadTrigger {
            nsView.reload()
            context.coordinator.lastReloadTrigger = tab.reloadTrigger
        }
    }
    
    // --- THE NEURAL NETWORK (COORDINATOR) ---
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView
        var lastReloadTrigger: UUID
        var urlObservation: NSKeyValueObservation?
        
        init(_ parent: WebView) {
            self.parent = parent
            self.lastReloadTrigger = parent.tab.reloadTrigger
            super.init()
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
        
        // 1. THE NEW TAB INTERCEPTOR
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

// --- THE WINDOW CONTROLS HACKER ---
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

// --- THE LIQUID GLASS MATERIAL ---
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

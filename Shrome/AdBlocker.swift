//
//  AdBlocker.swift
//  Shrome
//

import Foundation
import WebKit
import Combine

class AdBlocker: ObservableObject {
    static let shared = AdBlocker()
    
    @Published var ruleList: WKContentRuleList?
    @Published var isCompiled = false
    
    private init() {
        compileRules()
    }
    
    private func compileRules() {
        // Our Starter Pack of Deflector Shields
        let rulesJSON = """
        [
            {
                "trigger": { "url-filter": ".*" },
                "action": {
                    "type": "css-display-none",
                    "selector": ".ad, .ads, .advert, .banner, .promo, #ad, #ads, .ad-container, [aria-label='Advertisement']"
                }
            },
            {
                "trigger": { "url-filter": "(doubleclick\\\\.net|googleadservices\\\\.com|google-analytics\\\\.com|facebook\\\\.com/tr/|googlesyndication\\\\.com|taboola\\\\.com|outbrain\\\\.com)" },
                "action": { "type": "block" }
            }
        ]
        """
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "ShromeDeflectorShields",
            encodedContentRuleList: rulesJSON
        ) { [weak self] list, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Shield Malfunction: \(error.localizedDescription)")
                    return
                }
                self?.ruleList = list
                self?.isCompiled = true
                print("Deflector Shields Online. Bytecode compiled.")
            }
        }
    }
    
    // --- NEW: THE YOUTUBE SNIPER ---
    func getYouTubeSniper() -> WKUserScript {
        let js = """
        // Run this check every 100 milliseconds
        setInterval(() => {
            // Only engage if we are actually on YouTube
            if (!window.location.hostname.includes('youtube.com')) return;
            
            // Look for the various 'Skip Ad' buttons YouTube uses
            let skipButton = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button');
            
            // Look for the UI overlays that prove an ad is currently playing
            let adPreview = document.querySelector('.ytp-ad-preview-container');
            let adPlayerOverlay = document.querySelector('.ytp-ad-player-overlay');
            
            // Grab the actual video player element
            let video = document.querySelector('video');
            
            // If an ad is playing, neutralize it
            if (video && (adPreview || adPlayerOverlay)) {
                video.muted = true;          // Silence!
                video.playbackRate = 16.0;   // Maximum overdrive!
            }
            
            // If the skip button is available, click it immediately
            if (skipButton) {
                skipButton.click();
            }
        }, 100);
        """
        
        // Wrap it in a WebKit script object that runs after the document finishes loading
        return WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
    }
}

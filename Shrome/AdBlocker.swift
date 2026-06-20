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
        // FIX: `.ytd-ad-slot-renderer` (and friends) previously had a leading
        // dot, treating it as a CLASS selector. YouTube's ad containers
        // aren't classed that way — they're custom element TAG names
        // (Polymer/LitElement web components, e.g. <ytd-ad-slot-renderer>).
        // A dot-prefixed selector can never match a tag name, so that rule
        // was a silent no-op. Switched to proper tag selectors and added
        // the other companion/sidebar/in-feed ad tags YouTube actually uses
        // (this is what was letting the right-rail "Sponsored" card through).
        let rulesJSON = """
        [
            {
                "trigger": { "url-filter": ".*" },
                "action": {
                    "type": "css-display-none",
                    "selector": ".ad, .ads, .advert, .banner, .promo, #ad, #ads, .ad-container, [aria-label='Advertisement'], .ytp-ad-overlay-container, #player-ads, .ytp-ad-progress-list, ytd-ad-slot-renderer, ytd-display-ad-renderer, ytd-promoted-sparkles-web-renderer, ytd-promoted-video-renderer, ytd-companion-slot-renderer, ytd-action-companion-ad-renderer, ytd-in-feed-ad-layout-renderer, ytd-banner-promo-renderer, ytd-statement-banner-renderer, ytd-mealbar-promo-renderer, #masthead-ad"
                }
            },
            {
                "trigger": { "url-filter": "(doubleclick\\\\.net|googleadservices\\\\.com|google-analytics\\\\.com|analytics\\\\.|facebook\\\\.com/tr/|googlesyndication\\\\.com|taboola\\\\.com|outbrain\\\\.com|scorecardresearch\\\\.com|amazon-adsystem\\\\.com)" },
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
                print("Deflector Shields Online. Bytecode compiled natively.")
            }
        }
    }
    
    func getYouTubeSniper() -> WKUserScript {
        let js = """
        (function() {
            if (!window.location.hostname.includes('youtube.com')) return;

            // NOTE: .videoAdUiSkipButton added for embedded (iframe) players on
            // third-party sites, which is a real surface this script reaches
            // since the WKUserScript is forMainFrameOnly: false. The watch-page
            // player uses the .ytp-* classes; the embed player uses this one.
            const SKIP_SELECTORS = '.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button, .ytp-ad-skip-button-container button, button.ytp-ad-overlay-close-button, .videoAdUiSkipButton';

            // FIX: The root cause of skip-button clicks silently doing
            // nothing — element.click() only dispatches a synthetic 'click'
            // event. YouTube's player controls are Material/Polymer-style
            // components that commonly bind their real handler to
            // 'pointerdown'/'pointerup' (to feel instant, skipping the
            // ~300ms click delay), not 'click'. A bare .click() can land on
            // a button that's visibly there and "clickable" looking, while
            // the actual skip handler never fires. Dispatching a full
            // pointer+mouse event sequence at the button's real coordinates
            // covers every common handler style.
            function simulateClick(el) {
                const rect = el.getBoundingClientRect();
                const x = rect.left + rect.width / 2;
                const y = rect.top + rect.height / 2;
                const opts = {
                    bubbles: true,
                    cancelable: true,
                    composed: true,
                    view: window,
                    clientX: x,
                    clientY: y
                };

                try {
                    el.dispatchEvent(new PointerEvent('pointerover', opts));
                    el.dispatchEvent(new PointerEvent('pointerdown', { ...opts, button: 0 }));
                    el.dispatchEvent(new MouseEvent('mousedown', { ...opts, button: 0 }));
                    el.dispatchEvent(new PointerEvent('pointerup', { ...opts, button: 0 }));
                    el.dispatchEvent(new MouseEvent('mouseup', { ...opts, button: 0 }));
                    el.dispatchEvent(new MouseEvent('click', { ...opts, button: 0 }));
                } catch (e) {
                    // PointerEvent unsupported in this context — fall back
                    // to the plain method call rather than failing silently.
                    el.click();
                }
            }

            // FIX: Broader, more reliable ad-state detection. The previous
            // version only checked three selectors that don't all apply
            // throughout an ad's lifetime (.ytp-ad-preview-container in
            // particular is only present in the few seconds *before* an ad
            // starts, not while it's actually playing). The player itself
            // (#movie_player) gets an authoritative 'ad-showing' /
            // 'ad-interrupting' class for the entire duration of any ad.
            function isAdShowing() {
                const player = document.querySelector('#movie_player, .html5-video-player');
                if (player && (player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting'))) {
                    return true;
                }
                return !!document.querySelector('.ad-showing, .ytp-ad-player-overlay, .ytp-ad-text, .ytp-ad-preview-container');
            }

            function neutralizeAds() {
                const video = document.querySelector('video');
                const skipButton = document.querySelector(SKIP_SELECTORS);

                // Some skip buttons sit in the DOM disabled/greyed-out during
                // the mandatory pre-skip countdown before becoming
                // interactive — clicking then is a no-op, so only fire once
                // it's actually enabled (the 250ms poll below will catch it
                // the moment it flips).
                if (skipButton && skipButton.getAttribute('aria-disabled') !== 'true' && !skipButton.disabled) {
                    simulateClick(skipButton);
                }

                if (video && isAdShowing()) {
                    if (!video.muted) video.muted = true;

                    // FIX: YouTube's ad player actively resets playbackRate
                    // back to 1x shortly after a script changes it — a
                    // one-shot assignment (the old behavior) gets silently
                    // reverted within a frame or two and the ad plays out at
                    // normal speed. Reapplying it on every poll tick wins
                    // that race instead of losing it once and giving up.
                    if (video.playbackRate !== 16.0) {
                        try { video.playbackRate = 16.0; } catch (e) {}
                    }

                    if (isFinite(video.duration) && (video.duration - video.currentTime) > 0.3) {
                        try { video.currentTime = video.duration - 0.1; } catch (e) {}
                    }
                }
            }

            const observer = new MutationObserver(neutralizeAds);
            const targetNode = document.documentElement;
            if (targetNode) {
                observer.observe(targetNode, {
                    childList: true,
                    subtree: true,
                    attributes: true,
                    attributeFilter: ['class']
                });
            }

            // FIX: MutationObserver alone misses two things that don't
            // correspond to a fresh DOM mutation: (1) the skip button exists
            // in the DOM for several seconds before it becomes clickable —
            // clicking it too early is a no-op and the observer has no
            // reason to fire again once it's just sitting there enabled, and
            // (2) YouTube's playbackRate/currentTime resets happen on an
            // internal timer, not a DOM change. A continuous poll catches
            // both; the observer just makes us react instantly to the
            // common case (ad starting/ending) in between polls.
            setInterval(neutralizeAds, 250);

            neutralizeAds();
        })();
        """
        
        return WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }
    
    // --- NEW: THE DNS & PRECONNECT EXPRESS ENGINE ---
    /// Injects header linkage hints to resolve domains before the web view actively drives standard requests.
    func getPreconnectScript(for urlString: String) -> WKUserScript? {
        guard let url = URL(string: urlString), let host = url.host else { return nil }
        
        let js = """
        (function() {
            if (document.head) {
                const dnsHint = document.createElement('link');
                dnsHint.rel = 'dns-prefetch';
                dnsHint.href = 'https://\(host)';
                
                const connHint = document.createElement('link');
                connHint.rel = 'preconnect';
                connHint.href = 'https://\(host)';
                
                document.head.appendChild(dnsHint);
                document.head.appendChild(connHint);
            }
        })();
        """
        return WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }
}

//
//  LiquidGlassNowPlayingWidget.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI
import AppKit
import Combine

// MARK: - MediaRemote Bridge

/// Thin runtime bridge to MediaRemote.framework. All function pointers are
/// resolved once at init and cached — subsequent calls are just indirect
/// function calls, no repeated dlsym overhead.
private final class MediaRemoteBridge {
    static let shared = MediaRemoteBridge()

    // C function pointer types matching MediaRemote's exported signatures.
    private typealias MRMediaRemoteGetNowPlayingInfoFn = @convention(c) (
        DispatchQueue,
        @escaping ([String: Any]) -> Void
    ) -> Void

    private typealias MRMediaRemoteGetNowPlayingApplicationIsPlayingFn = @convention(c) (
        DispatchQueue,
        @escaping (Bool) -> Void
    ) -> Void

    private typealias MRMediaRemoteSendCommandFn = @convention(c) (
        Int,
        AnyObject?
    ) -> Bool

    private typealias MRNowPlayingClientGetBundleIdentifierFn = @convention(c) (AnyObject?) -> String?

    private let getNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFn?
    private let getIsPlaying: MRMediaRemoteGetNowPlayingApplicationIsPlayingFn?
    private let sendCommand: MRMediaRemoteSendCommandFn?

    // MediaRemote command constants (stable across macOS versions).
    private let kMRPlay            = 0
    private let kMRPause           = 1
    private let kMRTogglePlayPause = 2
    private let kMRNextTrack       = 4
    private let kMRPreviousTrack   = 5

    // Info dictionary keys.
    static let kTitle       = "kMRMediaRemoteNowPlayingInfoTitle"
    static let kArtist      = "kMRMediaRemoteNowPlayingInfoArtist"
    static let kAlbum       = "kMRMediaRemoteNowPlayingInfoAlbum"
    static let kDuration    = "kMRMediaRemoteNowPlayingInfoDuration"
    static let kElapsedTime = "kMRMediaRemoteNowPlayingInfoElapsedTime"
    static let kPlaybackRate = "kMRMediaRemoteNowPlayingInfoPlaybackRate"
    static let kArtworkData  = "kMRMediaRemoteNowPlayingInfoArtworkData"
    static let kArtworkMIME  = "kMRMediaRemoteNowPlayingInfoArtworkMIMEType"

    // Notification posted by MediaRemote when now-playing info changes.
    static let infoDidChangeNotification = Notification.Name(
        "kMRMediaRemoteNowPlayingInfoDidChangeNotification"
    )
    static let playbackStateDidChangeNotification = Notification.Name(
        "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"
    )

    private init() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_NOW
        ) else {
            getNowPlayingInfo = nil
            getIsPlaying      = nil
            sendCommand       = nil
            return
        }

        func resolve<T>(_ name: String) -> T? {
            guard let sym = dlsym(handle, name) else { return nil }
            return unsafeBitCast(sym, to: T.self)
        }

        getNowPlayingInfo = resolve("MRMediaRemoteGetNowPlayingInfo")
        getIsPlaying      = resolve("MRMediaRemoteGetNowPlayingApplicationIsPlaying")
        sendCommand       = resolve("MRMediaRemoteSendCommand")

        // Register for MediaRemote's own change notifications so we get
        // push updates instead of having to poll.
        if let registerFn: @convention(c) (DispatchQueue) -> Void =
            resolve("MRMediaRemoteRegisterForNowPlayingNotifications") {
            registerFn(.main)
        }
    }

    var isAvailable: Bool { getNowPlayingInfo != nil }

    func fetchNowPlayingInfo(completion: @escaping ([String: Any]) -> Void) {
        getNowPlayingInfo?(.main, completion)
    }

    func fetchIsPlaying(completion: @escaping (Bool) -> Void) {
        getIsPlaying?(.main, completion)
    }

    func togglePlayPause() { _ = sendCommand?(kMRTogglePlayPause, nil) }
    func nextTrack()       { _ = sendCommand?(kMRNextTrack, nil) }
    func previousTrack()   { _ = sendCommand?(kMRPreviousTrack, nil) }
}

// MARK: - Now Playing State Model

struct NowPlayingInfo: Equatable {
    var title:        String
    var artist:       String
    var album:        String
    var isPlaying:    Bool
    var duration:     TimeInterval   // seconds
    var elapsed:      TimeInterval   // seconds
    var playbackRate: Double
    var artwork:      NSImage?

    static func == (lhs: NowPlayingInfo, rhs: NowPlayingInfo) -> Bool {
        lhs.title == rhs.title &&
        lhs.artist == rhs.artist &&
        lhs.isPlaying == rhs.isPlaying &&
        lhs.duration == rhs.duration &&
        lhs.elapsed == rhs.elapsed
    }
}

// MARK: - Shared Monitor

/// Singleton that polls MediaRemote and publishes live NowPlayingInfo.
/// Single instance shared across all windows — one set of notifications,
/// one published state that every widget observes.
class SystemNowPlayingMonitor: ObservableObject {
    static let shared = SystemNowPlayingMonitor()

    @Published private(set) var nowPlaying: NowPlayingInfo? = nil

    private let bridge = MediaRemoteBridge.shared
    private var observers: [Any] = []

    private init() {
        guard bridge.isAvailable else { return }

        // Subscribe to MediaRemote's push notifications for info changes
        // and playback-state changes — refresh on either.
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(
            forName: MediaRemoteBridge.infoDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() })

        observers.append(nc.addObserver(
            forName: MediaRemoteBridge.playbackStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() })
    }

    /// Safe to call multiple times — idempotent first fetch.
    func ensureListening() {
        refresh()
    }

    func togglePlayPause() { bridge.togglePlayPause() }
    func nextTrack()       { bridge.nextTrack() }
    func previousTrack()   { bridge.previousTrack() }

    private func refresh() {
        bridge.fetchNowPlayingInfo { [weak self] info in
            guard !info.isEmpty else {
                self?.nowPlaying = nil
                return
            }

            let title  = info[MediaRemoteBridge.kTitle]  as? String ?? ""
            let artist = info[MediaRemoteBridge.kArtist] as? String ?? ""
            let album  = info[MediaRemoteBridge.kAlbum]  as? String ?? ""

            // Duration comes as seconds (Double) from MediaRemote.
            let duration = info[MediaRemoteBridge.kDuration]    as? Double ?? 0
            let elapsed  = info[MediaRemoteBridge.kElapsedTime] as? Double ?? 0
            let rate     = info[MediaRemoteBridge.kPlaybackRate] as? Double ?? 0

            // Artwork arrives as raw image bytes with a MIME type hint.
            var artwork: NSImage? = nil
            if let data = info[MediaRemoteBridge.kArtworkData] as? Data {
                artwork = NSImage(data: data)
            }

            // isPlaying comes from a separate async call — chain it.
            self?.bridge.fetchIsPlaying { playing in
                self?.nowPlaying = NowPlayingInfo(
                    title:        title,
                    artist:       artist,
                    album:        album,
                    isPlaying:    playing,
                    duration:     duration,
                    elapsed:      elapsed,
                    playbackRate: rate,
                    artwork:      artwork
                )
            }
        }
    }
}

// MARK: - Widget

struct LiquidGlassNowPlayingWidget: View {
    var hasBackgroundPhoto: Bool

    @AppStorage("accentColorRed")   private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue")  private var b: Double = 0.72

    @ObservedObject private var monitor = SystemNowPlayingMonitor.shared
    @State private var displayElapsed: TimeInterval = 0

    private var accentColor: Color { Color(red: r, green: g, blue: b) }

    private var info: NowPlayingInfo? { monitor.nowPlaying }

    private var isPlaying: Bool  { info?.isPlaying ?? false }
    private var duration: Double { info?.duration ?? 0 }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(displayElapsed / duration, 0), 1)
    }

    var body: some View {
        VStack(spacing: 12) {
            artworkView

            VStack(spacing: 2) {
                Text(info?.title ?? "Nothing Playing")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(hasBackgroundPhoto ? 0.35 : 0), radius: 6, x: 0, y: 1)

                Text(info?.artist ?? "Play something to see it here")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.75))
                    .lineLimit(1)
                    .shadow(color: .black.opacity(hasBackgroundPhoto ? 0.3 : 0), radius: 6, x: 0, y: 1)
            }
            .frame(maxWidth: .infinity)

            Capsule()
                .fill(Color.primary.opacity(0.12))
                .frame(width: artworkSize, height: 3)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(accentColor)
                        .frame(width: max(0, artworkSize * progress), height: 3)
                }
                .opacity(duration > 0 ? 1 : 0)

            HStack(spacing: 26) {
                transportButton(systemName: "backward.fill") {
                    monitor.previousTrack()
                }
                transportButton(systemName: isPlaying ? "pause.fill" : "play.fill", prominent: true) {
                    monitor.togglePlayPause()
                }
                transportButton(systemName: "forward.fill") {
                    monitor.nextTrack()
                }
            }
            .disabled(info == nil)
            .opacity(info == nil ? 0.35 : 1)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(width: LiquidGlassClockPanel.widgetWidth, alignment: .center)
        .background {
            ZStack {
                if hasBackgroundPhoto {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.black.opacity(0.14))
                }
                Color.clear
                    .glassEffect(
                        .regular.tint(accentColor.opacity(hasBackgroundPhoto ? 0.08 : 0.05)),
                        in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                    )
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 8)
        .animation(.shromeSnappy, value: info?.title)
        .onAppear {
            SystemNowPlayingMonitor.shared.ensureListening()
            displayElapsed = info?.elapsed ?? 0
        }
        .onChange(of: info?.title) { _, _ in
            displayElapsed = info?.elapsed ?? 0
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard isPlaying else { return }
            displayElapsed = (info?.elapsed ?? displayElapsed)
        }
    }

    private var artworkSize: CGFloat { LiquidGlassClockPanel.widgetWidth - 44 }

    @ViewBuilder
    private var artworkView: some View {
        if let artwork = info?.artwork {
            Image(nsImage: artwork)
                .resizable()
                .scaledToFill()
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accentColor.opacity(0.15))
                .frame(width: artworkSize, height: artworkSize)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(accentColor.opacity(0.6))
                }
        }
    }

    private func transportButton(systemName: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: prominent ? 17 : 14, weight: .bold))
                .foregroundColor(prominent ? .white : .primary.opacity(0.7))
                .frame(width: prominent ? 42 : 28, height: prominent ? 42 : 28)
                .background {
                    if prominent { Circle().fill(accentColor) }
                }
        }
        .buttonStyle(.bouncy)
    }
}

//
//  LiquidGlassNowPlayingWidget.swift
//  Shrome
//
//  A small glass card mirroring the Music widget in macOS Control Center —
//  album art, title/artist, and transport controls for whatever's playing
//  system-wide (Music, Spotify, a YouTube tab, anything).
//

import SwiftUI
import Combine
import MediaRemoteAdapter

// MARK: - Shared System Now-Playing State

/// Singleton wrapping MediaRemoteAdapter's MediaController, so every
/// window's widget reflects the same system-wide playback state from a
/// single background listener rather than each one spawning its own.
class SystemNowPlayingMonitor: ObservableObject {
    static let shared = SystemNowPlayingMonitor()

    @Published private(set) var trackInfo: TrackInfo? = nil

    private let mediaController = MediaController()
    private var hasStartedListening = false

    private init() {
        mediaController.onTrackInfoReceived = { [weak self] info in
            DispatchQueue.main.async {
                self?.trackInfo = info
            }
        }
        mediaController.onListenerTerminated = { [weak self] in
            DispatchQueue.main.async {
                self?.trackInfo = nil
            }
        }
    }

    func ensureListening() {
        guard !hasStartedListening else { return }
        hasStartedListening = true
        mediaController.startListening()
    }

    func togglePlayPause() { mediaController.togglePlayPause() }
    func nextTrack()       { mediaController.nextTrack() }
    func previousTrack()   { mediaController.previousTrack() }
}

// MARK: - Widget

struct LiquidGlassNowPlayingWidget: View {
    /// Same readability-boost contract as LiquidGlassClockPanel.
    var hasBackgroundPhoto: Bool

    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72

    @ObservedObject private var monitor = SystemNowPlayingMonitor.shared

    @State private var displayElapsed: TimeInterval = 0

    // Refined Theme-Blended Profile
    private var accentColor: Color { Color(red: r, green: g, blue: b) }

    private var payload: TrackInfo.Payload? { monitor.trackInfo?.payload }

    private var isPlaying: Bool {
        payload?.isPlaying ?? ((payload?.playbackRate ?? 0) > 0)
    }

    private var durationSeconds: Double {
        (payload?.durationMicros ?? 0) / 1_000_000
    }

    private var progress: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(max(displayElapsed / durationSeconds, 0), 1)
    }

    var body: some View {
        VStack(spacing: 12) {
            artworkView

            VStack(spacing: 2) {
                Text(payload?.title ?? "Nothing Playing")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(hasBackgroundPhoto ? 0.35 : 0), radius: 6, x: 0, y: 1)

                Text(payload?.artist ?? "Play something to see it here")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.75))
                    .lineLimit(1)
                    .shadow(color: .black.opacity(hasBackgroundPhoto ? 0.3 : 0), radius: 6, x: 0, y: 1)
            }
            .frame(maxWidth: .infinity)

            // --- REFINED EXTENSION: UN-NEON GRADIENT TRACK BUFFER ---
            Capsule()
                .fill(Color.primary.opacity(0.08))
                .frame(width: artworkSize, height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.6),
                                    accentColor.opacity(0.85)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, artworkSize * progress), height: 4)
                }
                .opacity(durationSeconds > 0 ? 1 : 0)

            HStack(spacing: 26) {
                transportButton(systemName: "backward.fill") {
                    monitor.previousTrack()
                }
                // Central prominent control
                transportButton(systemName: isPlaying ? "pause.fill" : "play.fill", prominent: true) {
                    monitor.togglePlayPause()
                }
                transportButton(systemName: "forward.fill") {
                    monitor.nextTrack()
                }
            }
            .disabled(payload == nil)
            .opacity(payload == nil ? 0.35 : 1)
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
        .animation(.shromeSnappy, value: payload?.title)
        .onAppear {
            SystemNowPlayingMonitor.shared.ensureListening()
            displayElapsed = payload?.currentElapsedTime ?? 0
        }
        .onChange(of: payload?.title) { _, _ in
            displayElapsed = payload?.currentElapsedTime ?? 0
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard isPlaying else { return }
            displayElapsed = payload?.currentElapsedTime ?? displayElapsed
        }
    }

    private var artworkSize: CGFloat {
        LiquidGlassClockPanel.widgetWidth - 44
    }

    @ViewBuilder
    private var artworkView: some View {
        if let artwork = payload?.artwork {
            Image(nsImage: artwork)
                .resizable()
                .scaledToFill()
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accentColor.opacity(0.12))
                .frame(width: artworkSize, height: artworkSize)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(accentColor.opacity(0.45))
                }
        }
    }

    // --- REFINED EXTENSION: GLASS-BLENDED TRANSPORT CONTROLS ---
    private func transportButton(systemName: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: prominent ? 15 : 13, weight: .bold))
                .foregroundColor(prominent ? .primary : .primary.opacity(0.45))
                .frame(width: prominent ? 44 : 28, height: prominent ? 44 : 28)
                .background {
                    if prominent {
                        Circle()
                            .fill(.thinMaterial)
                            .overlay {
                                Circle()
                                    .fill(accentColor.opacity(0.18))
                            }
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.4),
                                                accentColor.opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                    }
                }
        }
        .buttonStyle(.bouncy)
    }
}

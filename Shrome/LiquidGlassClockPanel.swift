//
//  LiquidGlassClockPanel.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI
import Combine

struct LiquidGlassClockPanel: View {
    static let widgetWidth: CGFloat = 220
    var hasBackgroundPhoto: Bool

    @AppStorage("accentColorRed") private var r: Double = 0.96
    @AppStorage("accentColorGreen") private var g: Double = 0.55
    @AppStorage("accentColorBlue") private var b: Double = 0.72
    @State private var displayTime: String = ""
    @State private var displayDate: String = ""

    private var accentColor: Color { Color(red: r, green: g, blue: b) }

    private func timeString(from date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func dateString(from date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(displayTime)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .monospacedDigit()
                // The signature "fade" digit transition — only the digit(s)
                // that actually changed animate, everything else holds still.
                .contentTransition(.numericText())
                .shadow(color: .black.opacity(hasBackgroundPhoto ? 0.35 : 0), radius: 8, x: 0, y: 2)

            Text(displayDate)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.secondary.opacity(0.75))
                .contentTransition(.opacity)
                .shadow(color: .black.opacity(hasBackgroundPhoto ? 0.3 : 0), radius: 6, x: 0, y: 1)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .frame(width: Self.widgetWidth, alignment: .leading)
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
        .onAppear {
            let now = Date()
            displayTime = timeString(from: now)
            displayDate = dateString(from: now)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
            let newTime = timeString(from: now)
            if newTime != displayTime {
                withAnimation(.easeInOut(duration: 0.5)) {
                    displayTime = newTime
                }
            }
            let newDate = dateString(from: now)
            if newDate != displayDate {
                withAnimation(.easeInOut(duration: 0.4)) {
                    displayDate = newDate
                }
            }
        }
    }
}

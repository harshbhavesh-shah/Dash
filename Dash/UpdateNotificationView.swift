//
//  UpdateNotificationView.swift
//  Dash
//
//  Created by Harsh Shah on 12/07/2026.
//


import SwiftUI

struct UpdateNotificationView: View {
    let updateInfo: UpdateInfo
    var onViewRelease: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onViewRelease) {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dash \(updateInfo.version) is available")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Click to see what's new")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 10)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 300)
        .glassEffect(in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
    }
}

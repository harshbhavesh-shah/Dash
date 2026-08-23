//
//  DownloadShelfView.swift
//  Dash
//
//  Created by Harsh Shah on 11/07/2026.
//


import SwiftUI

struct DownloadShelfView: View {
    @ObservedObject private var downloadManager = DownloadManager.shared
    var onOpenDownloads: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Downloads")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    withAnimation(.dashSnappy) {
                        downloadManager.dismissShelf()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Button(action: onOpenDownloads) {
                VStack(spacing: 10) {
                    ForEach(downloadManager.shelfItems) { item in
                        ShelfRow(item: item)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 260)
        .glassEffect(in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
    }
}

private struct ShelfRow: View {
    let item: ShelfDownloadInfo

    @State private var hasDropped = false
    @State private var showProgress = false

    private var statusLabel: String {
        switch item.status {
        case "completed": return "Done"
        case "failed": return "Failed"
        default: return ""
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.status == "completed" ? "checkmark.circle.fill" : "doc.fill")
                .font(.system(size: 16))
                .foregroundColor(item.status == "failed" ? .red.opacity(0.8) : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.filename)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                if showProgress {
                    if item.status == "downloading" {
                        ProgressView(value: item.fractionCompleted)
                            .frame(height: 3)
                    } else {
                        Text(statusLabel)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .transition(.opacity)
                    }
                }
            }
        }
        .offset(y: hasDropped ? 0 : -24)
        .opacity(hasDropped ? 1 : 0)
        .onAppear {
            withAnimation(.dashBouncy) {
                hasDropped = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showProgress = true
                }
            }
        }
    }
}

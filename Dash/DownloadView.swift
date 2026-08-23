//
//  DownloadView.swift
//  Dash
//
//  Created by Harsh Shah on 11/07/2026.
//

import SwiftUI
import AppKit

struct DownloadsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var downloadManager = DownloadManager.shared
    var onClose: () -> Void

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DownloadItem.timestamp, ascending: false)],
        animation: .default
    ) private var downloadItems: FetchedResults<DownloadItem>

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Downloads", systemImage: "arrow.down.circle")
                    .font(.system(size: 16, weight: .bold, design: .rounded))

                Spacer()

                Button(action: clearAll) {
                    Text("Clear All")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .padding(.trailing, 10)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider().opacity(0.1)

            if downloadItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No downloads yet.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(downloadItems) { item in
                        DownloadRow(
                            item: item,
                            liveProgress: item.id.flatMap { downloadManager.activeProgress[$0] }
                        ) {
                            deleteItem(item)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(width: 450, height: 550)
        .glassEffect(in: RoundedRectangle(cornerRadius: 24))
    }

    private func deleteItem(_ item: DownloadItem) {
        viewContext.delete(item)
        try? viewContext.save()
    }

    private func clearAll() {
        for item in downloadItems {
            viewContext.delete(item)
        }
        try? viewContext.save()
    }
}

struct DownloadRow: View {
    let item: DownloadItem
    let liveProgress: DownloadProgressInfo?
    var onDelete: () -> Void

    @State private var isHovered = false

    private var statusText: String {
        switch item.status {
        case "downloading": return "Downloading…"
        case "failed": return "Failed"
        case "cancelled": return "Cancelled"
        default: return formattedSize(item.totalBytes)
        }
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.filename ?? "Unknown file")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if item.status == "downloading", let liveProgress {
                    ProgressView(value: liveProgress.fractionCompleted)
                        .frame(width: 200)
                } else {
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if item.status == "completed" {
                Button(action: reveal) {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            withAnimation(.easeIn(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            if item.status == "completed" { open() }
        }
    }

    private func reveal() {
        guard let path = item.localPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private func open() {
        guard let path = item.localPath else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
}

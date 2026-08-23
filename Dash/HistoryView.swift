//
//  HistoryView.swift
//  Dash
//
//  Created by Harsh Shah on 18/06/2026.
//
import SwiftUI

struct HistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var tabManager: TabManager
    var onClose: () -> Void
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HistoryItem.timestamp, ascending: false)],
        animation: .default
    ) private var historyItems: FetchedResults<HistoryItem>
    
    @State private var searchText = ""

    var filteredItems: [HistoryItem] {
        if searchText.isEmpty {
            return Array(historyItems)
        } else {
            return historyItems.filter {
                ($0.title ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.url ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // HEADER BAR
            HStack {
                Label("Browsing History", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                
                Spacer()
                
                Button(action: clearAllHistory) {
                    Text("Clear All Data")
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
            
            // FILTER PIPELINE SEARCH BAR
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search history logs...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            Divider().opacity(0.1)
            
            // HISTORY LOG TABLE
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No cosmic records found.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredItems) { item in
                        HistoryRow(item: item) {
                            if let urlString = item.url {
                                tabManager.updateActiveUrl(urlString: urlString)
                                onClose()
                            }
                        } onDelete: {
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
    
    private func deleteItem(_ item: HistoryItem) {
        viewContext.delete(item)
        try? viewContext.save()
    }
    
    private func clearAllHistory() {
        for item in historyItems {
            viewContext.delete(item)
        }
        try? viewContext.save()

        // BUG FIX: see GravityPreferencesView.clearAllDataNow() — other
        // contexts (e.g. TabManager's background context) cache HistoryItem
        // objects and need to drop them after a wipe, or a new row can
        // collide with a stale cached object reusing the same SQLite row ID.
        NotificationCenter.default.post(name: .dashDidClearAllHistory, object: nil)
    }
}

struct HistoryRow: View {
    let item: HistoryItem
    var onSelect: () -> Void
    var onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(URL(string: item.url ?? "")?.host ?? "")")) { phase in
                if let image = phase.image {
                    image.resizable()
                } else {
                    Image(systemName: "globe")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 16, height: 16)
            .cornerRadius(4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title ?? "Unknown Title")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(item.url ?? "")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let timestamp = item.timestamp {
                Text(timestamp, style: .time)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
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
        .onTapGesture(perform: onSelect)
    }
}

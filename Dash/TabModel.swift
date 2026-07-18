//
//  TabModel.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI
import Foundation
import Combine
import CoreData

struct TabGroup: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var icon: String
    var colorName: String
}

struct Tab: Identifiable, Hashable, Codable {
    var id: UUID
    var url: URL
    var urlString: String
    var title: String
    var isPrivate: Bool
    var groupId: UUID? = nil
    var reloadTrigger: UUID = UUID()

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: Tab, rhs: Tab) -> Bool {
        lhs.id == rhs.id &&
        lhs.url == rhs.url &&
        lhs.urlString == rhs.urlString &&
        lhs.title == rhs.title &&
        lhs.isPrivate == rhs.isPrivate &&
        lhs.groupId == rhs.groupId &&
        lhs.reloadTrigger == rhs.reloadTrigger
    }
}

class TabManager: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var activeTabId: UUID = UUID()

    @Published var groups: [TabGroup] = [
        TabGroup(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "Work", icon: "briefcase.fill", colorName: "Sage"),
        TabGroup(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, name: "Personal", icon: "person.fill", colorName: "Rose"),
        TabGroup(id: UUID(uuidString: "33222222-2222-2222-2222-222222222222")!, name: "Gaming", icon: "gamecontroller.fill", colorName: "Peach")
    ]

    private lazy var backgroundContext: NSManagedObjectContext = {
        let ctx = PersistenceController.shared.container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }()
    private var saveDebounceTask: Task<Void, Never>?
    private var clearHistoryObserver: NSObjectProtocol?

    init() {
        loadSessionOrCreateDefault()

        // See GravityPreferencesView.clearAllDataNow(): after a full wipe,
        // this context needs to drop any cached HistoryItem objects it
        // still holds so it doesn't collide with new rows that reuse the
        // same underlying SQLite row IDs.
        clearHistoryObserver = NotificationCenter.default.addObserver(
            forName: .shromeDidClearAllHistory, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.backgroundContext.perform {
                self.backgroundContext.reset()
            }
        }
    }

    deinit {
        if let clearHistoryObserver { NotificationCenter.default.removeObserver(clearHistoryObserver) }
    }

    // MARK: - Startup / Session Restore
    //
    // BUG FIX: `_commitSessionToDisk()` was faithfully writing `savedTabs` /
    // `activeTabId` to UserDefaults on every change, but nothing ever read
    // them back — init() unconditionally called createNewTab(), so
    // "Continue where I left off" (the default StartupBehavior) silently
    // did nothing and every launch started on a blank tab. This wires up
    // all three StartupBehavior cases from GravityPreferencesView.

    private func loadSessionOrCreateDefault() {
        let defaults = UserDefaults.standard
        let behavior = StartupBehavior(rawValue: defaults.string(forKey: "startupBehavior") ?? "")
            ?? .leftOff

        switch behavior {
        case .newTab:
            let homepage = defaults.string(forKey: "homepage") ?? ""
            createNewTab(urlString: homepage.isEmpty ? "about:blank" : homepage)

        case .firstGroupTab:
            if restoreSavedTabs(), let firstGroup = groups.first,
               let tab = tabs.first(where: { $0.groupId == firstGroup.id }) {
                activeTabId = tab.id
            } else if let firstGroup = groups.first {
                createNewTab(targetGroupId: firstGroup.id)
            } else {
                createNewTab()
            }

        case .leftOff:
            if !restoreSavedTabs() {
                createNewTab()
            }
        }
    }

    /// Attempts to restore tabs saved by `_commitSessionToDisk()`.
    /// Returns false (and leaves `tabs` untouched) if there was nothing
    /// valid to restore, so callers can fall back to a fresh tab.
    @discardableResult
    private func restoreSavedTabs() -> Bool {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "savedTabs"),
              let decoded = try? JSONDecoder().decode([Tab].self, from: data),
              !decoded.isEmpty
        else { return false }

        tabs = decoded

        if let activeData = defaults.data(forKey: "activeTabId"),
           let decodedActiveId = try? JSONDecoder().decode(UUID.self, from: activeData),
           decoded.contains(where: { $0.id == decodedActiveId }) {
            activeTabId = decodedActiveId
        } else {
            activeTabId = decoded[0].id
        }
        return true
    }

    var activeTab: Tab {
        if let index = tabs.firstIndex(where: { $0.id == activeTabId }) {
            return tabs[index]
        }
        return Tab(
            id: UUID(),
            url: URL(string: "about:blank")!,
            urlString: "about:blank",
            title: "New Tab",
            isPrivate: false
        )
    }

    // MARK: - Tab Lifecycle

    func createNewTab(urlString: String = "about:blank", isPrivate: Bool = false, targetGroupId: UUID? = nil) {
        let newTab = Tab(
            id: UUID(),
            url: URL(string: urlString) ?? URL(string: "about:blank")!,
            urlString: urlString,
            title: urlString == "about:blank" ? "New Tab" : urlString,
            isPrivate: isPrivate,
            groupId: targetGroupId
        )
        tabs.append(newTab)
        activeTabId = newTab.id

        if !isPrivate { saveSession() }
    }

    func closeTab(id: UUID) {
        guard tabs.count > 1 else { return }
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let wasActive = (activeTabId == id)
        let closedTab = tabs[index]
        tabs.remove(at: index)

        if wasActive {
            activeTabId = tabs[min(index, tabs.count - 1)].id
        }
        WebViewPool.shared.releaseWebView(for: id)

        if !closedTab.isPrivate { saveSession() }
    }

    func reloadActiveTab() {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabId }) else { return }
        tabs[index].reloadTrigger = UUID()
    }

    // MARK: - Tab Cycling (⌃Tab / ⌃⇧Tab / ⌘1-9)

    func selectNextTab() {
        guard !tabs.isEmpty else { return }
        guard let index = tabs.firstIndex(where: { $0.id == activeTabId }) else {
            activeTabId = tabs[0].id
            return
        }
        activeTabId = tabs[(index + 1) % tabs.count].id
    }

    func selectPreviousTab() {
        guard !tabs.isEmpty else { return }
        guard let index = tabs.firstIndex(where: { $0.id == activeTabId }) else {
            activeTabId = tabs[0].id
            return
        }
        activeTabId = tabs[(index - 1 + tabs.count) % tabs.count].id
    }
    func selectTab(number: Int) {
        let index = number - 1
        guard tabs.indices.contains(index) else { return }
        activeTabId = tabs[index].id
    }
    func selectLastTab() {
        guard let last = tabs.last else { return }
        activeTabId = last.id
    }

    // MARK: - Groups

    func moveActiveTab(to groupId: UUID?) {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabId }) else { return }
        tabs[index].groupId = groupId
        if !tabs[index].isPrivate { saveSession() }
    }

    func createCustomGroup(name: String, icon: String, colorName: String) {
        groups.append(TabGroup(id: UUID(), name: name, icon: icon, colorName: colorName))
    }

    // MARK: - URL Routing

    func updateActiveUrl(urlString: String, searchEngine: String = "Google") {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabId }) else { return }

        var formattedString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        if !formattedString.contains("://") && !formattedString.hasPrefix("about:") {
            if formattedString.contains(".") && !formattedString.contains(" ") {
                formattedString = "https://" + formattedString
            } else {
                let query = formattedString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                switch searchEngine {
                case "DuckDuckGo":  formattedString = "https://duckduckgo.com/?q=" + query
                case "Bing":        formattedString = "https://www.bing.com/search?q=" + query
                case "Brave Search":formattedString = "https://search.brave.com/search?q=" + query
                case "Ecosia":      formattedString = "https://www.ecosia.org/search?q=" + query
                default:            formattedString = "https://www.google.com/search?q=" + query
                }
            }
        }

        guard let url = URL(string: formattedString) else { return }

        let previousUrl = tabs[index].url

        tabs[index].url = url
        tabs[index].urlString = formattedString
        tabs[index].title = url.host ?? formattedString

        if !tabs[index].isPrivate {
            saveSession()
            // BUG FIX: this used to log a history entry on every call,
            // including redundant resubmissions of the same URL (e.g. the
            // address bar's "reload" button re-running this whole method).
            // Only log when the URL actually changed.
            if historyLoggingEnabled && previousUrl != url {
                logVisitToCoreData(url: url, title: tabs[index].title)
            }
        }
    }

    // MARK: - Autocomplete

    struct URLSuggestion: Identifiable, Equatable {
        let id = UUID()
        let url: String
        let title: String
        let visitedAt: Date
    }
    func fetchSuggestions(matching query: String) async -> [URLSuggestion] {
        guard !query.isEmpty else { return [] }

        let ctx = backgroundContext
        return await ctx.perform {
            let request = NSFetchRequest<HistoryItem>(entityName: "HistoryItem")

            request.predicate = NSPredicate(
                format: "url CONTAINS[cd] %@ OR title CONTAINS[cd] %@",
                query, query
            )
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            request.fetchLimit = 40

            guard let results = try? ctx.fetch(request) else { return [] }

            var seen = Set<String>()
            var suggestions: [URLSuggestion] = []

            for item in results {
                guard let url = item.url, !url.isEmpty else { continue }
                let key: String
                if let parsed = URL(string: url), let host = parsed.host {
                    key = host + parsed.path
                } else {
                    key = url
                }
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                suggestions.append(URLSuggestion(
                    url: url,
                    title: item.title ?? url,
                    visitedAt: item.timestamp ?? .distantPast
                ))
                if suggestions.count == 6 { break }
            }
            return suggestions
        }
    }

    // MARK: - Persistence

    func saveSession() {
        saveDebounceTask?.cancel()
        saveDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled, let self else { return }
            await MainActor.run { self._commitSessionToDisk() }
        }
    }

    private func _commitSessionToDisk() {
        let clearOnQuit = UserDefaults.standard.bool(forKey: "clearOnQuit")
        if clearOnQuit {
            UserDefaults.standard.removeObject(forKey: "savedTabs")
            UserDefaults.standard.removeObject(forKey: "activeTabId")
            return
        }

        let normalTabs = tabs.filter { !$0.isPrivate }
        if let encoded = try? JSONEncoder().encode(normalTabs) {
            UserDefaults.standard.set(encoded, forKey: "savedTabs")
        }
        if let activeEncoded = try? JSONEncoder().encode(activeTabId) {
            UserDefaults.standard.set(activeEncoded, forKey: "activeTabId")
        }
    }
    private var historyLoggingEnabled: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "saveHistory") == nil { return true }
        return defaults.bool(forKey: "saveHistory")
    }

    private func logVisitToCoreData(url: URL, title: String) {
        let ctx = backgroundContext
        ctx.perform {
            let historyItem = HistoryItem(context: ctx)
            // BUG FIX: this is the actual root cause of every history row
            // rendering as identical content. HistoryItem has its own
            // explicit `id: UUID?` attribute (separate from Core Data's
            // internal object identity), and it's what Xcode's generated
            // class uses to satisfy `Identifiable` for `@FetchRequest` /
            // `ForEach` in HistoryView. This was never being set, so every
            // row had `id == nil` — SwiftUI saw every row as sharing the
            // exact same identity and rendered the same content for all of
            // them, even though each one really was a distinct, correctly
            // inserted row in the database.
            historyItem.id = UUID()
            historyItem.timestamp = Date()
            historyItem.url = url.absoluteString
            historyItem.title = title

            do {
                try ctx.save()
            } catch {
                print("History log failed: \(error)")
            }
        }
    }
}

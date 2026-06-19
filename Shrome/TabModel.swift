//
//  TabModel.swift
//  Shrome
//

import SwiftUI
import Foundation
import Combine
import CoreData

// --- THE TAB GROUP MODEL STRUCTURE ---
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

    // PERF FIX: Full value equality so SwiftUI can diff individual tabs
    // and skip re-rendering rows where nothing actually changed.
    // Previously this only compared IDs, meaning SwiftUI could never tell
    // two different states of the same tab apart.
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

    // PERF FIX: Dedicated background context for all Core Data writes.
    // Previously all history writes happened on viewContext (main thread),
    // blocking the UI during navigations, especially rapid redirect chains.
    private lazy var backgroundContext: NSManagedObjectContext = {
        let ctx = PersistenceController.shared.container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }()

    // PERF FIX: Task handle for debouncing saveSession.
    // Previously saveSession() fired synchronously on every mutation
    // (tab creation, URL update, group move, close) encoding JSON and
    // writing UserDefaults on the main thread — causing frame drops.
    private var saveDebounceTask: Task<Void, Never>?

    init() {
        createNewTab()
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

        if !closedTab.isPrivate { saveSession() }
    }

    func reloadActiveTab() {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabId }) else { return }
        tabs[index].reloadTrigger = UUID()
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

        tabs[index].url = url
        tabs[index].urlString = formattedString
        tabs[index].title = url.host ?? formattedString

        if !tabs[index].isPrivate {
            saveSession()
            logVisitToCoreData(url: url, title: tabs[index].title)
        }
    }

    // MARK: - Persistence

    // PERF FIX: Debounced 500ms — collapses rapid-fire mutations (e.g. a
    // tab group drag that moves 3 tabs) into a single encode + UserDefaults write.
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

    // PERF FIX: All Core Data writes now happen on a dedicated background
    // context, completely off the main thread. The persistent store
    // coordinator handles merging back to viewContext automatically
    // (automaticallyMergesChangesFromParent is set in Persistence.swift).
    private func logVisitToCoreData(url: URL, title: String) {
        let ctx = backgroundContext
        ctx.perform {
            let historyItem = HistoryItem(context: ctx)
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

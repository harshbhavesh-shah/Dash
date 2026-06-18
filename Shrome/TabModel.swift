//
//  TabModel.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI
import Combine
import CoreData

extension Notification.Name {
    static let saveBrowserSession = Notification.Name("saveBrowserSession")
}

struct TabGroup: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var isExpanded: Bool = true
}

struct Tab: Identifiable, Equatable, Codable {
    var id = UUID()
    var urlString: String
    var url: URL
    var reloadTrigger: UUID = UUID()
    var groupId: UUID? = nil
    var isPrivate: Bool = false
}

class TabManager: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var groups: [TabGroup] = []
    @Published var activeTabId: UUID = UUID()
    
    var activeTab: Tab {
        tabs.first(where: { $0.id == activeTabId }) ?? tabs[0]
    }
    
    init() {
        if !loadSession() {
            let firstTab = Tab(urlString: "", url: URL(string: "about:blank")!)
            self.tabs = [firstTab]
            self.activeTabId = firstTab.id
        }
        NotificationCenter.default.addObserver(self, selector: #selector(saveSession), name: .saveBrowserSession, object: nil)
    }
    
    @objc func saveSession() {
        let clearOnQuit = UserDefaults.standard.bool(forKey: "clearOnQuit")
        if clearOnQuit {
            UserDefaults.standard.removeObject(forKey: "savedTabs")
            UserDefaults.standard.removeObject(forKey: "savedGroups")
            UserDefaults.standard.removeObject(forKey: "activeTabId")
            return
        }
        
        let tabsToSave = tabs.filter { !$0.isPrivate }
        
        if let tabsData = try? JSONEncoder().encode(tabsToSave) {
            UserDefaults.standard.set(tabsData, forKey: "savedTabs")
        }
        if let groupsData = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(groupsData, forKey: "savedGroups")
        }
        UserDefaults.standard.set(activeTabId.uuidString, forKey: "activeTabId")
    }
    
    private func loadSession() -> Bool {
        let behaviorString = UserDefaults.standard.string(forKey: "startupBehavior") ?? "Continue where I left off"
        
        if behaviorString == "Start at the new tab page" {
            return false
        }
        
        guard let tabsData = UserDefaults.standard.data(forKey: "savedTabs"),
              let decodedTabs = try? JSONDecoder().decode([Tab].self, from: tabsData),
              !decodedTabs.isEmpty else {
            return false
        }
        
        self.tabs = decodedTabs
        
        if let groupsData = UserDefaults.standard.data(forKey: "savedGroups"),
           let decodedGroups = try? JSONDecoder().decode([TabGroup].self, from: groupsData) {
            self.groups = decodedGroups
        }
        
        if behaviorString == "First tab of a tab group" {
            if let firstGroupedTab = decodedTabs.first(where: { $0.groupId != nil }) {
                self.activeTabId = firstGroupedTab.id
            } else {
                self.activeTabId = decodedTabs.first!.id
            }
        } else {
            if let activeIdString = UserDefaults.standard.string(forKey: "activeTabId"),
               let activeId = UUID(uuidString: activeIdString),
               decodedTabs.contains(where: { $0.id == activeId }) {
                self.activeTabId = activeId
            } else {
                self.activeTabId = decodedTabs.first!.id
            }
        }
        
        return true
    }
    
    func createNewTab(in groupId: UUID? = nil, isPrivate: Bool = false) {
        let newTab = Tab(urlString: "", url: URL(string: "about:blank")!, groupId: groupId, isPrivate: isPrivate)
        tabs.append(newTab)
        activeTabId = newTab.id
        
        if let groupId = groupId, let index = groups.firstIndex(where: { $0.id == groupId }) {
            groups[index].isExpanded = true
        }
    }
    
    func createNewTabGroup() {
        let newGroup = TabGroup(name: "New Group")
        groups.append(newGroup)
        createNewTab(in: newGroup.id)
    }

    func moveTab(_ tabId: UUID, to groupId: UUID?) {
        guard let index = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        if tabs[index].groupId == groupId { return }
        
        tabs[index].groupId = groupId
        if let gId = groupId, let gIndex = groups.firstIndex(where: { $0.id == gId }) {
            groups[gIndex].isExpanded = true
        }
        cleanupEmptyGroups()
    }
    
    private func cleanupEmptyGroups() {
        groups.removeAll { group in
            !tabs.contains(where: { $0.groupId == group.id })
        }
    }

    func reloadActiveTab() {
        if let index = tabs.firstIndex(where: { $0.id == activeTabId }) {
            tabs[index].reloadTrigger = UUID()
        }
    }

    func updateActiveUrl(urlString: String) {
        let cleanedInput = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = tabs.firstIndex(where: { $0.id == activeTabId }) else { return }

        if cleanedInput.isEmpty || cleanedInput == "about:blank" {
            tabs[index].url = URL(string: "about:blank")!
            tabs[index].urlString = ""
            return
        }

        let formatted = formatUrl(cleanedInput)
        if let newUrl = URL(string: formatted) {
            tabs[index].url = newUrl
            tabs[index].urlString = formatted
            
            // Log history on a verified background thread
            recordHistoryItem(title: newUrl.host ?? cleanedInput, urlString: formatted)
        }
    }
    
    private func recordHistoryItem(title: String, urlString: String) {
        // --- FIXED: Read as optional object casting to guarantee a 'true' fallback baseline ---
        let saveHistory = UserDefaults.standard.object(forKey: "saveHistory") as? Bool ?? true
        
        guard saveHistory && !activeTab.isPrivate else { return }
        
        let context = PersistenceController.shared.container.viewContext
        context.perform {
            let newItem = HistoryItem(context: context)
            newItem.id = UUID()
            newItem.title = title
            newItem.url = urlString
            newItem.timestamp = Date()
            
            do {
                try context.save()
                print("Cosmic data warehouse updated: \(title)")
            } catch {
                print("Core Data logging exception: \(error)")
            }
        }
    }
    
    private func formatUrl(_ input: String) -> String {
        if input.contains(".") && !input.contains(" ") {
            return input.lowercased().hasPrefix("http") ? input : "https://\(input)"
        }
        let query = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "https://www.google.com/search?q=\(query)"
    }
    
    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        
        if tabs.count > 1 {
            if activeTabId == id {
                let nextIndex = (index > 0) ? index - 1 : index + 1
                activeTabId = tabs[nextIndex].id
            }
            tabs.remove(at: index)
        } else {
            tabs[0].url = URL(string: "about:blank")!
            tabs[0].urlString = ""
            tabs[0].groupId = nil
            tabs[0].isPrivate = false
        }
        
        cleanupEmptyGroups()
    }
    
    func closeGroup(id: UUID) {
        let tabsToClose = tabs.filter { $0.groupId == id }
        for tab in tabsToClose {
            closeTab(id: tab.id)
        }
    }
}

private struct IsPrivateWindowKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isPrivateWindow: Bool {
        get { self[IsPrivateWindowKey.self] }
        set { self[IsPrivateWindowKey.self] = newValue }
    }
}

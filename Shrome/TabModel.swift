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
    var icon: String // e.g., "briefcase.fill", "gamecontroller.fill"
    var colorName: String // To match custom theme accents
}

struct Tab: Identifiable, Hashable, Codable {
    var id: UUID
    var url: URL
    var urlString: String
    var title: String
    var isPrivate: Bool
    var groupId: UUID? = nil // Group attribution tracking
    var reloadTrigger: UUID = UUID()
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Tab, rhs: Tab) -> Bool {
        lhs.id == rhs.id
    }
}

class TabManager: ObservableObject {
    @Published var tabs: [Tab] = []
    @Published var activeTabId: UUID = UUID()
    
    // --- REAL-TIME GROUPS DECK ---
    @Published var groups: [TabGroup] = [
        TabGroup(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "Work", icon: "briefcase.fill", colorName: "Sage"),
        TabGroup(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, name: "Personal", icon: "person.fill", colorName: "Rose"),
        TabGroup(id: UUID(uuidString: "33222222-2222-2222-2222-222222222222")!, name: "Gaming", icon: "gamecontroller.fill", colorName: "Peach")
    ]
    
    init() {
        createNewTab()
    }
    
    var activeTab: Tab {
        if let index = tabs.firstIndex(where: { $0.id == activeTabId }) {
            return tabs[index]
        }
        let fallbackTab = Tab(id: UUID(), url: URL(string: "about:blank")!, urlString: "about:blank", title: "New Tab", isPrivate: false)
        return fallbackTab
    }
    
    // --- CREATION WITH GROUP ROUTING ---
    func createNewTab(urlString: String = "about:blank", isPrivate: Bool = false, targetGroupId: UUID? = nil) {
        let newTab = Tab(
            id: UUID(),
            url: URL(string: urlString) ?? URL(string: "about:blank")!,
            urlString: urlString,
            title: urlString == "about:blank" ? "New Tab" : urlString,
            isPrivate: isPrivate,
            groupId: targetGroupId
        )
        
        self.tabs.append(newTab)
        self.activeTabId = newTab.id
        
        if !isPrivate {
            saveSession()
        }
    }
    
    // --- ASSIGN ACTIVE TAB TO A GROUP ---
    func moveActiveTab(to groupId: UUID?) {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabId }) else { return }
        tabs[index].groupId = groupId
        if !tabs[index].isPrivate { saveSession() }
    }
    
    // --- DYNAMIC CUSTOM THEMED GROUP INJECTION ---
    func createCustomGroup(name: String, icon: String, colorName: String) {
        let newGroup = TabGroup(id: UUID(), name: name, icon: icon, colorName: colorName)
        self.groups.append(newGroup)
    }
    
    // --- MULTI-ENGINE URL ENGINE ROUTER ---
    func updateActiveUrl(urlString: String, searchEngine: String = "Google") {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabId }) else { return }
        
        var formattedString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !formattedString.contains("://") && !formattedString.hasPrefix("about:") {
            if formattedString.contains(".") && !formattedString.contains(" ") {
                formattedString = "https://" + formattedString
            } else {
                let query = formattedString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                
                switch searchEngine {
                case "DuckDuckGo":
                    formattedString = "https://duckduckgo.com/?q=" + query
                case "Bing":
                    formattedString = "https://www.bing.com/search?q=" + query
                case "Brave Search":
                    formattedString = "https://search.brave.com/search?q=" + query
                case "Ecosia":
                    formattedString = "https://www.ecosia.org/search?q=" + query
                default: // Google Default Fallback
                    formattedString = "https://www.google.com/search?q=" + query
                }
            }
        }
        
        if let url = URL(string: formattedString) {
            tabs[index].url = url
            tabs[index].urlString = formattedString
            tabs[index].title = url.host ?? formattedString
            
            if !tabs[index].isPrivate {
                saveSession()
                logVisitToCoreData(url: url, title: tabs[index].title)
            }
        }
    }
    
    // --- SELF-CONTAINED BACKGROUND CORE DATA LOGGING ROUTINE ---
    private func logVisitToCoreData(url: URL, title: String) {
        let context = PersistenceController.shared.container.viewContext
        context.perform {
            let historyItem = HistoryItem(context: context)
            historyItem.timestamp = Date()
            historyItem.url = url.absoluteString
            historyItem.title = title
            
            do {
                try context.save()
            } catch {
                print("Failed to record cosmic history event: \(error)")
            }
        }
    }
    
    func closeTab(id: UUID) {
        guard tabs.count > 1 else { return }
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        
        let wasActive = (activeTabId == id)
        let primaryTab = tabs[index]
        tabs.remove(at: index)
        
        if wasActive {
            let nextIndex = min(index, tabs.count - 1)
            activeTabId = tabs[nextIndex].id
        }
        
        if !primaryTab.isPrivate {
            saveSession()
        }
    }
    
    func reloadActiveTab() {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabId }) else { return }
        tabs[index].reloadTrigger = UUID()
    }
    
    func saveSession() {
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
}

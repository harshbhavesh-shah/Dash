//
//  TabModel.swift
//  Shrome
//

import SwiftUI
import Foundation
import Combine
import CoreData // --- Added to allow background context thread logs ---

struct Tab: Identifiable, Hashable, Codable {
    var id: UUID
    var url: URL
    var urlString: String
    var title: String
    var isPrivate: Bool
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
    
    func createNewTab(urlString: String = "about:blank", isPrivate: Bool = false) {
        let newTab = Tab(
            id: UUID(),
            url: URL(string: urlString) ?? URL(string: "about:blank")!,
            urlString: urlString,
            title: urlString == "about:blank" ? "New Tab" : urlString,
            isPrivate: isPrivate
        )
        
        self.tabs.append(newTab)
        self.activeTabId = newTab.id
        
        if !isPrivate {
            saveSession()
        }
    }
    
    func updateActiveUrl(urlString: String) {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabId }) else { return }
        
        var formattedString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !formattedString.contains("://") && !formattedString.hasPrefix("about:") {
            if formattedString.contains(".") && !formattedString.contains(" ") {
                formattedString = "https://" + formattedString
            } else {
                let query = formattedString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                formattedString = "https://www.google.com/search?q=" + query
            }
        }
        
        if let url = URL(string: formattedString) {
            tabs[index].url = url
            tabs[index].urlString = formattedString
            tabs[index].title = url.host ?? formattedString
            
            if !tabs[index].isPrivate {
                saveSession()
                // --- FIXED: NATIVE ROUTING PIPELINE TO PERSISTENCECONTROLLER ---
                logVisitToCoreData(url: url, title: tabs[index].title)
            }
        }
    }
    
    // --- FIXED: SELF-CONTAINED CORE DATA RECORDING ROUTINE ---
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
                print("Failed to save cosmic history item: \(error)")
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

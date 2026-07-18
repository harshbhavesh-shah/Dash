//
//  UpdateChecker.swift
//  Shrome
//
//  Created by Harsh Shah on 12/07/2026.
//


import Foundation
import Combine

struct UpdateInfo: Equatable {
    let version: String       
    let releaseURL: URL
    let releaseNotes: String 
}

class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    private let repoOwner = "harshbhavesh-shah"
    private let repoName = "Shrome"

    @Published var updateAvailable: UpdateInfo? = nil

    private let session = URLSession(configuration: .ephemeral)

    private init() {}

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdatesIfNeeded() {
        let defaults = UserDefaults.standard
        let lastCheck = defaults.object(forKey: "lastUpdateCheckDate") as? Date
        if let lastCheck, Date().timeIntervalSince(lastCheck) < 24 * 60 * 60 {
            return
        }
        defaults.set(Date(), forKey: "lastUpdateCheckDate")
        performCheck(isManual: false)
    }
    func checkForUpdatesManually() {
        performCheck(isManual: true)
    }

    func dismiss() {
        if let version = updateAvailable?.version {
            UserDefaults.standard.set(version, forKey: "dismissedUpdateVersion")
        }
        updateAvailable = nil
    }

    // MARK: - Networking

    private func performCheck(isManual: Bool) {
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        session.dataTask(with: request) { [weak self] data, _, error in
            guard let self, let data, error == nil else { return }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlURLString = json["html_url"] as? String,
                  let htmlURL = URL(string: htmlURLString)
            else { return }

            let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            let notes = (json["body"] as? String) ?? ""

            DispatchQueue.main.async {
                guard self.isVersion(remoteVersion, newerThan: self.currentVersion) else { return }

                if !isManual {
                    let dismissedVersion = UserDefaults.standard.string(forKey: "dismissedUpdateVersion")
                    if dismissedVersion == remoteVersion { return }
                }

                self.updateAvailable = UpdateInfo(version: remoteVersion, releaseURL: htmlURL, releaseNotes: notes)
            }
        }.resume()
    }

    // MARK: - Version comparison

    private func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let lhsParts = lhs.split(separator: ".").compactMap { Int($0) }
        let rhsParts = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(lhsParts.count, rhsParts.count)

        for i in 0..<count {
            let l = i < lhsParts.count ? lhsParts[i] : 0
            let r = i < rhsParts.count ? rhsParts[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}

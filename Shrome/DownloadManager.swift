//
//  DownloadManager.swift
//  Shrome
//
//  Created by Harsh Shah on 11/07/2026.
//



import Foundation
import SwiftUI
import WebKit
import Combine
import CoreData


struct DownloadProgressInfo: Identifiable {
    let id: UUID
    var receivedBytes: Int64
    var totalBytes: Int64
    var fractionCompleted: Double
}


struct ShelfDownloadInfo: Identifiable, Equatable {
    let id: UUID
    var filename: String
    var status: String
    var fractionCompleted: Double
}

class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var activeProgress: [UUID: DownloadProgressInfo] = [:]
    @Published var shelfItems: [ShelfDownloadInfo] = []
    @Published var isShelfVisible: Bool = false

    func dismissShelf() {
        isShelfVisible = false
        shelfItems.removeAll()
    }

    private func scheduleShelfCleanup(id: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            guard let self else { return }
            withAnimation(.shromeSnappy) {
                self.shelfItems.removeAll { $0.id == id }
            }
            if self.shelfItems.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.shromeSnappy) {
                        self.isShelfVisible = false
                    }
                }
            }
        }
    }

    private var progressObservations: [UUID: NSKeyValueObservation] = [:]
    private var activeDownloads: [UUID: WKDownload] = [:]
    private var idsByDownload: [ObjectIdentifier: UUID] = [:]

    private lazy var backgroundContext: NSManagedObjectContext = {
        let ctx = PersistenceController.shared.container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }()

    private override init() {
        super.init()
    }

    func track(_ download: WKDownload) {
        download.delegate = self
    }

    func cancel(id: UUID) {
        activeDownloads[id]?.cancel()
    }

    // MARK: - Destination picking

    private func destinationURL(for suggestedFilename: String) -> URL {
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        let safeName = suggestedFilename.isEmpty ? "download" : suggestedFilename
        var candidate = downloadsDir.appendingPathComponent(safeName)

        let ext = candidate.pathExtension
        let base = candidate.deletingPathExtension().lastPathComponent
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let newName = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            candidate = downloadsDir.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }

    // MARK: - Persistence

    private func createRecord(id: UUID, filename: String, sourceURL: String, localPath: String, totalBytes: Int64) {
        let ctx = backgroundContext
        ctx.perform {
            let item = DownloadItem(context: ctx)
            item.id = id
            item.filename = filename
            item.sourceURL = sourceURL
            item.localPath = localPath
            item.timestamp = Date()
            item.status = "downloading"
            item.receivedBytes = 0
            item.totalBytes = totalBytes
            try? ctx.save()
        }
    }

    private func updateRecord(id: UUID, mutate: @escaping (DownloadItem) -> Void) {
        let ctx = backgroundContext
        ctx.perform {
            let request = NSFetchRequest<DownloadItem>(entityName: "DownloadItem")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let item = try? ctx.fetch(request).first else { return }
            mutate(item)
            try? ctx.save()
        }
    }

    private func cleanup(id: UUID, download: WKDownload) {
        progressObservations[id]?.invalidate()
        progressObservations[id] = nil
        activeDownloads[id] = nil
        idsByDownload[ObjectIdentifier(download)] = nil
        DispatchQueue.main.async {
            self.activeProgress[id] = nil
        }
    }
}

// MARK: - WKDownloadDelegate

extension DownloadManager: WKDownloadDelegate {
    func download(_ download: WKDownload,
                   decideDestinationUsing response: URLResponse,
                   suggestedFilename: String,
                   completionHandler: @escaping (URL?) -> Void) {
        let id = UUID()
        let destination = destinationURL(for: suggestedFilename)
        let totalBytes = response.expectedContentLength > 0 ? response.expectedContentLength : 0

        idsByDownload[ObjectIdentifier(download)] = id
        activeDownloads[id] = download

        DispatchQueue.main.async {
            self.activeProgress[id] = DownloadProgressInfo(
                id: id, receivedBytes: 0, totalBytes: totalBytes, fractionCompleted: 0
            )

            withAnimation(.shromeBouncy) {
                self.isShelfVisible = true
                self.shelfItems.append(
                    ShelfDownloadInfo(id: id, filename: destination.lastPathComponent, status: "downloading", fractionCompleted: 0)
                )
            }
        }

        createRecord(
            id: id,
            filename: destination.lastPathComponent,
            sourceURL: response.url?.absoluteString ?? "",
            localPath: destination.path,
            totalBytes: totalBytes
        )

        let observation = download.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.activeProgress[id]?.fractionCompleted = progress.fractionCompleted
                self.activeProgress[id]?.receivedBytes = progress.completedUnitCount
                self.activeProgress[id]?.totalBytes = progress.totalUnitCount

                if let idx = self.shelfItems.firstIndex(where: { $0.id == id }) {
                    self.shelfItems[idx].fractionCompleted = progress.fractionCompleted
                }
            }
        }
        progressObservations[id] = observation

        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let id = idsByDownload[ObjectIdentifier(download)] else { return }
        updateRecord(id: id) { item in
            item.status = "completed"
            item.receivedBytes = item.totalBytes
        }
        DispatchQueue.main.async {
            if let idx = self.shelfItems.firstIndex(where: { $0.id == id }) {
                self.shelfItems[idx].status = "completed"
            }
            self.scheduleShelfCleanup(id: id)
        }
        cleanup(id: id, download: download)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let id = idsByDownload[ObjectIdentifier(download)] else { return }
        updateRecord(id: id) { item in
            item.status = "failed"
        }
        DispatchQueue.main.async {
            if let idx = self.shelfItems.firstIndex(where: { $0.id == id }) {
                self.shelfItems[idx].status = "failed"
            }
            self.scheduleShelfCleanup(id: id)
        }
        cleanup(id: id, download: download)
    }
}

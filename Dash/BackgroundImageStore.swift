//
//  BackgroundImageStore.swift
//  Dash
//
//  Created by Harsh Shah on 06/03/2026.
//

import AppKit
import SwiftUI
internal import UniformTypeIdentifiers

enum BackgroundImageStore {

    static let appStorageKey = "landingBackgroundImagePath"

    private static var backgroundsDirectory: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport
            .appendingPathComponent("Dash", isDirectory: true)
            .appendingPathComponent("Backgrounds", isDirectory: true)

        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }


    @discardableResult
    static func pickAndSaveImage() -> String? {
        let panel = NSOpenPanel()
        panel.title = "Choose a Background Image"
        panel.message = "Pick a photo to use as your landing page background"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.image]
        } else {
            panel.allowedFileTypes = ["png", "jpg", "jpeg", "heic", "gif", "tiff", "bmp"]
        }

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return nil }
        return save(from: sourceURL)
    }

    @discardableResult
    static func save(from sourceURL: URL) -> String? {
        guard let dir = backgroundsDirectory else { return nil }

        clearStoredFile()

        let ext = sourceURL.pathExtension.isEmpty ? "img" : sourceURL.pathExtension
        let destinationURL = dir.appendingPathComponent("landing-background-\(UUID().uuidString).\(ext)")

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL.path
        } catch {
            print("Background image save failed: \(error)")
            return nil
        }
    }


    static func clearStoredFile() {
        guard let dir = backgroundsDirectory,
              let existing = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return }
        
        for file in existing {
            try? FileManager.default.removeItem(at: file)
        }
    }
    
    static func loadImage(at path: String) -> NSImage? {
        guard !path.isEmpty else { return nil }
        return NSImage(contentsOfFile: path)
    }
}

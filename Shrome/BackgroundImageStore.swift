//
//  BackgroundImageStore.swift
//  Shrome
//
//  Handles persisting a user-chosen landing page background image to disk.
//  We store a *copy* of the image in Application Support (rather than the
//  raw bytes in UserDefaults) so arbitrarily large photos don't bloat
//  UserDefaults, and only the file path is kept in @AppStorage.
//

import AppKit
import SwiftUI
internal import UniformTypeIdentifiers

enum BackgroundImageStore {
    /// The @AppStorage key shared between GravityPreferencesView and
    /// GravityLandingView for the saved background image's file path.
    static let appStorageKey = "landingBackgroundImagePath"

    private static var backgroundsDirectory: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport
            .appendingPathComponent("Shrome", isDirectory: true)
            .appendingPathComponent("Backgrounds", isDirectory: true)

        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Presents an NSOpenPanel for image selection, copies the chosen file
    /// into the app's support directory, and returns the new file's path.
    /// Returns nil if the user cancels or the copy fails.
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

    /// Copies an image at `sourceURL` into the app's Backgrounds directory,
    /// removing any previously saved background first so we don't
    /// accumulate orphaned files, and returns the path to the saved copy.
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

    /// Deletes any currently saved background image file(s) from disk.
    /// Callers are still responsible for clearing the AppStorage-backed
    /// path themselves so the UI updates.
    static func clearStoredFile() {
        guard let dir = backgroundsDirectory,
              let existing = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return }

        for file in existing {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Loads the image at the given path, if any. Safe to call with an
    /// empty string (returns nil rather than throwing).
    static func loadImage(at path: String) -> NSImage? {
        guard !path.isEmpty else { return nil }
        return NSImage(contentsOfFile: path)
    }
}

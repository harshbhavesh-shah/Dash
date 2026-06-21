//
//  InlineCompleteTextField.swift
//  Shrome
//
//  A macOS NSTextField subclass that renders inline ghost-text autocomplete.
//  The user types "git" → the field shows "github.com" with "hub.com" in grey.
//  Tab / → / Return all accept the completion.
//  Escape clears it without navigating.
//

import SwiftUI
import AppKit

// MARK: - SwiftUI wrapper

struct InlineCompleteTextField: NSViewRepresentable {
    /// The live text the user is typing (two-way).
    @Binding var text: String
    /// The full suggested completion string (e.g. "github.com").
    /// Supply nil when there is no suggestion.
    var suggestion: String?
    var placeholder: String = ""
    var font: NSFont = .systemFont(ofSize: 14, weight: .medium)
    var textColor: NSColor = .labelColor
    /// When true, this field grabs keyboard focus shortly after it first
    /// appears — used by the landing page's search field so a brand new
    /// tab is immediately ready to type into. Defaults to false so the
    /// floating address bar (which uses this same component while
    /// browsing) never steals focus unexpectedly.
    var autoFocusOnAppear: Bool = false

    /// Called when the user commits — either by accepting the completion
    /// or by pressing Return on their own typed text.
    var onCommit: () -> Void
    /// Called when Escape is pressed — lets the parent clear the suggestion.
    var onEscape: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> GhostTextField {
        let field = GhostTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = font
        field.textColor = textColor
        field.placeholderString = placeholder
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        context.coordinator.setupFocusObserver(for: field)

        if autoFocusOnAppear {
            // FIX: GravityLandingView previously tried to drive this via a
            // @FocusState that was never actually attached to this field
            // with .focused(...) — on macOS, SwiftUI's FocusState doesn't
            // automatically wire up to NSViewRepresentable-backed controls
            // the way it does for native SwiftUI controls, so setting it
            // was a complete no-op and the cursor never actually landed in
            // the search bar. Driving focus directly via makeFirstResponder
            // (the same mechanism the working ⌘L "Open Location" shortcut
            // already uses) is the reliable way to do this for an
            // NSTextField. The short delay is needed because the field
            // isn't actually attached to a window yet the instant
            // makeNSView returns.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak field] in
                guard let field else { return }
                field.window?.makeFirstResponder(field)
            }
        }

        return field
    }

    func updateNSView(_ nsView: GhostTextField, context: Context) {
        context.coordinator.parent = self

        // Only update the field's string when it genuinely differs — avoids
        // fighting the user mid-keystroke.
        if nsView.stringValue != text {
            nsView.stringValue = text
            // Keep cursor at the end after programmatic changes.
            if let editor = nsView.currentEditor() {
                let end = (text as NSString).length
                editor.selectedRange = NSRange(location: end, length: 0)
            }
        }

        // Update ghost text whenever the suggestion changes.
        nsView.ghostSuffix = ghostSuffix(for: text, suggestion: suggestion)
        nsView.needsDisplay = true
    }

    // Derives the grey suffix to draw: the part of the suggestion that
    // extends beyond what the user has already typed (case-insensitive).
    private func ghostSuffix(for typed: String, suggestion: String?) -> String? {
        guard let suggestion, !typed.isEmpty,
              suggestion.lowercased().hasPrefix(typed.lowercased()),
              suggestion.count > typed.count else { return nil }
        return String(suggestion.dropFirst(typed.count))
    }

    // MARK: Coordinator

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: InlineCompleteTextField

        // FIX: ⌘L ("Open Location", classic Safari/Chrome shortcut) has
        // nowhere else to land — there's no @FocusState plumbed in from
        // ContentView down to this field. Only one InlineCompleteTextField
        // is ever on screen at a time (landing page search vs. floating
        // address bar are mutually exclusive), so listening globally here
        // is unambiguous: whichever instance exists is the one that should
        // grab focus.
        private var focusObserver: NSObjectProtocol?

        init(_ parent: InlineCompleteTextField) {
            self.parent = parent
        }

        deinit {
            if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }
        }

        func setupFocusObserver(for field: GhostTextField) {
            focusObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name("MenuActionFocusAddressBar"), object: nil, queue: .main
            ) { [weak field] _ in
                guard let field else { return }
                field.window?.makeFirstResponder(field)
                field.currentEditor()?.selectAll(nil)
            }
        }

        // Live-sync text changes back to the binding.
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        // Intercept special keys before the field processes them.
        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy selector: Selector) -> Bool {
            guard let field = control as? GhostTextField else { return false }

            switch selector {
            case #selector(NSResponder.insertTab(_:)),
                 #selector(NSResponder.moveRight(_:)):
                // Tab or → accepts the ghost completion.
                if let suffix = field.ghostSuffix {
                    let completed = parent.text + suffix
                    parent.text = completed
                    field.stringValue = completed
                    field.ghostSuffix = nil
                    // Move cursor to end.
                    let end = (completed as NSString).length
                    textView.selectedRange = NSRange(location: end, length: 0)
                    return true
                }
                return false

            case #selector(NSResponder.insertNewline(_:)):
                // Return: if ghost text exists, accept it then commit.
                if let suffix = field.ghostSuffix {
                    let completed = parent.text + suffix
                    parent.text = completed
                    field.stringValue = completed
                    field.ghostSuffix = nil
                }
                parent.onCommit()
                return true

            case #selector(NSResponder.cancelOperation(_:)):
                // Escape: clear ghost text without navigating.
                field.ghostSuffix = nil
                field.needsDisplay = true
                parent.onEscape()
                return true

            default:
                return false
            }
        }
    }
}

// MARK: - Custom NSTextField that paints ghost text

final class GhostTextField: NSTextField {
    /// The grey suffix to render after the user's typed characters.
    var ghostSuffix: String? {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let suffix = ghostSuffix, !suffix.isEmpty,
              let cell = self.cell else { return }

        let drawFont = font ?? NSFont.systemFont(ofSize: 14)

        // titleRect(forBounds:) returns the exact rect NSTextFieldCell uses
        // to draw its own string — same insets, same vertical centering.
        // Using it means our ghost text sits on the identical baseline with
        // zero manual arithmetic.
        let titleRect = cell.titleRect(forBounds: bounds)

        // Measure only the typed portion so we know where to start the ghost.
        let typedWidth = (stringValue as NSString)
            .size(withAttributes: [.font: drawFont])
            .width

        let ghostOrigin = CGPoint(x: titleRect.minX + typedWidth, y: titleRect.minY)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: drawFont,
            .foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.55)
        ]
        (suffix as NSString).draw(at: ghostOrigin, withAttributes: attrs)
    }
}

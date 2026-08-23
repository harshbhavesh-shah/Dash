//
//  InlineCompleteTextField.swift
//  Dash
//
//  Created by Harsh Shah on 06/03/2026.
//

import SwiftUI
import AppKit

// MARK: - SwiftUI wrapper

struct InlineCompleteTextField: NSViewRepresentable {
    @Binding var text: String
    var suggestion: String?
    var placeholder: String = ""
    var font: NSFont = .systemFont(ofSize: 14, weight: .medium)
    var textColor: NSColor = .labelColor
    var autoFocusOnAppear: Bool = false
    var displayOverride: String? = nil
    var onCommit: () -> Void
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak field] in
                guard let field else { return }
                field.window?.makeFirstResponder(field)
            }
        }

        return field
    }

    func updateNSView(_ nsView: GhostTextField, context: Context) {
        context.coordinator.parent = self

        // BUG FIX: textColor was previously only ever set once, in
        // makeNSView. Even though NSColor.labelColor is itself a dynamic
        // color, the field's color never got refreshed after creation, so
        // changing the app's appearance mode had no visible effect on
        // already-created address bars.
        if nsView.textColor != textColor {
            nsView.textColor = textColor
        }

        let isActive = nsView.currentEditor() != nil
        // When not focused, show the display alias (e.g. just the host) if
        // one was provided. When focused, always show the real full text so
        // the user edits the actual URL, not the alias.
        let valueToShow = isActive ? text : (displayOverride ?? text)

        if nsView.stringValue != valueToShow {
            nsView.stringValue = valueToShow
            if isActive, let editor = nsView.currentEditor() {
                let end = (valueToShow as NSString).length
                editor.selectedRange = NSRange(location: end, length: 0)
            }
        }
        // Only show ghost suffix while actively editing.
        nsView.ghostSuffix = isActive ? ghostSuffix(for: text, suggestion: suggestion) : nil
        nsView.needsDisplay = true
    }

    private func ghostSuffix(for typed: String, suggestion: String?) -> String? {
        guard let suggestion, !typed.isEmpty,
              suggestion.lowercased().hasPrefix(typed.lowercased()),
              suggestion.count > typed.count else { return nil }
        return String(suggestion.dropFirst(typed.count))
    }

    // MARK: Coordinator

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: InlineCompleteTextField

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

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            // Switch from display alias to the real full URL so the user
            // edits the actual address, then select all for quick replacement.
            if field.stringValue != parent.text {
                field.stringValue = parent.text
            }
            // BUG FIX: this selectAll used to be deferred via
            // DispatchQueue.main.async, which opened a race window between
            // "editing began" and "select all actually ran." If the user
            // typed fast enough that a keystroke landed in that window, the
            // deferred selectAll would then select whatever they'd just
            // typed, and their very next keystroke would replace that
            // selection instead of appending to it — silently eating the
            // start of what they typed, worse the faster they typed. The
            // field editor is already installed by the time this delegate
            // method fires, so selecting synchronously closes the race.
            field.currentEditor()?.selectAll(nil)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let field = obj.object as? GhostTextField else { return }
            // Switch back to the display alias now that editing is done.
            let displayValue = parent.displayOverride ?? parent.text
            if field.stringValue != displayValue {
                field.stringValue = displayValue
                field.ghostSuffix = nil
                field.needsDisplay = true
            }
        }

        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy selector: Selector) -> Bool {
            guard let field = control as? GhostTextField else { return false }

            switch selector {
            case #selector(NSResponder.insertTab(_:)),
                 #selector(NSResponder.moveRight(_:)):
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
        let titleRect = cell.titleRect(forBounds: bounds)

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

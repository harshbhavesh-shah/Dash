//
//  InlineCompleteTextField.swift
//  Shrome
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
        if nsView.stringValue != text {
            nsView.stringValue = text
            if let editor = nsView.currentEditor() {
                let end = (text as NSString).length
                editor.selectedRange = NSRange(location: end, length: 0)
            }
        }
        nsView.ghostSuffix = ghostSuffix(for: text, suggestion: suggestion)
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

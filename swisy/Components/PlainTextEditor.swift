/*
 PlainTextEditor.swift

 A plain text editor wrapper around NSTextView with smart quotes/dashes disabled.
 Perfect for code, JSON, and other technical text where automatic substitutions break syntax.
 */

import SwiftUI
import AppKit

/// Plain text editor with automatic text substitutions disabled
///
/// Features:
/// - No smart quotes (always uses straight quotes: ")
/// - No smart dashes (always uses regular dashes: -)
/// - No automatic text replacement
/// - Monospaced font by default
/// - Proper text binding with SwiftUI
///
/// Usage:
/// ```swift
/// @State private var code = ""
///
/// PlainTextEditor(text: $code)
///     .frame(height: 200)
/// ```
struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        // Appearance
        textView.isEditable = true
        textView.isSelectable = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.font = font
        textView.textContainerInset = NSSize(width: 12, height: 12)

        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        textView.delegate = context.coordinator

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView

        // Only update if text actually changed to avoid cursor jumping
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlainTextEditor

        init(_ parent: PlainTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

// MARK: - Custom Font Support
extension PlainTextEditor {
    func font(_ font: NSFont) -> PlainTextEditor {
        var editor = self
        editor.font = font
        return editor
    }
}

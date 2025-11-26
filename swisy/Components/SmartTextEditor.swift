/*
 SmartTextEditor.swift

 Enhanced text editor with intelligent wrapping behavior.

 Features:
 - Natural text wrapping within available width
 - Hard limit at 120 characters (configurable)
 - Monospaced font
 - Character/line count support via CharacterCountView
 - macOS native behavior

 Usage:
 ```swift
 SmartTextEditor(text: $input)
 SmartTextEditor(text: $input, maxLineLength: 100)
 ```
 */

import SwiftUI
import AppKit

struct SmartTextEditor: NSViewRepresentable {
    @Binding var text: String
    var maxLineLength: Int = 120  // Hard wrap at this character count
    var font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    var availableWidth: CGFloat = 0  // Track container width for resize updates

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        // Basic setup
        textView.delegate = context.coordinator
        textView.font = font
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.textContainerInset = NSSize(width: 8, height: 8)

        // Configure text container
        if let textContainer = textView.textContainer {
            // Calculate maximum width for the character limit
            let charWidth = font.advancement(forGlyph: font.glyph(withName: "m")).width
            let maxWidth = charWidth * CGFloat(maxLineLength)

            // Set maximum width - text wraps naturally within this limit
            textContainer.containerSize = NSSize(
                width: maxWidth,
                height: CGFloat.greatestFiniteMagnitude
            )

            // Don't track text view size - use our fixed maximum
            textContainer.widthTracksTextView = false
            textContainer.heightTracksTextView = false
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Only update if text actually changed (avoid cursor jumping)
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text

            // Restore cursor position if valid
            if selectedRange.location <= text.count {
                textView.setSelectedRange(selectedRange)
            }
        }

        // Update text container width based on availableWidth or scroll view size
        if let textContainer = textView.textContainer {
            let charWidth = font.advancement(forGlyph: font.glyph(withName: "m")).width
            let maxWidth = charWidth * CGFloat(maxLineLength)

            // Use availableWidth if provided (from GeometryReader), otherwise fall back to contentSize
            let currentWidth = availableWidth > 0 ? availableWidth - 16 : scrollView.contentSize.width - 16

            // Use whichever is smaller: available width or maximum width
            let containerWidth = min(currentWidth, maxWidth)

            textContainer.containerSize = NSSize(
                width: containerWidth,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SmartTextEditor

        init(_ parent: SmartTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

// MARK: - Resize-Aware Wrapper

/// Wrapper that makes SmartTextEditor responsive to window resizing
struct ResizableSmartTextEditor: View {
    @Binding var text: String
    var maxLineLength: Int = 120
    var font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)

    @State private var debouncedWidth: CGFloat = 0
    @State private var resizeTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            SmartTextEditor(
                text: $text,
                maxLineLength: maxLineLength,
                font: font,
                availableWidth: debouncedWidth > 0 ? debouncedWidth : geometry.size.width
            )
            .onChange(of: geometry.size.width) { _, newWidth in
                // Cancel previous resize task
                resizeTask?.cancel()

                // Debounce resize updates (100ms)
                resizeTask = Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    guard !Task.isCancelled else { return }

                    await MainActor.run {
                        debouncedWidth = newWidth
                    }
                }
            }
            .onAppear {
                debouncedWidth = geometry.size.width
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Text("Should wrap at 120 characters:")
        SmartTextEditor(
            text: .constant(
                "This is a very long line that demonstrates wrapping behavior. " +
                String(repeating: "Lorem ipsum dolor sit amet. ", count: 5)
            ),
            maxLineLength: 120
        )
        .frame(height: 200)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    .padding()
}

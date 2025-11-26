/*
 CharacterCountView.swift

 Reusable character count indicator for text editors.
 Shows character count, line count, and wrap indicator.

 Usage:
 ```swift
 CharacterCountView(text: myText)
 CharacterCountView(text: myText, showLines: true, maxCharsPerLine: 120)
 ```
 */

import SwiftUI

struct CharacterCountView: View {
    let text: String
    var showLines: Bool = true
    var maxCharsPerLine: Int = 120

    private var stats: (chars: Int, lines: Int, hasWrappedLines: Bool) {
        let lines = text.components(separatedBy: .newlines)
        let hasWrapped = lines.contains { $0.count > maxCharsPerLine }
        return (
            chars: text.count,
            lines: lines.count,
            hasWrappedLines: hasWrapped
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            // Character count (number only)
            Text("\(stats.chars)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            // Wrapped indicator with tooltip
            if stats.hasWrappedLines {
                Text("W")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
                    .help("Text has wrapped lines exceeding \(maxCharsPerLine) characters")
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CharacterCountView(text: "Hello World")

        CharacterCountView(text: "Line 1\nLine 2\nLine 3")

        CharacterCountView(text: String(repeating: "x", count: 150))

        CharacterCountView(
            text: "Short line\n" + String(repeating: "x", count: 150),
            maxCharsPerLine: 140
        )
    }
    .padding()
}

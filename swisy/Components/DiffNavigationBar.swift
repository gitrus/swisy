/*
 DiffNavigationBar.swift
 Prev/Next hunk navigation with counter. Used by TextDiffTool and JSONDiffTool.
 */

import SwiftUI

struct DiffNavigationBar: View {
    let currentIndex: Int
    let totalCount: Int
    var onPrevious: () -> Void
    var onNext: () -> Void

    private var hasPrevious: Bool { currentIndex > 0 }
    private var hasNext: Bool { totalCount > 0 && currentIndex < totalCount - 1 }

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onPrevious) {
                Label("Previous", systemImage: "chevron.up").labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .disabled(!hasPrevious)

            if totalCount > 0, currentIndex >= 0 {
                Text("\(currentIndex + 1)/\(totalCount)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 30)
            }

            Button(action: onNext) {
                Label("Next", systemImage: "chevron.down").labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .disabled(!hasNext)
        }
    }
}

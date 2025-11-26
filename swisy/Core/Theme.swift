/*
 Theme.swift
 Shared colors for the app.
 */

import AppKit

// MARK: - Common Colors

enum AppColors {
    /// Search/find highlight color
    static let searchHighlight = NSColor.yellow.withAlphaComponent(0.5)
}

// MARK: - Diff Colors

enum DiffColors {
    // Background colors for diff lines
    static let deletedBackground = NSColor.systemRed.withAlphaComponent(0.2)
    static let addedBackground = NSColor.systemGreen.withAlphaComponent(0.2)
    static let modifiedBackground = NSColor.systemOrange.withAlphaComponent(0.2)
    static let unchangedBackground = NSColor.textBackgroundColor

    // Line number backgrounds (lighter)
    static let deletedLineNumBackground = NSColor.systemRed.withAlphaComponent(0.1)
    static let addedLineNumBackground = NSColor.systemGreen.withAlphaComponent(0.1)
    static let modifiedLineNumBackground = NSColor.systemOrange.withAlphaComponent(0.1)
    static let unchangedLineNumBackground = NSColor.windowBackgroundColor.withAlphaComponent(0.5)

    // Character-level highlight colors
    static let deletedHighlight = NSColor.systemRed.withAlphaComponent(0.4)
    static let addedHighlight = NSColor.systemGreen.withAlphaComponent(0.4)
}

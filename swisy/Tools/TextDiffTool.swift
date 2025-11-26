/*
 TextDiffTool.swift
 Side-by-side text diff comparator using Swift's native Myers algorithm.
 */

import SwiftUI
import AppKit

// MARK: - Tool Registration

struct TextDiffTool: Tool, Sendable {
    let id = "text-diff"
    let name = "Text Diff"
    let icon = "arrow.left.arrow.right"
    let category: ToolCategory = .text

    func makeView() -> AnyView {
        AnyView(TextDiffView())
    }

    static func == (lhs: TextDiffTool, rhs: TextDiffTool) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Models

enum DiffLineType: Equatable {
    case unchanged, added, deleted, modified
}

struct DiffLine: Identifiable, Equatable {
    let id = UUID()
    let leftLineNumber: Int?
    let rightLineNumber: Int?
    let leftContent: String?
    let rightContent: String?
    let type: DiffLineType
    let leftChangedRanges: [Range<String.Index>]
    let rightChangedRanges: [Range<String.Index>]

    init(leftLineNumber: Int?, rightLineNumber: Int?, leftContent: String?, rightContent: String?,
         type: DiffLineType, leftChangedRanges: [Range<String.Index>] = [], rightChangedRanges: [Range<String.Index>] = []) {
        self.leftLineNumber = leftLineNumber
        self.rightLineNumber = rightLineNumber
        self.leftContent = leftContent
        self.rightContent = rightContent
        self.type = type
        self.leftChangedRanges = leftChangedRanges
        self.rightChangedRanges = rightChangedRanges
    }
}

struct DiffStats: Equatable {
    let additions: Int
    let deletions: Int
    let modifications: Int
    let unchanged: Int

    var hasChanges: Bool { additions > 0 || deletions > 0 || modifications > 0 }
}

// MARK: - ViewModel

@MainActor
final class TextDiffToolState: ObservableObject {
    @Published var leftText = ""
    @Published var rightText = ""
}

// MARK: - Diff Algorithm

enum TextDiffer {
    /// Minimum similarity ratio (0.0-1.0) to consider two lines as "modified" rather than delete+add
    private static let similarityThreshold: Double = 0.5

    static func diff(left: String, right: String) -> [DiffLine] {
        let leftLines = left.components(separatedBy: .newlines)
        let rightLines = right.components(separatedBy: .newlines)

        guard !(leftLines == [""] && rightLines == [""]) else { return [] }

        // Get raw diff using Myers algorithm
        let difference = rightLines.difference(from: leftLines)

        var removedIndices = Set<Int>()
        var insertedIndices = Set<Int>()

        for change in difference {
            switch change {
            case .remove(let offset, _, _): removedIndices.insert(offset)
            case .insert(let offset, _, _): insertedIndices.insert(offset)
            }
        }

        // Build result with similarity-based pairing
        var result: [DiffLine] = []
        var leftIdx = 0, rightIdx = 0, leftNum = 1, rightNum = 1

        while leftIdx < leftLines.count || rightIdx < rightLines.count {
            let isRemoved = removedIndices.contains(leftIdx) && leftIdx < leftLines.count
            let isInserted = insertedIndices.contains(rightIdx) && rightIdx < rightLines.count

            if isRemoved && isInserted {
                // Both have changes - check similarity to decide: modified vs delete+add
                let leftLine = leftLines[leftIdx]
                let rightLine = rightLines[rightIdx]

                if similarity(leftLine, rightLine) >= similarityThreshold {
                    // Similar enough - show as modification on same row
                    let charDiff = characterDiff(left: leftLine, right: rightLine)
                    result.append(DiffLine(leftLineNumber: leftNum, rightLineNumber: rightNum,
                                           leftContent: leftLine, rightContent: rightLine, type: .modified,
                                           leftChangedRanges: charDiff.left, rightChangedRanges: charDiff.right))
                    leftIdx += 1; rightIdx += 1; leftNum += 1; rightNum += 1
                } else {
                    // Not similar - show as separate delete and add
                    result.append(DiffLine(leftLineNumber: leftNum, rightLineNumber: nil,
                                           leftContent: leftLine, rightContent: nil, type: .deleted))
                    leftIdx += 1; leftNum += 1
                }
            } else if isRemoved {
                result.append(DiffLine(leftLineNumber: leftNum, rightLineNumber: nil,
                                       leftContent: leftLines[leftIdx], rightContent: nil, type: .deleted))
                leftIdx += 1; leftNum += 1
            } else if isInserted {
                result.append(DiffLine(leftLineNumber: nil, rightLineNumber: rightNum,
                                       leftContent: nil, rightContent: rightLines[rightIdx], type: .added))
                rightIdx += 1; rightNum += 1
            } else if leftIdx < leftLines.count && rightIdx < rightLines.count {
                // Unchanged
                result.append(DiffLine(leftLineNumber: leftNum, rightLineNumber: rightNum,
                                       leftContent: leftLines[leftIdx], rightContent: rightLines[rightIdx], type: .unchanged))
                leftIdx += 1; rightIdx += 1; leftNum += 1; rightNum += 1
            } else if leftIdx < leftLines.count {
                result.append(DiffLine(leftLineNumber: leftNum, rightLineNumber: nil,
                                       leftContent: leftLines[leftIdx], rightContent: nil, type: .deleted))
                leftIdx += 1; leftNum += 1
            } else {
                result.append(DiffLine(leftLineNumber: nil, rightLineNumber: rightNum,
                                       leftContent: nil, rightContent: rightLines[rightIdx], type: .added))
                rightIdx += 1; rightNum += 1
            }
        }
        return result
    }

    /// Calculate similarity ratio between two strings (0.0 = completely different, 1.0 = identical)
    /// Uses Levenshtein edit distance - counts actual character edits needed
    private static func similarity(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty || !b.isEmpty else { return 1.0 }
        guard !a.isEmpty && !b.isEmpty else { return 0.0 }

        let distance = levenshteinDistance(Array(a), Array(b))
        let maxLen = max(a.count, b.count)
        return 1.0 - (Double(distance) / Double(maxLen))
    }

    /// Compute Levenshtein edit distance using dynamic programming
    private static func levenshteinDistance<T: Equatable>(_ a: [T], _ b: [T]) -> Int {
        let m = a.count, n = b.count
        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    curr[j] = prev[j - 1]  // No edit needed
                } else {
                    curr[j] = 1 + min(prev[j],      // deletion
                                      curr[j - 1],   // insertion
                                      prev[j - 1])   // substitution
                }
            }
            swap(&prev, &curr)
        }
        return prev[n]
    }

    static func computeStats(from lines: [DiffLine]) -> DiffStats {
        var add = 0, del = 0, mod = 0, unch = 0
        for line in lines {
            switch line.type {
            case .added: add += 1
            case .deleted: del += 1
            case .modified: mod += 1
            case .unchanged: unch += 1
            }
        }
        return DiffStats(additions: add, deletions: del, modifications: mod, unchanged: unch)
    }

    private static func characterDiff(left: String, right: String) -> (left: [Range<String.Index>], right: [Range<String.Index>]) {
        let diff = Array(right).difference(from: Array(left))
        var removed = Set<Int>(), inserted = Set<Int>()

        for change in diff {
            switch change {
            case .remove(let offset, _, _): removed.insert(offset)
            case .insert(let offset, _, _): inserted.insert(offset)
            }
        }
        return (indicesToRanges(removed, in: left), indicesToRanges(inserted, in: right))
    }

    private static func indicesToRanges(_ indices: Set<Int>, in string: String) -> [Range<String.Index>] {
        guard !indices.isEmpty else { return [] }

        var ranges: [Range<String.Index>] = []
        let sorted = indices.sorted()
        var start = sorted[0], end = sorted[0]

        for i in sorted.dropFirst() {
            if i == end + 1 {
                end = i
            } else {
                if let s = string.index(string.startIndex, offsetBy: start, limitedBy: string.endIndex),
                   let e = string.index(string.startIndex, offsetBy: end + 1, limitedBy: string.endIndex) {
                    ranges.append(s..<e)
                }
                start = i; end = i
            }
        }
        if let s = string.index(string.startIndex, offsetBy: start, limitedBy: string.endIndex),
           let e = string.index(string.startIndex, offsetBy: end + 1, limitedBy: string.endIndex) {
            ranges.append(s..<e)
        }
        return ranges
    }
}

// MARK: - Main View

struct TextDiffView: View {
    @ObservedObject private var state = ToolStateRegistry.shared.textDiff
    @State private var diffLines: [DiffLine] = []
    @State private var stats: DiffStats?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            inputPanels
            Divider()
            diffResultView
            Divider()
            statusBar
        }
        .navigationTitle("Text Diff")
        .task(id: state.leftText + state.rightText) {
            try? await Task.sleep(for: .milliseconds(200))
            computeDiff()
        }
    }

    private var toolbar: some View {
        HStack {
            Text("Text Diff").font(.headline)
            Spacer()
            Button("Swap", systemImage: "arrow.left.arrow.right") {
                swap(&state.leftText, &state.rightText)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            Button("Clear", systemImage: "trash") {
                state.leftText = ""
                state.rightText = ""
            }
        }
        .padding()
    }

    private var inputPanels: some View {
        HSplitView {
            inputPanel(title: "Original (Left)", text: $state.leftText, shortcutKey: "1")
            inputPanel(title: "Modified (Right)", text: $state.rightText, shortcutKey: "2")
        }
        .frame(minHeight: 150, maxHeight: 250)
    }

    private func inputPanel(title: String, text: Binding<String>, shortcutKey: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                CharacterCountView(text: text.wrappedValue)
                Button(action: { if let p = ClipboardService.shared.paste() { text.wrappedValue = p } }) {
                    Label("Paste", systemImage: "doc.on.clipboard").labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Paste (⌘⇧\(shortcutKey))")
            }
            ResizablePlainTextEditor(text: text)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
        }
        .padding()
    }

    private var diffResultView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Diff Result").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if let stats, stats.hasChanges {
                    Button(action: copyUnifiedDiff) {
                        Label("Copy Unified", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Group {
                if diffLines.isEmpty && state.leftText.isEmpty && state.rightText.isEmpty {
                    emptyStateView(icon: "arrow.left.arrow.right", title: "Compare Two Texts",
                                   description: "Paste or type text in both panels to see differences")
                } else if stats == nil {
                    VStack { ProgressView().padding(.top, 40); Spacer() }
                } else if !stats!.hasChanges {
                    emptyStateView(icon: "checkmark.circle", title: "No Differences",
                                   description: "Both texts are identical")
                } else {
                    DiffTableView(lines: diffLines)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        }
    }

    private func emptyStateView(icon: String, title: String, description: String) -> some View {
        VStack {
            ContentUnavailableView { Label(title, systemImage: icon) } description: { Text(description) }
            Spacer()
        }
    }

    private var statusBar: some View {
        HStack {
            if let stats, stats.hasChanges {
                HStack(spacing: 16) {
                    if stats.additions > 0 { Label("\(stats.additions)", systemImage: "plus").foregroundStyle(.green) }
                    if stats.deletions > 0 { Label("\(stats.deletions)", systemImage: "minus").foregroundStyle(.red) }
                    if stats.modifications > 0 { Label("\(stats.modifications)", systemImage: "pencil").foregroundStyle(.orange) }
                    if stats.unchanged > 0 { Label("\(stats.unchanged)", systemImage: "equal").foregroundStyle(.secondary) }
                }
                .font(.caption)
            }
            Spacer()
            Text("Myers algorithm (same as git)").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func computeDiff() {
        guard !state.leftText.isEmpty || !state.rightText.isEmpty else {
            diffLines = []; stats = nil; return
        }
        diffLines = TextDiffer.diff(left: state.leftText, right: state.rightText)
        stats = TextDiffer.computeStats(from: diffLines)
    }

    private func copyUnifiedDiff() {
        var output = "--- original\n+++ modified\n"
        for line in diffLines {
            switch line.type {
            case .deleted: output += "-\(line.leftContent ?? "")\n"
            case .added: output += "+\(line.rightContent ?? "")\n"
            case .modified:
                output += "-\(line.leftContent ?? "")\n"
                output += "+\(line.rightContent ?? "")\n"
            case .unchanged: output += " \(line.leftContent ?? "")\n"
            }
        }
        ClipboardService.shared.copy(output)
    }
}

// MARK: - Diff Table View (3 synchronized panels)

struct DiffTableView: NSViewRepresentable {
    let lines: [DiffLine]

    private let lineNumberColumnWidth: CGFloat = 70
    private let minContentColumnWidth: CGFloat = 200
    private let rowHeight: CGFloat = 20
    private let contentPadding: CGFloat = 20

    func makeNSView(context: Context) -> NSView {
        let container = NSView()

        // Create 3 table views: left content, line numbers, right content
        let leftScrollView = createScrollView(hasHorizontalScroller: true)
        let centerScrollView = createScrollView(hasHorizontalScroller: false)
        let rightScrollView = createScrollView(hasHorizontalScroller: true, hasVerticalScroller: true)

        let leftTable = createTableView()
        let centerTable = createTableView()
        let rightTable = createTableView()

        // Configure columns
        let leftCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("content"))
        leftCol.minWidth = 100
        leftTable.addTableColumn(leftCol)

        let centerCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lineNums"))
        centerCol.width = lineNumberColumnWidth
        centerCol.minWidth = lineNumberColumnWidth
        centerCol.maxWidth = lineNumberColumnWidth
        centerTable.addTableColumn(centerCol)

        let rightCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("content"))
        rightCol.minWidth = 100
        rightTable.addTableColumn(rightCol)

        leftScrollView.documentView = leftTable
        centerScrollView.documentView = centerTable
        rightScrollView.documentView = rightTable

        // Store references
        context.coordinator.leftTable = leftTable
        context.coordinator.centerTable = centerTable
        context.coordinator.rightTable = rightTable
        context.coordinator.leftScrollView = leftScrollView
        context.coordinator.centerScrollView = centerScrollView
        context.coordinator.rightScrollView = rightScrollView
        context.coordinator.lines = lines

        // Set delegates
        leftTable.delegate = context.coordinator
        leftTable.dataSource = context.coordinator
        centerTable.delegate = context.coordinator
        centerTable.dataSource = context.coordinator
        rightTable.delegate = context.coordinator
        rightTable.dataSource = context.coordinator

        // Tag tables to identify them
        leftTable.tag = 0
        centerTable.tag = 1
        rightTable.tag = 2

        // Add to container
        container.addSubview(leftScrollView)
        container.addSubview(centerScrollView)
        container.addSubview(rightScrollView)

        // Setup constraints
        leftScrollView.translatesAutoresizingMaskIntoConstraints = false
        centerScrollView.translatesAutoresizingMaskIntoConstraints = false
        rightScrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            leftScrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            leftScrollView.topAnchor.constraint(equalTo: container.topAnchor),
            leftScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            centerScrollView.leadingAnchor.constraint(equalTo: leftScrollView.trailingAnchor),
            centerScrollView.topAnchor.constraint(equalTo: container.topAnchor),
            centerScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            centerScrollView.widthAnchor.constraint(equalToConstant: lineNumberColumnWidth),

            rightScrollView.leadingAnchor.constraint(equalTo: centerScrollView.trailingAnchor),
            rightScrollView.topAnchor.constraint(equalTo: container.topAnchor),
            rightScrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            rightScrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            leftScrollView.widthAnchor.constraint(equalTo: rightScrollView.widthAnchor)
        ])

        // Setup scroll synchronization
        context.coordinator.setupScrollSync()

        // Update column widths
        DispatchQueue.main.async { context.coordinator.updateColumnWidths() }

        return container
    }

    private func createScrollView(hasHorizontalScroller: Bool, hasVerticalScroller: Bool = false) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = hasVerticalScroller
        scrollView.hasHorizontalScroller = hasHorizontalScroller
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        return scrollView
    }

    private func createTableView() -> NSTableView {
        let tableView = NSTableView()
        tableView.style = .plain
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.gridStyleMask = []
        tableView.intercellSpacing = .zero
        tableView.rowHeight = rowHeight
        tableView.headerView = nil
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.allowsColumnResizing = false
        return tableView
    }

    func updateNSView(_ container: NSView, context: Context) {
        context.coordinator.lines = lines
        context.coordinator.leftTable?.reloadData()
        context.coordinator.centerTable?.reloadData()
        context.coordinator.rightTable?.reloadData()
        DispatchQueue.main.async { context.coordinator.updateColumnWidths() }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(lines: lines, minContentColumnWidth: minContentColumnWidth, contentPadding: contentPadding)
    }

    @MainActor
    class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var lines: [DiffLine]
        weak var leftTable: NSTableView?
        weak var centerTable: NSTableView?
        weak var rightTable: NSTableView?
        weak var leftScrollView: NSScrollView?
        weak var centerScrollView: NSScrollView?
        weak var rightScrollView: NSScrollView?

        private var isSyncing = false
        private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        private let minContentColumnWidth: CGFloat
        private let contentPadding: CGFloat

        init(lines: [DiffLine], minContentColumnWidth: CGFloat, contentPadding: CGFloat) {
            self.lines = lines
            self.minContentColumnWidth = minContentColumnWidth
            self.contentPadding = contentPadding
        }

        deinit { NotificationCenter.default.removeObserver(self) }

        func setupScrollSync() {
            guard let leftClip = leftScrollView?.contentView,
                  let centerClip = centerScrollView?.contentView,
                  let rightClip = rightScrollView?.contentView else { return }

            leftClip.postsBoundsChangedNotifications = true
            centerClip.postsBoundsChangedNotifications = true
            rightClip.postsBoundsChangedNotifications = true

            NotificationCenter.default.addObserver(self, selector: #selector(syncScroll(_:)),
                                                   name: NSView.boundsDidChangeNotification, object: leftClip)
            NotificationCenter.default.addObserver(self, selector: #selector(syncScroll(_:)),
                                                   name: NSView.boundsDidChangeNotification, object: centerClip)
            NotificationCenter.default.addObserver(self, selector: #selector(syncScroll(_:)),
                                                   name: NSView.boundsDidChangeNotification, object: rightClip)
        }

        @objc func syncScroll(_ notification: Notification) {
            guard !isSyncing, let changedClip = notification.object as? NSClipView else { return }
            isSyncing = true
            defer { isSyncing = false }

            let newOrigin = changedClip.bounds.origin
            let isLeftOrRight = changedClip === leftScrollView?.contentView || changedClip === rightScrollView?.contentView

            // Sync vertical position to all panels
            for scrollView in [leftScrollView, centerScrollView, rightScrollView] {
                guard let clip = scrollView?.contentView, clip !== changedClip else { continue }
                var origin = clip.bounds.origin
                origin.y = newOrigin.y

                // Sync horizontal only between left and right
                if isLeftOrRight && (scrollView === leftScrollView || scrollView === rightScrollView) {
                    origin.x = newOrigin.x
                }

                clip.setBoundsOrigin(origin)
            }
        }

        func updateColumnWidths() {
            let leftMaxWidth = maxContentWidth(for: lines.compactMap { $0.leftContent })
            let rightMaxWidth = maxContentWidth(for: lines.compactMap { $0.rightContent })

            // Use max of both sides so they scroll together properly
            let maxWidth = max(leftMaxWidth, rightMaxWidth, minContentColumnWidth)

            leftTable?.tableColumns.first?.width = maxWidth
            rightTable?.tableColumns.first?.width = maxWidth
        }

        private func maxContentWidth(for contents: [String]) -> CGFloat {
            guard !contents.isEmpty else { return minContentColumnWidth }

            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            var maxWidth: CGFloat = 0

            for content in contents {
                let size = (content as NSString).size(withAttributes: attributes)
                maxWidth = max(maxWidth, size.width + contentPadding)
            }
            return maxWidth
        }

        func numberOfRows(in tableView: NSTableView) -> Int { lines.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < lines.count else { return nil }
            let line = lines[row]

            switch tableView.tag {
            case 0: // Left content
                let content = line.leftContent ?? ""
                let bg = contentBackground(line.type, isLeft: true)
                let fg = textColor(line.type, isLeft: true)

                if line.type == .modified && !line.leftChangedRanges.isEmpty {
                    return makeCell(attributedText: highlightedString(content, ranges: line.leftChangedRanges,
                                    fg: fg, highlight: DiffColors.deletedHighlight), bg: bg)
                }
                return makeCell(text: content, bg: bg, fg: fg)

            case 1: // Line numbers
                let leftNum = line.leftLineNumber.map(String.init) ?? ""
                let rightNum = line.rightLineNumber.map(String.init) ?? ""
                return makeCell(text: String(format: "%4s │ %-4s", (leftNum as NSString).utf8String ?? "",
                                             (rightNum as NSString).utf8String ?? ""),
                                bg: lineNumBackground(line.type), fg: .tertiaryLabelColor, center: true)

            case 2: // Right content
                let content = line.rightContent ?? ""
                let bg = contentBackground(line.type, isLeft: false)
                let fg = textColor(line.type, isLeft: false)

                if line.type == .modified && !line.rightChangedRanges.isEmpty {
                    return makeCell(attributedText: highlightedString(content, ranges: line.rightChangedRanges,
                                    fg: fg, highlight: DiffColors.addedHighlight), bg: bg)
                }
                return makeCell(text: content, bg: bg, fg: fg)

            default:
                return nil
            }
        }

        private func makeCell(text: String = "", bg: NSColor, fg: NSColor = .labelColor, center: Bool = false) -> NSTextField {
            let cell = NSTextField(labelWithString: text)
            cell.font = font
            cell.lineBreakMode = .byClipping
            cell.drawsBackground = true
            cell.backgroundColor = bg
            cell.textColor = fg
            if center { cell.alignment = .center }
            return cell
        }

        private func makeCell(attributedText: NSAttributedString, bg: NSColor) -> NSTextField {
            let cell = NSTextField(labelWithString: "")
            cell.font = font
            cell.lineBreakMode = .byClipping
            cell.drawsBackground = true
            cell.backgroundColor = bg
            cell.attributedStringValue = attributedText
            return cell
        }

        private func highlightedString(_ text: String, ranges: [Range<String.Index>], fg: NSColor, highlight: NSColor) -> NSAttributedString {
            let attr = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: fg])
            for range in ranges {
                attr.addAttribute(.backgroundColor, value: highlight, range: NSRange(range, in: text))
            }
            return attr
        }

        private func lineNumBackground(_ type: DiffLineType) -> NSColor {
            switch type {
            case .deleted: return DiffColors.deletedLineNumBackground
            case .added: return DiffColors.addedLineNumBackground
            case .modified: return DiffColors.modifiedLineNumBackground
            case .unchanged: return DiffColors.unchangedLineNumBackground
            }
        }

        private func contentBackground(_ type: DiffLineType, isLeft: Bool) -> NSColor {
            switch type {
            case .deleted: return isLeft ? DiffColors.deletedBackground : .windowBackgroundColor
            case .added: return isLeft ? .windowBackgroundColor : DiffColors.addedBackground
            case .modified: return DiffColors.modifiedBackground
            case .unchanged: return DiffColors.unchangedBackground
            }
        }

        private func textColor(_ type: DiffLineType, isLeft: Bool) -> NSColor {
            switch type {
            case .deleted: return isLeft ? .labelColor : .tertiaryLabelColor
            case .added: return isLeft ? .tertiaryLabelColor : .labelColor
            case .modified, .unchanged: return .labelColor
            }
        }
    }
}

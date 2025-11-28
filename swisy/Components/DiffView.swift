/*
 DiffView.swift
 Shared diff components: models, algorithm, and table view.
 Used by TextDiffTool and JSONDiffTool.
 */

import AppKit
import SwiftUI

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

// MARK: - Diff Algorithm (Myers)

enum TextDiffer {
    private static let similarityThreshold: Double = 0.5

    static func diff(left: String, right: String) -> [DiffLine] {
        let leftLines = left.components(separatedBy: .newlines)
        let rightLines = right.components(separatedBy: .newlines)

        guard !(leftLines == [""] && rightLines == [""]) else { return [] }

        let difference = rightLines.difference(from: leftLines)
        var removedIndices = Set<Int>()
        var insertedIndices = Set<Int>()

        for change in difference {
            switch change {
            case .remove(let offset, _, _): removedIndices.insert(offset)
            case .insert(let offset, _, _): insertedIndices.insert(offset)
            }
        }

        var result: [DiffLine] = []
        var leftIdx = 0, rightIdx = 0, leftNum = 1, rightNum = 1

        while leftIdx < leftLines.count || rightIdx < rightLines.count {
            let isRemoved = removedIndices.contains(leftIdx) && leftIdx < leftLines.count
            let isInserted = insertedIndices.contains(rightIdx) && rightIdx < rightLines.count

            if isRemoved && isInserted {
                let leftLine = leftLines[leftIdx]
                let rightLine = rightLines[rightIdx]

                if similarity(leftLine, rightLine) >= similarityThreshold {
                    let charDiff = characterDiff(left: leftLine, right: rightLine)
                    result.append(DiffLine(leftLineNumber: leftNum, rightLineNumber: rightNum,
                                           leftContent: leftLine, rightContent: rightLine, type: .modified,
                                           leftChangedRanges: charDiff.left, rightChangedRanges: charDiff.right))
                    leftIdx += 1; rightIdx += 1; leftNum += 1; rightNum += 1
                } else {
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

    private static func similarity(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty || !b.isEmpty else { return 1.0 }
        guard !a.isEmpty && !b.isEmpty else { return 0.0 }
        let distance = levenshteinDistance(Array(a), Array(b))
        return 1.0 - (Double(distance) / Double(max(a.count, b.count)))
    }

    private static func levenshteinDistance<T: Equatable>(_ a: [T], _ b: [T]) -> Int {
        let m = a.count, n = b.count
        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                curr[j] = a[i - 1] == b[j - 1] ? prev[j - 1] : 1 + min(prev[j], curr[j - 1], prev[j - 1])
            }
            swap(&prev, &curr)
        }
        return prev[n]
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
            if i == end + 1 { end = i }
            else {
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

// MARK: - Diff Table View

struct DiffTableView: NSViewRepresentable {
    let lines: [DiffLine]

    private let lineNumberColumnWidth: CGFloat = 70
    private let minContentColumnWidth: CGFloat = 200
    private let rowHeight: CGFloat = 20

    func makeNSView(context: Context) -> NSView {
        let container = NSView()

        let leftScrollView = createScrollView(hasHorizontalScroller: true)
        let centerScrollView = createScrollView(hasHorizontalScroller: false)
        let rightScrollView = createScrollView(hasHorizontalScroller: true, hasVerticalScroller: true)

        let leftTable = createTableView()
        let centerTable = createTableView()
        let rightTable = createTableView()

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

        context.coordinator.leftTable = leftTable
        context.coordinator.centerTable = centerTable
        context.coordinator.rightTable = rightTable
        context.coordinator.leftScrollView = leftScrollView
        context.coordinator.centerScrollView = centerScrollView
        context.coordinator.rightScrollView = rightScrollView
        context.coordinator.lines = lines

        for table in [leftTable, centerTable, rightTable] {
            table.delegate = context.coordinator
            table.dataSource = context.coordinator
        }

        leftTable.tag = 0
        centerTable.tag = 1
        rightTable.tag = 2

        container.addSubview(leftScrollView)
        container.addSubview(centerScrollView)
        container.addSubview(rightScrollView)

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

        context.coordinator.setupScrollSync()
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

    func makeCoordinator() -> Coordinator { Coordinator(lines: lines) }

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

        init(lines: [DiffLine]) { self.lines = lines }
        deinit { NotificationCenter.default.removeObserver(self) }

        func setupScrollSync() {
            guard let leftClip = leftScrollView?.contentView,
                  let centerClip = centerScrollView?.contentView,
                  let rightClip = rightScrollView?.contentView else { return }

            for clip in [leftClip, centerClip, rightClip] {
                clip.postsBoundsChangedNotifications = true
                NotificationCenter.default.addObserver(self, selector: #selector(syncScroll(_:)),
                                                       name: NSView.boundsDidChangeNotification, object: clip)
            }
        }

        @objc func syncScroll(_ notification: Notification) {
            guard !isSyncing, let changedClip = notification.object as? NSClipView else { return }
            isSyncing = true
            defer { isSyncing = false }

            let newOrigin = changedClip.bounds.origin
            let isLeftOrRight = changedClip === leftScrollView?.contentView || changedClip === rightScrollView?.contentView

            for scrollView in [leftScrollView, centerScrollView, rightScrollView] {
                guard let clip = scrollView?.contentView, clip !== changedClip else { continue }
                var origin = clip.bounds.origin
                origin.y = newOrigin.y
                if isLeftOrRight && (scrollView === leftScrollView || scrollView === rightScrollView) {
                    origin.x = newOrigin.x
                }
                clip.setBoundsOrigin(origin)
            }
        }

        func updateColumnWidths() {
            let leftMax = maxContentWidth(for: lines.compactMap { $0.leftContent })
            let rightMax = maxContentWidth(for: lines.compactMap { $0.rightContent })
            let maxWidth = max(leftMax, rightMax, 200)
            leftTable?.tableColumns.first?.width = maxWidth
            rightTable?.tableColumns.first?.width = maxWidth
        }

        private func maxContentWidth(for contents: [String]) -> CGFloat {
            guard !contents.isEmpty else { return 200 }
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            return contents.map { ($0 as NSString).size(withAttributes: attrs).width + 20 }.max() ?? 200
        }

        func numberOfRows(in tableView: NSTableView) -> Int { lines.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < lines.count else { return nil }
            let line = lines[row]

            switch tableView.tag {
            case 0: // Left
                let content = line.leftContent ?? ""
                let bg = contentBg(line.type, isLeft: true)
                let fg = textColor(line.type, isLeft: true)
                if line.type == .modified && !line.leftChangedRanges.isEmpty {
                    return makeCell(highlighted: content, ranges: line.leftChangedRanges, fg: fg, highlight: DiffColors.deletedHighlight, bg: bg)
                }
                return makeCell(text: content, bg: bg, fg: fg)

            case 1: // Line numbers
                let l = line.leftLineNumber.map(String.init) ?? ""
                let r = line.rightLineNumber.map(String.init) ?? ""
                return makeCell(text: String(format: "%4s │ %-4s", (l as NSString).utf8String ?? "", (r as NSString).utf8String ?? ""),
                                bg: lineNumBg(line.type), fg: .tertiaryLabelColor, center: true)

            case 2: // Right
                let content = line.rightContent ?? ""
                let bg = contentBg(line.type, isLeft: false)
                let fg = textColor(line.type, isLeft: false)
                if line.type == .modified && !line.rightChangedRanges.isEmpty {
                    return makeCell(highlighted: content, ranges: line.rightChangedRanges, fg: fg, highlight: DiffColors.addedHighlight, bg: bg)
                }
                return makeCell(text: content, bg: bg, fg: fg)

            default: return nil
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

        private func makeCell(highlighted text: String, ranges: [Range<String.Index>], fg: NSColor, highlight: NSColor, bg: NSColor) -> NSTextField {
            let attr = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: fg])
            for range in ranges {
                attr.addAttribute(.backgroundColor, value: highlight, range: NSRange(range, in: text))
            }
            let cell = NSTextField(labelWithString: "")
            cell.font = font
            cell.lineBreakMode = .byClipping
            cell.drawsBackground = true
            cell.backgroundColor = bg
            cell.attributedStringValue = attr
            return cell
        }

        private func lineNumBg(_ type: DiffLineType) -> NSColor {
            switch type {
            case .deleted: return DiffColors.deletedLineNumBackground
            case .added: return DiffColors.addedLineNumBackground
            case .modified: return DiffColors.modifiedLineNumBackground
            case .unchanged: return DiffColors.unchangedLineNumBackground
            }
        }

        private func contentBg(_ type: DiffLineType, isLeft: Bool) -> NSColor {
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

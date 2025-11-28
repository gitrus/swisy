/*
 JSONDiffTool.swift
 Compare two JSON documents side-by-side with sorted keys.
 Uses custom parser to preserve number precision (avoids IEEE 754 float issues).
 */

import AppKit
import SwiftUI

// MARK: - Tool Registration

struct JSONDiffTool: Tool, Sendable {
    let id = "json-diff"
    let name = "JSON Diff"
    let icon = "curlybraces.square"
    let category: ToolCategory = .json

    func makeView() -> AnyView { AnyView(JSONDiffView()) }
    static func == (lhs: JSONDiffTool, rhs: JSONDiffTool) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - ViewModel

@MainActor
final class JSONDiffToolState: ObservableObject {
    @Published var leftJSON = ""
    @Published var rightJSON = ""
}

// MARK: - JSON Value (stores numbers as strings to preserve precision)

private indirect enum JSONValue {
    case null, bool(Bool), number(String), string(String)
    case array([JSONValue]), object([(String, JSONValue)])

    func format(_ indent: Int = 0) -> String {
        let pad = String(repeating: "  ", count: indent)
        let child = String(repeating: "  ", count: indent + 1)
        switch self {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .number(let n): return n
        case .string(let s): return "\"\(s.escaped)\""
        case .array(let arr):
            guard !arr.isEmpty else { return "[]" }
            return "[\n" + arr.map { "\(child)\($0.format(indent + 1))" }.joined(separator: ",\n") + "\n\(pad)]"
        case .object(let pairs):
            guard !pairs.isEmpty else { return "{}" }
            let sorted = pairs.sorted { $0.0 < $1.0 }
            return "{\n" + sorted.map { "\(child)\"\($0.0.escaped)\": \($0.1.format(indent + 1))" }.joined(separator: ",\n") + "\n\(pad)}"
        }
    }
}

private extension String {
    var escaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}

// MARK: - Minimal JSON Parser

private enum JSONParser {
    static func parse(_ s: String) -> JSONValue? {
        var i = s.startIndex
        skipWS(s, &i)
        guard let v = parseValue(s, &i) else { return nil }
        skipWS(s, &i)
        return i == s.endIndex ? v : nil
    }

    private static func skipWS(_ s: String, _ i: inout String.Index) {
        while i < s.endIndex && s[i].isWhitespace { i = s.index(after: i) }
    }

    private static func parseValue(_ s: String, _ i: inout String.Index) -> JSONValue? {
        skipWS(s, &i)
        guard i < s.endIndex else { return nil }
        switch s[i] {
        case "{": return parseObject(s, &i)
        case "[": return parseArray(s, &i)
        case "\"": return parseString(s, &i).map { .string($0) }
        case "t", "f": return parseBool(s, &i)
        case "n": return parseNull(s, &i)
        case "-", "0"..."9": return parseNumber(s, &i)
        default: return nil
        }
    }

    private static func parseObject(_ s: String, _ i: inout String.Index) -> JSONValue? {
        i = s.index(after: i)
        skipWS(s, &i)
        var pairs: [(String, JSONValue)] = []
        if i < s.endIndex && s[i] == "}" { i = s.index(after: i); return .object(pairs) }
        while true {
            skipWS(s, &i)
            guard let key = parseString(s, &i) else { return nil }
            skipWS(s, &i)
            guard i < s.endIndex && s[i] == ":" else { return nil }
            i = s.index(after: i)
            guard let val = parseValue(s, &i) else { return nil }
            pairs.append((key, val))
            skipWS(s, &i)
            guard i < s.endIndex else { return nil }
            if s[i] == "}" { i = s.index(after: i); return .object(pairs) }
            guard s[i] == "," else { return nil }
            i = s.index(after: i)
        }
    }

    private static func parseArray(_ s: String, _ i: inout String.Index) -> JSONValue? {
        i = s.index(after: i)
        skipWS(s, &i)
        var items: [JSONValue] = []
        if i < s.endIndex && s[i] == "]" { i = s.index(after: i); return .array(items) }
        while true {
            guard let val = parseValue(s, &i) else { return nil }
            items.append(val)
            skipWS(s, &i)
            guard i < s.endIndex else { return nil }
            if s[i] == "]" { i = s.index(after: i); return .array(items) }
            guard s[i] == "," else { return nil }
            i = s.index(after: i)
        }
    }

    private static func parseString(_ s: String, _ i: inout String.Index) -> String? {
        guard i < s.endIndex && s[i] == "\"" else { return nil }
        i = s.index(after: i)
        var result = ""
        while i < s.endIndex {
            let c = s[i]
            if c == "\"" { i = s.index(after: i); return result }
            if c == "\\" {
                i = s.index(after: i)
                guard i < s.endIndex else { return nil }
                switch s[i] {
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "/": result.append("/")
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                case "b": result.append("\u{08}")
                case "f": result.append("\u{0C}")
                case "u":
                    i = s.index(after: i)
                    guard let end = s.index(i, offsetBy: 4, limitedBy: s.endIndex),
                          let cp = UInt32(s[i..<end], radix: 16),
                          let sc = Unicode.Scalar(cp) else { return nil }
                    result.append(Character(sc))
                    i = end
                    continue
                default: return nil
                }
            } else {
                result.append(c)
            }
            i = s.index(after: i)
        }
        return nil
    }

    private static func parseNumber(_ s: String, _ i: inout String.Index) -> JSONValue? {
        let start = i
        if i < s.endIndex && s[i] == "-" { i = s.index(after: i) }
        guard i < s.endIndex && s[i].isNumber else { return nil }
        while i < s.endIndex && s[i].isNumber { i = s.index(after: i) }
        if i < s.endIndex && s[i] == "." {
            i = s.index(after: i)
            guard i < s.endIndex && s[i].isNumber else { return nil }
            while i < s.endIndex && s[i].isNumber { i = s.index(after: i) }
        }
        if i < s.endIndex && (s[i] == "e" || s[i] == "E") {
            i = s.index(after: i)
            if i < s.endIndex && (s[i] == "+" || s[i] == "-") { i = s.index(after: i) }
            guard i < s.endIndex && s[i].isNumber else { return nil }
            while i < s.endIndex && s[i].isNumber { i = s.index(after: i) }
        }
        return .number(String(s[start..<i]))
    }

    private static func parseBool(_ s: String, _ i: inout String.Index) -> JSONValue? {
        if s[i...].hasPrefix("true") { i = s.index(i, offsetBy: 4); return .bool(true) }
        if s[i...].hasPrefix("false") { i = s.index(i, offsetBy: 5); return .bool(false) }
        return nil
    }

    private static func parseNull(_ s: String, _ i: inout String.Index) -> JSONValue? {
        guard s[i...].hasPrefix("null") else { return nil }
        i = s.index(i, offsetBy: 4)
        return .null
    }
}

// MARK: - JSON Diff Logic

private enum JSONDiff {
    static func format(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return JSONParser.parse(trimmed)?.format()
    }

    static func compute(left: String, right: String) -> (lines: [DiffLine], stats: DiffStats)? {
        let l = left.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "{}" : left
        let r = right.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "{}" : right

        guard let lf = format(l), let rf = format(r) else { return nil }

        let lines = TextDiffer.diff(left: lf, right: rf)
        return (lines, TextDiffer.computeStats(from: lines))
    }
}

// MARK: - Main View

struct JSONDiffView: View {
    @ObservedObject private var state = ToolStateRegistry.shared.jsonDiff
    @State private var diffLines: [DiffLine] = []
    @State private var stats: DiffStats?
    @State private var hasError = false

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
        .navigationTitle("JSON Diff")
        .task(id: state.leftJSON + state.rightJSON) {
            try? await Task.sleep(for: .milliseconds(250))
            computeDiff()
        }
    }

    private var toolbar: some View {
        HStack {
            Text("JSON Diff").font(.headline)
            Spacer()
            Button("Swap", systemImage: "arrow.left.arrow.right") { swap(&state.leftJSON, &state.rightJSON) }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Button("Clear", systemImage: "trash") { state.leftJSON = ""; state.rightJSON = "" }
        }
        .padding()
    }

    private var inputPanels: some View {
        HSplitView {
            inputPanel(title: "Original (Left)", text: $state.leftJSON)
            inputPanel(title: "Modified (Right)", text: $state.rightJSON)
        }
        .frame(minHeight: 150, maxHeight: 250)
    }

    private func inputPanel(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                CharacterCountView(text: text.wrappedValue)
                Button(action: { if let p = ClipboardService.shared.paste() { text.wrappedValue = p } }) {
                    Label("Paste", systemImage: "doc.on.clipboard").labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
            }
            ResizablePlainTextEditor(text: text)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
        }
        .padding()
    }

    private var diffResultView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Diff (keys sorted)").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if let stats, stats.hasChanges {
                    Button(action: copyUnifiedDiff) { Label("Copy", systemImage: "doc.on.doc") }.buttonStyle(.borderless)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Group {
                if state.leftJSON.isEmpty && state.rightJSON.isEmpty {
                    placeholder(icon: "curlybraces.square", title: "Compare JSONs", desc: "Paste JSON in both panels")
                } else if hasError {
                    placeholder(icon: "exclamationmark.triangle", title: "Invalid JSON", desc: "Check your JSON syntax")
                } else if stats == nil {
                    VStack { ProgressView().padding(.top, 40); Spacer() }
                } else if !stats!.hasChanges {
                    placeholder(icon: "checkmark.circle", title: "Identical", desc: "No differences found")
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

    private func placeholder(icon: String, title: String, desc: String) -> some View {
        VStack { ContentUnavailableView { Label(title, systemImage: icon) } description: { Text(desc) }; Spacer() }
    }

    private var statusBar: some View {
        HStack {
            if let stats, stats.hasChanges {
                HStack(spacing: 16) {
                    if stats.additions > 0 { Label("\(stats.additions)", systemImage: "plus").foregroundStyle(.green) }
                    if stats.deletions > 0 { Label("\(stats.deletions)", systemImage: "minus").foregroundStyle(.red) }
                    if stats.modifications > 0 { Label("\(stats.modifications)", systemImage: "pencil").foregroundStyle(.orange) }
                }
                .font(.caption)
            }
            Spacer()
            Text("Keys sorted • Myers diff").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func computeDiff() {
        hasError = false; diffLines = []; stats = nil
        guard !state.leftJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
              !state.rightJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if let result = JSONDiff.compute(left: state.leftJSON, right: state.rightJSON) {
            diffLines = result.lines
            stats = result.stats
        } else {
            hasError = true
        }
    }

    private func copyUnifiedDiff() {
        var out = "--- original.json\n+++ modified.json\n"
        for line in diffLines {
            switch line.type {
            case .deleted: out += "-\(line.leftContent ?? "")\n"
            case .added: out += "+\(line.rightContent ?? "")\n"
            case .modified: out += "-\(line.leftContent ?? "")\n+\(line.rightContent ?? "")\n"
            case .unchanged: out += " \(line.leftContent ?? "")\n"
            }
        }
        ClipboardService.shared.copy(out)
    }
}

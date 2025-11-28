/*
 TextDiffTool.swift
 Side-by-side text diff comparator.
 */

import SwiftUI

// MARK: - Tool Registration

struct TextDiffTool: Tool, Sendable {
    let id = "text-diff"
    let name = "Text Diff"
    let icon = "arrow.left.arrow.right"
    let category: ToolCategory = .text

    func makeView() -> AnyView { AnyView(TextDiffView()) }
    static func == (lhs: TextDiffTool, rhs: TextDiffTool) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - ViewModel

@MainActor
final class TextDiffToolState: ObservableObject {
    @Published var leftText = ""
    @Published var rightText = ""
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
            Button("Swap", systemImage: "arrow.left.arrow.right") { swap(&state.leftText, &state.rightText) }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Button("Clear", systemImage: "trash") { state.leftText = ""; state.rightText = "" }
        }
        .padding()
    }

    private var inputPanels: some View {
        HSplitView {
            inputPanel(title: "Original (Left)", text: $state.leftText)
            inputPanel(title: "Modified (Right)", text: $state.rightText)
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
                Text("Diff Result").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if let stats, stats.hasChanges {
                    Button(action: copyUnifiedDiff) { Label("Copy", systemImage: "doc.on.doc") }.buttonStyle(.borderless)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Group {
                if diffLines.isEmpty && state.leftText.isEmpty && state.rightText.isEmpty {
                    placeholder(icon: "arrow.left.arrow.right", title: "Compare Texts", desc: "Paste text in both panels")
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
            Text("Myers diff algorithm").font(.caption2).foregroundStyle(.tertiary)
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
        var out = "--- original\n+++ modified\n"
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

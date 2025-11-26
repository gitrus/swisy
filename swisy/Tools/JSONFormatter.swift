import AppKit
import Highlight
import SwiftUI

// MARK: - Tool Registration

struct JSONFormatterTool: Tool, Sendable {
    let id = "json-formatter"
    let name = "JSON Formatter"
    let icon = "curlybraces"
    let category: ToolCategory = .json

    func makeView() -> AnyView {
        AnyView(JSONFormatterView())
    }

    static func == (lhs: JSONFormatterTool, rhs: JSONFormatterTool) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Models

enum JSONFormatterError: LocalizedError {
    case invalidJSON(String)
    case emptyInput

    var errorDescription: String? {
        switch self {
        case .invalidJSON(let details): "Invalid JSON: \(details)"
        case .emptyInput: "Please enter JSON to format"
        }
    }
}

struct JSONStats: Equatable {
    let lines: Int
    let chars: Int
}

// MARK: - ViewModel

@MainActor
final class JSONToolState: ObservableObject {
    @Published var input: String = ""
}

// MARK: - Formatter Logic

enum JSONFormatter {
    static func format(_ input: String) -> Result<NSAttributedString, any Error> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .failure(JSONFormatterError.emptyInput)
        }

        guard let data = trimmed.data(using: .utf8) else {
            return .failure(JSONFormatterError.invalidJSON("Could not convert to UTF-8"))
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            let formattedData = try JSONSerialization.data(
                withJSONObject: jsonObject,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            )

            guard let formattedString = String(data: formattedData, encoding: .utf8) else {
                return .failure(JSONFormatterError.invalidJSON("Could not convert to string"))
            }

            let attributed = NSMutableAttributedString(string: formattedString)
            JsonSyntaxHighlightProvider.shared.highlight(attributed, as: .json)
            return .success(attributed)
        } catch {
            return .failure(JSONFormatterError.invalidJSON(error.localizedDescription))
        }
    }

    static func minify(_ input: String) -> Result<String, any Error> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .failure(JSONFormatterError.emptyInput)
        }

        guard let data = trimmed.data(using: .utf8),
            let jsonObject = try? JSONSerialization.jsonObject(with: data),
            let minifiedData = try? JSONSerialization.data(withJSONObject: jsonObject),
            let minified = String(data: minifiedData, encoding: .utf8)
        else {
            return .failure(JSONFormatterError.invalidJSON("Could not minify JSON"))
        }

        return .success(minified)
    }
}

// MARK: - Highlighted Text View

struct HighlightedTextView: NSViewRepresentable {
    let attributedString: NSAttributedString
    let searchText: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView,
            let textStorage = textView.textStorage
        else { return }

        let highlighted = NSMutableAttributedString(attributedString: attributedString)
        applySearchHighlights(to: highlighted)
        textStorage.setAttributedString(highlighted)
    }

    private func applySearchHighlights(to text: NSMutableAttributedString) {
        guard !searchText.isEmpty else { return }

        let content = text.string
        var searchRange = content.startIndex..<content.endIndex

        while let range = content.range(
            of: searchText, options: .caseInsensitive, range: searchRange)
        {
            let nsRange = NSRange(range, in: content)
            text.addAttribute(
                .backgroundColor, value: NSColor.yellow.withAlphaComponent(0.5), range: nsRange)
            searchRange = range.upperBound..<content.endIndex
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            TextField("Search...", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - Main View

struct JSONFormatterView: View {
    @ObservedObject private var state = ToolStateRegistry.shared.json
    @State private var result: Result<NSAttributedString, any Error>?
    @State private var stats: JSONStats?
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var debouncedInput = ""
    @State private var showSearch = false
    @FocusState private var inputFocused: Bool
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .navigationTitle("JSON Formatter")
        .task { inputFocused = true }
        .task(id: state.input) {
            try? await Task.sleep(for: .milliseconds(150))
            formatJSON()
        }
        .task(id: searchText) {
            try? await Task.sleep(for: .milliseconds(100))
            debouncedSearchText = searchText
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("JSON Formatter")
                .font(.headline)

            Spacer()

            Button("Format", systemImage: "wand.and.stars", action: formatJSON)
                .keyboardShortcut("b", modifiers: .command)

            Button("Minify", systemImage: "minus.magnifyingglass", action: minifyJSON)

            Button("Paste", systemImage: "doc.on.clipboard", action: pasteFromClipboard)
                .keyboardShortcut("v", modifiers: [.command, .shift])

            Button("Find", systemImage: "magnifyingglass") {
                showSearch.toggle()
                if showSearch { searchFocused = true }
            }
            .keyboardShortcut("f", modifiers: .command)
        }
        .padding()
    }

    // MARK: - Content

    private var content: some View {
        HSplitView {
            inputPanel
            outputPanel
        }
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Input")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ResizablePlainTextEditor(text: $state.input)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        }
        .padding()
    }

    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            outputHeader

            if showSearch {
                SearchBar(text: $searchText, isFocused: $searchFocused) {
                    searchText = ""
                    debouncedSearchText = ""
                    showSearch = false
                }
            }

            outputContent
        }
        .padding()
    }

    private var outputHeader: some View {
        HStack {
            Text("Output")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if let stats {
                HStack(spacing: 12) {
                    Text("\(stats.lines) lines")
                    Text("\(stats.chars) chars")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)

                Button(action: copyOutput) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private var outputContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )

            switch result {
            case .success(let attributed):
                HighlightedTextView(attributedString: attributed, searchText: debouncedSearchText)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            case .failure(let error):
                JSONErrorView(error: error)
            case .none:
                JSONPlaceholderView()
            }
        }
    }

    // MARK: - Actions

    private func formatJSON() {
        let trimmed = state.input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            result = nil
            stats = nil
            return
        }

        result = JSONFormatter.format(trimmed)

        if case .success(let attributed) = result {
            let text = attributed.string
            stats = JSONStats(
                lines: text.components(separatedBy: .newlines).count,
                chars: text.count
            )
        } else {
            stats = nil
        }
    }

    private func minifyJSON() {
        guard case .success = result,
            case .success(let minified) = JSONFormatter.minify(state.input)
        else { return }
        state.input = minified
    }

    private func pasteFromClipboard() {
        if let text = ClipboardService.shared.paste() {
            state.input = text
        }
    }

    private func copyOutput() {
        if case .success(let attributed) = result {
            ClipboardService.shared.copy(attributed.string)
        }
    }
}

// MARK: - Supporting Views

struct JSONErrorView: View {
    let error: any Error

    var body: some View {
        ContentUnavailableView {
            Label("Invalid JSON", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        }
    }
}

struct JSONPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Paste JSON to format", systemImage: "curlybraces")
        } description: {
            Text("⌘⇧V to paste • Auto-formats as you type")
        }
    }
}

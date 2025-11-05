import SwiftUI
import AppKit
import Highlight

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
        case .invalidJSON(let details):
            return "Invalid JSON: \(details)"
        case .emptyInput:
            return "Please enter JSON to format"
        }
    }
}

// MARK: - ViewModel (Persisted State)
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

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            return .failure(JSONFormatterError.invalidJSON("Parse error: \(error.localizedDescription)"))
        }

        let formattedData: Data
        do {
            formattedData = try JSONSerialization.data(
                withJSONObject: jsonObject,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            )
        } catch {
            return .failure(JSONFormatterError.invalidJSON("Format error: \(error.localizedDescription)"))
        }

        guard let formattedString = String(data: formattedData, encoding: .utf8) else {
            return .failure(JSONFormatterError.invalidJSON("Could not convert formatted data to string"))
        }

        // Apply syntax highlighting
        let attributed = NSMutableAttributedString(string: formattedString)
        JsonSyntaxHighlightProvider.shared.highlight(attributed, as: .json)

        return .success(attributed)
    }

    static func minify(_ input: String) -> Result<String, any Error> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return .failure(JSONFormatterError.emptyInput)
        }

        guard let data = trimmed.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let minifiedData = try? JSONSerialization.data(withJSONObject: jsonObject),
              let minified = String(data: minifiedData, encoding: .utf8) else {
            return .failure(JSONFormatterError.invalidJSON("Could not minify JSON"))
        }

        return .success(minified)
    }
}

// MARK: - NSTextView Wrapper for Syntax Highlighting
struct HighlightedTextView: NSViewRepresentable {
    let attributedString: NSAttributedString

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 12, height: 12)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        textView.textStorage?.setAttributedString(attributedString)
    }
}

// MARK: - Main View
struct JSONFormatterView: View {
    @ObservedObject private var state = ToolStateRegistry.shared.json
    @State private var result: Result<NSAttributedString, any Error>?
    @State private var stats: (lines: Int, chars: Int)?
    @State private var formatTask: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("JSON Formatter")
                    .font(.headline)

                Spacer()

                Button(action: { formatJSON() }) {
                    Label("Format", systemImage: "wand.and.stars")
                }
                .keyboardShortcut("f", modifiers: [.command])

                Button(action: minifyJSON) {
                    Label("Minify", systemImage: "minus.magnifyingglass")
                }

                Button(action: pasteFromClipboard) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }
            .padding()

            Divider()

            HSplitView {
                // Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Input")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    PlainTextEditor(text: $state.input)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                        .onChange(of: state.input) { _, _ in
                            debouncedFormat()
                        }
                }
                .padding()

                // Output
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Output")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if let stats {
                            HStack(spacing: 12) {
                                Text("\(stats.lines) lines")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)

                                Text("\(stats.chars) chars")
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

                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .textBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            )

                        switch result {
                        case .success(let attributed):
                            HighlightedTextView(attributedString: attributed)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                        case .failure(let error):
                            JSONErrorView(error: error)

                        case .none:
                            JSONPlaceholderView()
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("JSON Formatter")
        .task {
            inputFocused = true
            // Format persisted input when view appears
            formatJSON()
        }
    }

    private func debouncedFormat() {
        // Cancel previous formatting task
        formatTask?.cancel()

        // Schedule new formatting task with 150ms delay
        formatTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms

            guard !Task.isCancelled else { return }

            await MainActor.run {
                formatJSON()
            }
        }
    }

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
            stats = (
                lines: text.components(separatedBy: .newlines).count,
                chars: text.count
            )
        } else {
            stats = nil
        }
    }

    private func minifyJSON() {
        guard case .success = result else { return }

        if case .success(let minified) = JSONFormatter.minify(state.input) {
            state.input = minified
        }
    }

    private func pasteFromClipboard() {
        if let text = ClipboardService.shared.paste() {
            state.input = text
        }
    }

    private func clearInput() {
        state.input = ""
        result = nil
        stats = nil
        inputFocused = true
    }

    private func copyOutput() {
        if case .success(let attributed) = result {
            ClipboardService.shared.copy(attributed.string)
        }
    }
}

struct JSONErrorView: View {
    let error: any Error

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Invalid JSON")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

struct JSONPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "curlybraces")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Paste JSON to format")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("⌘⇧V to paste • Auto-formats as you type")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

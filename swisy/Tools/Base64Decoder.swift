/*
 Base64Decoder.swift

 Complete Base64 encoder/decoder tool with ViewModel pattern for state persistence.
 Pattern: Tool struct → ViewModel (persisted) → Pure functions → Views

 Features:
 - Encode: Plain text → Base64
 - Decode: Base64 → Plain text
 - Mode toggle with cached inputs (persisted across tool switches)
 */

import SwiftUI
import Foundation

// MARK: - Tool Registration
struct Base64DecoderTool: Tool {
    let id = "base64-decoder"
    let name = "Base64 Encoder/Decoder"
    let icon = "number"
    let category: ToolCategory = .encoding

    func makeView() -> AnyView {
        AnyView(Base64DecoderView())
    }

    static func == (lhs: Base64DecoderTool, rhs: Base64DecoderTool) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Models
enum Base64Mode: Sendable {
    case encode
    case decode
}

enum Base64Error: LocalizedError, Sendable {
    case invalidBase64
    case invalidUTF8

    var errorDescription: String? {
        switch self {
        case .invalidBase64:
            return "Invalid Base64 encoding"
        case .invalidUTF8:
            return "Result is not valid UTF-8 text"
        }
    }
}

// MARK: - ViewModel (Persisted State)
@MainActor
final class Base64ToolState: ObservableObject {
    @Published var mode: Base64Mode = .decode
    @Published var encodeInput: String = ""
    @Published var decodeInput: String = ""

    /// Current input based on selected mode
    var currentInput: String {
        mode == .encode ? encodeInput : decodeInput
    }
}

// MARK: - Encoder/Decoder Logic (Pure Functions)
enum Base64Codec {
    static func encode(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else {
            return ""
        }
        return data.base64EncodedString()
    }

    static func decode(_ base64: String) -> Result<String, any Error> {
        // Clean up input - remove whitespace and newlines
        let cleaned = base64.filter { !$0.isWhitespace && !$0.isNewline }

        guard !cleaned.isEmpty else {
            return .failure(Base64Error.invalidBase64)
        }

        guard let data = Data(base64Encoded: cleaned) else {
            return .failure(Base64Error.invalidBase64)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            return .failure(Base64Error.invalidUTF8)
        }

        return .success(text)
    }
}

// MARK: - Main View
struct Base64DecoderView: View {
    @ObservedObject private var state = ToolStateRegistry.shared.base64

    @State private var output = ""
    @State private var error: (any Error)?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Mode Picker
            HStack {
                Picker("Mode", selection: $state.mode) {
                    Text("Decode").tag(Base64Mode.decode)
                    Text("Encode").tag(Base64Mode.encode)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .onChange(of: state.mode) { _, _ in
                    transformCurrentInput()
                }

                Spacer()
            }
            .padding()

            Divider()

            // Input section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(inputLabel)
                        .font(.headline)

                    Spacer()

                    CharacterCountView(text: state.currentInput)

                    Button(action: pasteFromClipboard) {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                }

                ResizableSmartTextEditor(text: currentInputBinding, maxLineLength: 120)
                    .frame(height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .onChange(of: state.encodeInput) { _, _ in transformCurrentInput() }
                    .onChange(of: state.decodeInput) { _, _ in transformCurrentInput() }
            }
            .padding()

            Divider()

            // Output section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(outputLabel)
                        .font(.headline)

                    Spacer()

                    if !output.isEmpty {
                        CharacterCountView(text: output)

                        Button(action: copyToClipboard) {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .keyboardShortcut("c", modifiers: [.command, .shift])
                    }
                }

                if let error = error {
                    Base64ErrorView(error: error)
                } else if output.isEmpty && state.currentInput.isEmpty {
                    Base64PlaceholderView(mode: state.mode)
                } else {
                    ScrollView {
                        Text(output)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 150)
                    .padding(12)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding()

            Spacer()
        }
        .navigationTitle("Base64 Encoder/Decoder")
        .task {
            // Use .task instead of .onAppear for async-safe initialization
            transformCurrentInput()
        }
        .onAppear {
            inputFocused = true
        }
    }

    // MARK: - Computed Properties & Bindings

    private var currentInputBinding: Binding<String> {
        Binding(
            get: {
                state.mode == .encode ? state.encodeInput : state.decodeInput
            },
            set: { newValue in
                if state.mode == .encode {
                    state.encodeInput = newValue
                } else {
                    state.decodeInput = newValue
                }
            }
        )
    }

    private var inputLabel: String {
        state.mode == .encode ? "Plain Text" : "Base64 Encoded"
    }

    private var outputLabel: String {
        state.mode == .encode ? "Base64 Encoded" : "Decoded Text"
    }

    // MARK: - Transform Logic

    private func transformCurrentInput() {
        let trimmed = state.currentInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            output = ""
            error = nil
            return
        }

        switch state.mode {
        case .encode:
            output = Base64Codec.encode(trimmed)
            error = nil

        case .decode:
            let result = Base64Codec.decode(trimmed)
            switch result {
            case .success(let decoded):
                output = decoded
                error = nil
            case .failure(let err):
                output = ""
                error = err
            }
        }
    }

    private func pasteFromClipboard() {
        if let text = ClipboardService.shared.paste() {
            if state.mode == .encode {
                state.encodeInput = text
            } else {
                state.decodeInput = text
            }
        }
    }

    private func copyToClipboard() {
        ClipboardService.shared.copy(output)
    }
}

// MARK: - Supporting Views
struct Base64ErrorView: View {
    let error: any Error

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Conversion Error")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(32)
    }
}

struct Base64PlaceholderView: View {
    let mode: Base64Mode

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "number")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(placeholderText)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("⌘⇧V to paste from clipboard")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(32)
    }

    private var placeholderText: String {
        mode == .encode
            ? "Enter text to encode"
            : "Paste Base64 text to decode"
    }
}

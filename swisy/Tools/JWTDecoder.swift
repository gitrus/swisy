/*
 JWTDecoder.swift

 Complete JWT decoder tool - registration, logic, and UI in one file.
 Pattern: Tool struct → Models → Pure functions → Views
 */

import SwiftUI
import Foundation

// MARK: - Tool Registration
struct JWTDecoderTool: Tool {
    let id = "jwt-decoder"
    let name = "JWT Decoder"
    let icon = "key.horizontal"
    let category: ToolCategory = .encoding

    func makeView() -> AnyView {
        AnyView(JWTDecoderView())
    }

    static func == (lhs: JWTDecoderTool, rhs: JWTDecoderTool) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Models
struct DecodedJWT {
    let header: String
    let payload: String
    let signature: String
    let isExpired: Bool
    let expiresAt: Date?
}

enum JWTError: LocalizedError {
    case invalidFormat
    case invalidBase64(part: String)
    case invalidJSON(part: String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "JWT must have 3 parts separated by dots (header.payload.signature)"
        case .invalidBase64(let part):
            return "Invalid Base64 encoding in \(part)"
        case .invalidJSON(let part):
            return "Invalid JSON in \(part)"
        }
    }
}

// MARK: - ViewModel (Persisted State)
@MainActor
final class JWTToolState: ObservableObject {
    @Published var input: String = ""
}

// MARK: - Decoder Logic (Pure Functions)
enum JWTDecoder {
    static func decode(_ token: String) -> Result<DecodedJWT, any Error> {
        let parts = token.components(separatedBy: ".")

        guard parts.count == 3 else {
            return .failure(JWTError.invalidFormat)
        }

        // Decode header
        guard let headerData = base64URLDecode(parts[0]),
              let headerJSON = try? JSONSerialization.jsonObject(with: headerData),
              let prettyHeader = try? JSONSerialization.data(withJSONObject: headerJSON, options: [.prettyPrinted, .sortedKeys]),
              let headerString = String(data: prettyHeader, encoding: .utf8) else {
            return .failure(JWTError.invalidBase64(part: "header"))
        }

        // Decode payload
        guard let payloadData = base64URLDecode(parts[1]),
              let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData),
              let prettyPayload = try? JSONSerialization.data(withJSONObject: payloadJSON, options: [.prettyPrinted, .sortedKeys]),
              let payloadString = String(data: prettyPayload, encoding: .utf8) else {
            return .failure(JWTError.invalidBase64(part: "payload"))
        }

        // Extract expiration
        var expiresAt: Date?
        var isExpired = false

        if let payload = payloadJSON as? [String: Any],
           let exp = payload["exp"] as? TimeInterval {
            expiresAt = Date(timeIntervalSince1970: exp)
            isExpired = expiresAt ?? Date.distantFuture < Date()
        }

        let jwt = DecodedJWT(
            header: headerString,
            payload: payloadString,
            signature: parts[2],
            isExpired: isExpired,
            expiresAt: expiresAt
        )

        return .success(jwt)
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        return Data(base64Encoded: base64)
    }
}

// MARK: - Main View
struct JWTDecoderView: View {
    @ObservedObject private var state = ToolStateRegistry.shared.jwt
    @State private var result: Result<DecodedJWT, any Error>?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Input section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Encoded JWT")
                        .font(.headline)
                    Spacer()
                    Button(action: pasteFromClipboard) {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                }

                TextEditor(text: $state.input)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 120)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .focused($inputFocused)
                    .onChange(of: state.input) { _, newValue in
                        decode(newValue)
                    }
            }
            .padding()

            Divider()

            // Output sections
            ScrollView {
                VStack(spacing: 16) {
                    switch result {
                    case .success(let jwt):
                        DecodedSection(
                            title: "Header",
                            content: jwt.header,
                            color: .red
                        )

                        DecodedSection(
                            title: "Payload",
                            content: jwt.payload,
                            color: .purple,
                            warning: jwt.isExpired ? "Token expired" : nil,
                            expiresAt: jwt.expiresAt
                        )

                        DecodedSection(
                            title: "Signature",
                            content: jwt.signature,
                            color: .blue
                        )

                    case .failure(let error):
                        ErrorView(error: error)

                    case .none:
                        PlaceholderView()
                    }
                }
                .padding()
            }
        }
        .navigationTitle("JWT Decoder")
        .task {
            // Decode persisted input when view appears
            decode(state.input)
        }
        .onAppear {
            inputFocused = true
        }
    }

    private func decode(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            result = nil
            return
        }

        result = JWTDecoder.decode(trimmed)
    }

    private func pasteFromClipboard() {
        if let text = ClipboardService.shared.paste() {
            state.input = text
        }
    }
}

// MARK: - Supporting Views
struct DecodedSection: View {
    let title: String
    let content: String
    let color: Color
    var warning: String? = nil
    var expiresAt: Date? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: "circle.fill")
                    .font(.headline)
                    .foregroundStyle(color)

                Spacer()

                if let warning {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let exp = expiresAt {
                    Text("Expires: \(exp, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(action: { ClipboardService.shared.copy(content) }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
            }

            Text(content)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct ErrorView: View {
    let error: any Error

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Invalid JWT")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.horizontal")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Paste a JWT token to decode")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("⌘⇧V to paste from clipboard")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

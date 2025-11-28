/*
 ToolStateRegistry.swift

 Singleton registry for tool ViewModels (state that persists across view recreation).

 ## Architecture Pattern

 ```
 User switches tools → View destroyed → @State lost ❌

 Solution:
 ToolStateRegistry (singleton)
    └── ViewModels (persisted)
           └── Views (@ObservedObject) ✅
 ```

 ## Why This Works

 1. Registry is a singleton (lives forever)
 2. ViewModels stored in registry (survive view destruction)
 3. Views observe ViewModels via @ObservedObject (not @StateObject)
 4. When view recreates, it reconnects to SAME ViewModel

 ## Usage in Tools

 ```swift
 // 1. Define ViewModel
 @MainActor
 final class Base64ToolState: ObservableObject {
     @Published var input = ""
     @Published var mode: Base64Mode = .decode
 }

 // 2. Register extension (type-safe accessor)
 extension ToolStateRegistry {
     var base64: Base64ToolState {
         state(for: "base64-decoder") { Base64ToolState() }
     }
 }

 // 3. Use in view (NOT @StateObject!)
 struct Base64DecoderView: View {
     @ObservedObject private var state = ToolStateRegistry.shared.base64

     var body: some View {
         TextEditor(text: $state.input)
     }
 }
 ```

 ## Key Difference

 ❌ @StateObject - Creates NEW instance (lost on recreation)
 ✅ @ObservedObject - Observes EXISTING instance (persisted)

 */

import SwiftUI

@MainActor
final class ToolStateRegistry {
    static let shared = ToolStateRegistry()
    private init() {}

    // Store ViewModels by tool ID
    private var viewModels: [String: any ObservableObject] = [:]

    /// Get or create a tool ViewModel
    /// - Parameters:
    ///   - toolId: Unique tool identifier
    ///   - factory: Closure to create ViewModel if it doesn't exist
    /// - Returns: The ViewModel instance (existing or newly created)
    func state<T: ObservableObject>(for toolId: String, factory: () -> T) -> T {
        if let existing = viewModels[toolId] as? T {
            return existing
        }

        let newState = factory()
        viewModels[toolId] = newState
        return newState
    }

    /// Clear state for a specific tool (useful for "reset" functionality)
    func clear(toolId: String) {
        viewModels.removeValue(forKey: toolId)
    }

    /// Clear all tool states (useful for app reset/logout)
    func clearAll() {
        viewModels.removeAll()
    }
}

// MARK: - Type-Safe Accessors

extension ToolStateRegistry {
    var base64: Base64ToolState {
        state(for: "base64-decoder") { Base64ToolState() }
    }

    var jwt: JWTToolState {
        state(for: "jwt-decoder") { JWTToolState() }
    }

    var json: JSONToolState {
        state(for: "json-formatter") { JSONToolState() }
    }

    var jsonDiff: JSONDiffToolState {
        state(for: "json-diff") { JSONDiffToolState() }
    }

    var textDiff: TextDiffToolState {
        state(for: "text-diff") { TextDiffToolState() }
    }
}

/*
 ToolRegistry.swift

 Central registry for all tools. Singleton pattern is correct here:
 - One app process
 - One window
 - One tool list
 - Thread-safe with Swift 6 concurrency

 ## Usage

 ```swift
 // Get all categories
 let categories = ToolRegistry.shared.categories

 // Get tools in category
 let encodingTools = ToolRegistry.shared.tools(in: .encoding)

 // Get specific tool
 if let tool = ToolRegistry.shared.tool(withId: "jwt-decoder") {
     tool.makeView()
 }
 ```

 ## Adding Tools

 Add to the tools array:
 ```swift
 private(set) var tools: [any Tool] = [
     JWTDecoderTool(),
     Base64Tool(),      // Add new tools here
     YourNewTool()
 ]
 ```
 */

import Foundation

@MainActor
final class ToolRegistry {
    static let shared = ToolRegistry()
    private init() {}

    private(set) var tools: [any Tool] = [
        JWTDecoderTool(),
        Base64DecoderTool(),
        JSONFormatterTool(),
        JSONDiffTool(),
        TextDiffTool()
    ]

    var categories: [ToolCategory] {
        Array(Set(tools.map(\.category))).sorted { $0.rawValue < $1.rawValue }
    }

    func tools(in category: ToolCategory) -> [any Tool] {
        tools.filter { $0.category == category }
    }

    func tool(withId id: String) -> (any Tool)? {
        tools.first { $0.id == id }
    }
}

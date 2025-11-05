/*
 Tool.swift
 
 Core protocol and categories for all developer tools.
 Swift 6 compliant with Sendable conformance.
 
 ## Adding a New Tool
 
 1. Create a struct conforming to Tool:
 
 ```swift
 struct MyTool: Tool, Sendable {
     let id = "my-tool"              // Unique identifier
     let name = "My Tool"            // Display name
     let icon = "star"               // SF Symbol name
     let category = ToolCategory.text
     
     func makeView() -> AnyView {
         AnyView(MyToolView())
     }
     
     // Required for Hashable/Equatable
     static func == (lhs: MyTool, rhs: MyTool) -> Bool { lhs.id == rhs.id }
     func hash(into hasher: inout Hasher) { hasher.combine(id) }
 }
 ```
 
 2. Register in ToolRegistry.shared.tools array
 
 ## Common SF Symbols
 - key.horizontal - Auth, JWT
 - number - Encoding, Base64
 - link - URL tools
 - curlybraces - JSON
 - doc.text - Text tools
 - function - Formatters
 */

import SwiftUI

protocol Tool: Identifiable, Hashable, Sendable {
    var id: String { get }
    var name: String { get }
    var icon: String { get }
    var category: ToolCategory { get }
    
    @ViewBuilder
    @MainActor
    func makeView() -> AnyView
}

enum ToolCategory: String, CaseIterable, Identifiable, Sendable {
    case encoding = "Encoding"
    case json = "JSON"
    case text = "Text"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .encoding: return "lock.shield"
        case .json: return "curlybraces"
        case .text: return "doc.text"
        }
    }
}

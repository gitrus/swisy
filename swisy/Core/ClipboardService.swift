/*
 ClipboardService.swift
 
 System clipboard operations. Singleton wraps NSPasteboard.
 Thread-safe with @MainActor for Swift 6.
 
 ## Usage
 
 ```swift
 // Copy to clipboard
 ClipboardService.shared.copy("text to copy")
 
 // Paste from clipboard
 if let text = ClipboardService.shared.paste() {
     input = text
 }
 
 // With keyboard shortcut
 Button(action: {
     if let text = ClipboardService.shared.paste() {
         input = text
     }
 }) {
     Label("Paste", systemImage: "doc.on.clipboard")
 }
 .keyboardShortcut("v", modifiers: [.command, .shift])
 ```
 */

import AppKit

@MainActor
final class ClipboardService {
    static let shared = ClipboardService()
    private init() {}
    
    func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
    
    func paste() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}

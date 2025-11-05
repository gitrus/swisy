/*
 AppState.swift
 
 Global application state and window restoration.
 Singleton pattern - one window, one state.
 Swift 6 @MainActor for thread safety.
 
 ## Usage
 
 ```swift
 // In your view
 @StateObject private var appState = AppState.shared
 
 // Access selected tool
 if let toolId = appState.selectedToolId {
     // Show tool
 }
 
 // Restore on launch
 .onAppear {
     appState.restoreState()
 }
 
 // Save on change
 .onChange(of: appState.selectedToolId) { _, _ in
     appState.saveState()
 }
 ```
 */

import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    private init() {}
    
    @Published var selectedToolId: String?
    @Published var sidebarVisible = true
    
    // Window restoration
    func saveState() {
        UserDefaults.standard.set(selectedToolId, forKey: "selectedTool")
    }
    
    func restoreState() {
        selectedToolId = UserDefaults.standard.string(forKey: "selectedTool")
    }
}

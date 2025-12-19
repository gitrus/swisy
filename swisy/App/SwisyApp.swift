import SwiftUI
import AppKit

@main
struct SwisyApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Tools") {
                Button("Search Tools...") {
                    // Handled by searchable in MainWindow
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
        .defaultSize(width: 1200, height: 800)
    }
}

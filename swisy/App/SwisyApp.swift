import SwiftUI
import AppKit

@main
struct SwisyApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)

        // Create custom icon from SF Symbol
        if let hammerImage = NSImage(systemSymbolName: "hammer.fill", accessibilityDescription: nil) {
            let size = NSSize(width: 512, height: 512)
            let finalImage = NSImage(size: size)

            finalImage.lockFocus()
            // Draw with white color
            NSColor.white.set()
            hammerImage.draw(in: NSRect(origin: .zero, size: size))
            finalImage.unlockFocus()

            NSApplication.shared.applicationIconImage = finalImage
        }
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

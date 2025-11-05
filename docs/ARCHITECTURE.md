# Swisy Architecture

Clean architecture for macOS developer tools. No over-engineering.

## Design Philosophy

**4 Singletons (and only 4):**
- `ToolRegistry` - Central tool registration
- `ClipboardService` - System clipboard operations
- `AppState` - Window state & restoration
- `ToolStateRegistry` - Tool ViewModels (state persistence)

**One file per tool.** Complete feature in <200 LOC.

## Directory Structure

```
swisy/
├── App/                    # Application Layer
│   ├── SwisyApp.swift     # @main entry, lifecycle, config
│   └── MainWindow.swift   # Root view, navigation
│
├── Core/                   # Business Logic (UI-agnostic)
│   ├── AppState.swift     # Singleton: State & persistence
│   ├── ClipboardService.swift  # Singleton: Clipboard wrapper
│   ├── Tool.swift         # Protocol: Tool contract
│   ├── ToolRegistry.swift # Singleton: Tool registry
│   └── ToolStateRegistry.swift # Singleton: ViewModel registry
│
├── Components/             # Reusable UI Components
│   └── PlainTextEditor.swift  # Text input (no smart quotes)
│
├── Tools/                  # Self-contained Features
│   ├── JSONFormatter.swift
│   └── JWTDecoder.swift
│
└── Resources/
    └── AppIcon.svg
```

## Layer Responsibilities

### App Layer
- **Purpose:** Application config, lifecycle, window management
- **Dependencies:** → Tools, Components, Core

### Core Layer
- **Purpose:** Business logic, protocols, services (no UI)
- **Dependencies:** → Foundation only
- **Rules:** Thread-safe (@MainActor), No UI imports

### Components Layer
- **Purpose:** Reusable UI building blocks
- **Dependencies:** → Core, SwiftUI/AppKit
- **Rules:** Generic, reusable, no business logic

### Tools Layer
- **Purpose:** Self-contained feature modules
- **Dependencies:** → Components, Core
- **Rules:** One file per tool, no cross-dependencies

## Dependency Flow

```
App → Tools → Components → Core
```

Lower layers never import upper layers.

## Key Patterns

### Pure Functions if possible

```swift
// ✅ Good
enum JSONFormatter {
    static func format(_ input: String) -> Result<String, Error>
}


### State Persistence Rules

**Use @ObservedObject for persisted state:**
```swift
// ✅ Correct - Observes existing ViewModel in registry
@ObservedObject private var state = ToolStateRegistry.shared.myTool
```

**Re-compute output on view appear:**
ViewModels persist INPUT, but OUTPUT must be re-computed when view reappears.
```swift
.task {
    transform()
}
```


## Adding a New Tool

1. Create `Tools/MyTool.swift`
2. Add ViewModel for state persistence
3. Register in `ToolRegistry.shared.tools`


## Guidelines

**Anti-patterns:**
- ❌ Nested directories
- ❌ Shared mutable state
- ❌ Cross-tool dependencies

**Offline-first:**
- ❌ No network calls
- ✅ All local processing

## FAQ

**Q: When to create a component?**
A: When 2+ tools need the same UI.

**Q: When to add a singleton?**
A: Almost never. Only for app-wide services.

**Q: How to share logic?**
A: For now: Extract to Core (logic) or Components (UI). But consider more advanced patterns as well.

# Swisy - macOS-only Developer Tools

Offline-first developer tools for macOS. Built with SwiftUI.
Build by claude code with human assistance.

## Architecture
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Design Principles

- **One file per tool** - Complete feature in <200 LOC
- **Pure functions first** - Transform data, don't manage state
- **Offline-first** - Zero network calls, ever
- **Native macOS** - Respect platform conventions


## Current Tools

- JWT Decoder
- Base64 Decoder/Encoder
- JSON formatter


## Requirements

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

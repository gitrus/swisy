# Swisy - macOS Developer Tools

![Swisy Icon](AppIcon.iconset/icon_128x128.png)

Offline-first developer tools for macOS. Built with SwiftUI.
Build by claude code with human assistance.

## Tools

| Tool | Description |
|------|-------------|
| **JWT Decoder** | Decode and inspect JWT tokens (header, payload, signature) |
| **Base64** | Encode/decode Base64 strings |
| **JSON Formatter** | Format and validate JSON with syntax highlighting |
| **JSON Diff** | Compare two JSON documents with sorted keys, Myers diff |
| **Text Diff** | Side-by-side text comparison, Myers diff |

## Design Principles

- **Offline-first** - Zero network calls, ever
- **One file per tool** - Complete feature in <200 LOC
- **Pure functions first** - Transform data, don't manage state
- **Native macOS** - Respect platform conventions

## Install

Download latest from [Releases](../../releases/latest), unzip, then:

```bash
xattr -cr Swisy.app   # remove quarantine (unsigned app)
open Swisy.app
```

## Requirements

- macOS 14.0+

## Dev requirements
- Swift 6.2+

## Keywords

macOS, developer tools, offline, SwiftUI, diff-tool, no-telemetry

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

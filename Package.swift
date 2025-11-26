// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swisy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "swisy", targets: ["swisy"])
    ],
    dependencies: [
        .package(url: "https://github.com/nkristek/Highlight.git", branch: "master"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.2")
    ],
    targets: [
        .executableTarget(
            name: "swisy",
            dependencies: [
                "Highlight",
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "swisy",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("StrictConcurrency"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

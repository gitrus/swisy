.PHONY: build run clean release help

help:
	@echo "Swisy Build Commands (Swift Package Manager):"
	@echo "  make build    - Build debug"
	@echo "  make run      - Build and launch app"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make release  - Build release (optimized)"
	@echo "  make xcode    - Generate Xcode project (optional)"

build:
	swift build

run: build
	swift run

clean:
	swift package clean
	rm -rf .build

release:
	swift build -c release

# Optional: generate Xcode project if you want to use Xcode later
xcode:
	swift package generate-xcodeproj
	@echo "Generated swisy.xcodeproj - open with: open swisy.xcodeproj"

import SwiftUI

struct MainWindow: View {
    @StateObject private var appState = AppState.shared
    @State private var searchText = ""
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    private let registry = ToolRegistry.shared

    var filteredCategories: [ToolCategory] {
        if searchText.isEmpty {
            return registry.categories
        }

        return registry.categories.filter { category in
            let tools = registry.tools(in: category)
            return tools.contains { tool in
                tool.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            VStack(spacing: 0) {
                // Search bar at top of sidebar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    TextField("Search tools", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // Tools list
                List(selection: $appState.selectedToolId) {
                    ForEach(filteredCategories) { category in
                        Section {
                            ForEach(filteredTools(in: category), id: \.id) { tool in
                                NavigationLink(value: tool.id) {
                                    Label(tool.name, systemImage: tool.icon)
                                }
                            }
                        } header: {
                            Label(category.rawValue, systemImage: category.icon)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .navigationTitle("Tools")
            .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            // Detail view
            if let toolId = appState.selectedToolId,
               let tool = registry.tool(withId: toolId) {
                tool.makeView()
            } else {
                EmptyStateView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            appState.restoreState()
        }
        .onChange(of: appState.selectedToolId) { _, _ in
            appState.saveState()
        }
    }

    private func filteredTools(in category: ToolCategory) -> [any Tool] {
        let tools = registry.tools(in: category)

        if searchText.isEmpty {
            return tools
        }

        return tools.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Select a tool to get started")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Choose from the sidebar or press ⌘K to search")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MainWindow()
        .frame(width: 900, height: 600)
}

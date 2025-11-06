import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    @State private var syncService: QuoteSyncService?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                QuoteEditorView()
                    .environmentObject(syncService ?? QuoteSyncService(modelContext: modelContext))
            }
            .tabItem {
                Label("Write", systemImage: "pencil")
            }
            .tag(0)
            
            NavigationStack {
                QuoteHistoryView()
                    .environmentObject(syncService ?? QuoteSyncService(modelContext: modelContext))
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .tag(1)
            
            NavigationStack {
                APIQuotesView()
            }
            .tabItem {
                Label("Discover", systemImage: "globe")
            }
            .tag(2)
            
            NavigationStack {
                AppView()
            }
            .tabItem {
                Label("Auth", systemImage: "lock")
            }
            .tag(3)
        }
        .onAppear {
            if syncService == nil {
                syncService = QuoteSyncService(modelContext: modelContext)
            }
        }
        .task {
            await syncService?.syncQuotesOnAppLaunch()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(SharedModelContainer.shared.container)
}

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                QuoteEditorView()
            }
            .tabItem {
                Label("Write", systemImage: "pencil")
            }
            .tag(0)
            
            NavigationStack {
                QuoteHistoryView()
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
    }
}

#Preview {
    ContentView()
        .modelContainer(SharedModelContainer.shared.container)
}

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
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(SharedModelContainer.shared.container)
}

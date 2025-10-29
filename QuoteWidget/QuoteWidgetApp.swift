import SwiftUI
import SwiftData

@main
struct QuoteWidgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(SharedModelContainer.shared.container)
    }
}

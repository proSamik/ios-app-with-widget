import SwiftUI
import SwiftData

@main
struct QuoteWidgetApp: App {
    init() {
        initializeRevenueCat()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(RevenueCatManager.shared)
        }
        .modelContainer(SharedModelContainer.shared.container)
    }
}

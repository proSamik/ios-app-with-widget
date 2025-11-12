import SwiftUI
import SwiftData

@main
struct QuoteWidgetApp: App {
    init() {
        initializeRevenueCat()
        // Initialize theme manager
        _ = ThemeManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(RevenueCatManager.shared)
                .environmentObject(ThemeManager.shared)
        }
        .modelContainer(SharedModelContainer.shared.container)
    }
}

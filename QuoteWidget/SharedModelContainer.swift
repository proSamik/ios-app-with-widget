import Foundation
import SwiftData

class SharedModelContainer {
    static let shared = SharedModelContainer()
    let container: ModelContainer
    
    private init() {
        let schema = Schema([Quote.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier("group.com.prosamik.QuoteWidget") // Use YOUR App Group
        )
        
        do {
            container = try ModelContainer(for: schema, configurations: modelConfiguration)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}

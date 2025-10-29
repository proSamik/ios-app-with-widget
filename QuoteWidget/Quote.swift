import Foundation
import SwiftData

@Model
final class Quote: Identifiable {
    @Attribute(.unique) var id: String
    var text: String
    var timestamp: Date
    
    init(id: String = UUID().uuidString, text: String, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }
}

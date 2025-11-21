import Foundation
import SwiftData

@Model
final class Quote: Identifiable {
    @Attribute(.unique) var id: String
    var text: String
    var timestamp: Date
    var isFavorite: Bool
    var author: String?
    var categories: [String]

    init(id: String = UUID().uuidString, text: String, timestamp: Date = Date(), isFavorite: Bool = false, author: String? = nil, categories: [String] = []) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.isFavorite = isFavorite
        self.author = author
        self.categories = categories
    }
}

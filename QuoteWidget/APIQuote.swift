import Foundation

struct APIQuote: Codable, Identifiable {
    let id = UUID()
    let quote: String
    let author: String
    let work: String
    let categories: [String]
    
    private enum CodingKeys: String, CodingKey {
        case quote, author, work, categories
    }
}

enum QuoteCategory: String, CaseIterable {
    case quoteOfTheDay = "Quote of the Day"
    case list = "List"

    var apiEndpoint: String {
        switch self {
        case .quoteOfTheDay:
            return "/api/quote/day"
        case .list:
            return "/api/quote/list"
        }
    }

    var displayName: String {
        return self.rawValue
    }
}
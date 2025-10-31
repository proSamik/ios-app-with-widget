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
    case success = "Success"
    case wisdom = "Wisdom"
    
    var apiEndpoint: String {
        switch self {
        case .quoteOfTheDay:
            return "/v2/quoteoftheday"
        case .success:
            return "/v2/quotes?categories=success&limit=10"
        case .wisdom:
            return "/v2/quotes?categories=wisdom&limit=10"
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}
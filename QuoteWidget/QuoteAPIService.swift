import Foundation
import SwiftUI
import Combine

@MainActor
class QuoteAPIService: ObservableObject {
    
    private let apiKey = "API_KEY"
    private let baseURL = "https://api.api-ninjas.com"
    
    @Published var quotes: [APIQuote] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastFetchedCategory: QuoteCategory?
    
    private let urlSession: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: config)
    }
    
    func fetchQuotes(for category: QuoteCategory) async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedQuotes = try await performNetworkRequest(for: category)
            
            quotes = fetchedQuotes
            lastFetchedCategory = category
            
        } catch {
            errorMessage = handleError(error)
            quotes = []
        }
        
        isLoading = false
    }
    
    private func performNetworkRequest(for category: QuoteCategory) async throws -> [APIQuote] {
        
        guard let url = URL(string: baseURL + category.apiEndpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        
        print("🌐 Making API request to: \(url.absoluteString)")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("📊 API Response Status: \(httpResponse.statusCode)")
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            let apiQuotes = try decoder.decode([APIQuote].self, from: data)
            
            print("✅ Successfully parsed \(apiQuotes.count) quotes")
            return apiQuotes
            
        } catch {
            print("❌ JSON Parsing Error: \(error)")
            throw APIError.decodingError(error)
        }
    }
    
    private func handleError(_ error: Error) -> String {
        switch error {
        case APIError.invalidURL:
            return "Invalid API URL"
        case APIError.invalidResponse:
            return "Invalid response from server"
        case APIError.serverError(let code):
            return "Server error: \(code)"
        case APIError.decodingError:
            return "Failed to parse quotes data"
        case URLError.notConnectedToInternet:
            return "No internet connection"
        case URLError.timedOut:
            return "Request timed out"
        default:
            return "Failed to fetch quotes: \(error.localizedDescription)"
        }
    }
    
    func clearData() {
        quotes = []
        errorMessage = nil
        lastFetchedCategory = nil
    }
}

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError(Error)
}

import Foundation
import SwiftUI
import Combine

@MainActor
class VideoAPIService: ObservableObject {

    private let baseURL = "https://quote-api-tau.vercel.app"
    private let videosEndpoint = "/api/quote/videos"

    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let urlSession: URLSession

    // Cache
    private static var cachedVideos: [Video]?
    private static var lastFetchTime: Date?
    private static let cacheExpirationInterval: TimeInterval = 300 // 5 minutes

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: config)
    }

    var isCacheValid: Bool {
        guard let lastFetch = Self.lastFetchTime else { return false }
        return Date().timeIntervalSince(lastFetch) < Self.cacheExpirationInterval
    }

    func fetchVideos(forceRefresh: Bool = false) async {
        guard !isLoading else { return }

        // Return cached data if valid and not forcing refresh
        if !forceRefresh, isCacheValid, let cached = Self.cachedVideos {
            videos = cached
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let fetchedVideos = try await performNetworkRequest()

            // Update cache
            Self.cachedVideos = fetchedVideos
            Self.lastFetchTime = Date()

            videos = fetchedVideos

        } catch {
            errorMessage = handleError(error)
            // Fall back to cache if available
            if let cached = Self.cachedVideos {
                videos = cached
            } else {
                videos = []
            }
        }

        isLoading = false
    }

    private func performNetworkRequest() async throws -> [Video] {
        guard let url = URL(string: baseURL + videosEndpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            let apiVideos = try decoder.decode([Video].self, from: data)
            // Shuffle the videos array to prevent repetitive order
            return apiVideos.shuffled()
        } catch {
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
            return "Failed to parse videos data"
        case URLError.notConnectedToInternet:
            return "No internet connection"
        case URLError.timedOut:
            return "Request timed out"
        default:
            return "Failed to fetch videos: \(error.localizedDescription)"
        }
    }

    func clearCache() {
        Self.cachedVideos = nil
        Self.lastFetchTime = nil
        videos = []
        errorMessage = nil
    }
}

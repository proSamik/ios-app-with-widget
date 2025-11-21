import Foundation
import SwiftData
import Supabase
import Combine

@MainActor
class QuoteSyncService: ObservableObject {
    @Published var isLoading = false
    @Published var lastSyncDate: Date?
    @Published var errorMessage: String?
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Sync Operations
    
    func syncQuotesOnAppLaunch() async {
        guard await isUserAuthenticated() else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // First, load from local database (immediate UI update)
            let localQuotes = await loadLocalQuotes()
            
            // Then sync with remote database
            let remoteQuotes = try await fetchRemoteQuotes()
            await syncQuotes(remote: remoteQuotes, local: localQuotes)
            
            lastSyncDate = Date()
        } catch {
            errorMessage = "Sync failed: \(error.localizedDescription)"
            print("Sync error: \(error)")
        }
        
        isLoading = false
    }
    
    func addQuote(_ text: String) async {
        guard await isUserAuthenticated() else { return }
        
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            // Create quote locally first (optimistic update)
            let localQuote = Quote(text: text)
            modelContext.insert(localQuote)
            try modelContext.save()
            
            // Then sync to remote
            let supabaseQuote = SupabaseQuote(
                id: UUID(uuidString: localQuote.id) ?? UUID(),
                userId: userId,
                text: text,
                timestamp: localQuote.timestamp
            )
            
            try await supabase
                .from("quotes")
                .insert(supabaseQuote)
                .execute()
                
        } catch {
            // If remote fails, we keep the local quote
            errorMessage = "Failed to sync quote: \(error.localizedDescription)"
            print("Add quote error: \(error)")
        }
    }
    
    func deleteQuote(_ quote: Quote) async {
        guard await isUserAuthenticated() else { return }
        
        do {
            // Delete locally first
            modelContext.delete(quote)
            try modelContext.save()
            
            // Then delete from remote
            try await supabase
                .from("quotes")
                .delete()
                .eq("id", value: quote.id)
                .execute()
                
        } catch {
            errorMessage = "Failed to delete quote: \(error.localizedDescription)"
            print("Delete quote error: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func isUserAuthenticated() async -> Bool {
        do {
            _ = try await supabase.auth.session
            return true
        } catch {
            return false
        }
    }
    
    private func loadLocalQuotes() async -> [Quote] {
        let descriptor = FetchDescriptor<Quote>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to load local quotes: \(error)")
            return []
        }
    }
    
    private func fetchRemoteQuotes() async throws -> [SupabaseQuote] {
        let session = try await supabase.auth.session
        let userId = session.user.id
        
        let response: [SupabaseQuote] = try await supabase
            .from("quotes")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("timestamp", ascending: false)
            .execute()
            .value
            
        return response
    }
    
    private func syncQuotes(remote: [SupabaseQuote], local: [Quote]) async {
        // Convert remote quotes to local format
        let remoteQuoteIds = Set(remote.map { $0.id.uuidString })
        let localQuoteIds = Set(local.map { $0.id })

        // Add remote quotes that don't exist locally
        for remoteQuote in remote {
            if !localQuoteIds.contains(remoteQuote.id.uuidString) {
                let localQuote = Quote(
                    id: remoteQuote.id.uuidString,
                    text: remoteQuote.text,
                    timestamp: remoteQuote.timestamp,
                    isFavorite: remoteQuote.isFavorite,
                    author: remoteQuote.author,
                    categories: remoteQuote.categories
                )
                modelContext.insert(localQuote)
            }
        }

        // Remove local quotes that don't exist remotely
        for localQuote in local {
            if !remoteQuoteIds.contains(localQuote.id) {
                modelContext.delete(localQuote)
            }
        }

        // Save changes
        do {
            try modelContext.save()
        } catch {
            print("Failed to save synced quotes: \(error)")
        }
    }

    func findExistingQuote(text: String, author: String) -> Quote? {
        let descriptor = FetchDescriptor<Quote>(
            predicate: #Predicate { quote in
                quote.text == text && quote.author == author && quote.isFavorite == true
            }
        )

        do {
            let results = try modelContext.fetch(descriptor)
            return results.first
        } catch {
            print("Failed to find existing quote: \(error)")
            return nil
        }
    }

    func addFavoriteQuote(text: String, author: String, categories: [String]) async {
        guard await isUserAuthenticated() else { return }

        do {
            let session = try await supabase.auth.session
            let userId = session.user.id

            // Create quote locally first (optimistic update)
            let localQuote = Quote(text: text, isFavorite: true, author: author, categories: categories)
            modelContext.insert(localQuote)
            try modelContext.save()

            // Then sync to remote
            let supabaseQuote = SupabaseQuote(
                id: UUID(uuidString: localQuote.id) ?? UUID(),
                userId: userId,
                text: text,
                timestamp: localQuote.timestamp,
                isFavorite: true,
                author: author,
                categories: categories
            )

            try await supabase
                .from("quotes")
                .insert(supabaseQuote)
                .execute()

        } catch {
            // If remote fails, we keep the local quote
            errorMessage = "Failed to sync favorite quote: \(error.localizedDescription)"
            print("Add favorite quote error: \(error)")
        }
    }

    func removeFavoriteQuote(_ quote: Quote) async {
        await deleteQuote(quote)
    }

    func updateQuoteAsCurrent(_ quote: Quote) async {
        guard await isUserAuthenticated() else { return }

        do {
            // Update timestamp to make it the most recent
            quote.timestamp = Date()
            try modelContext.save()

            // Update in remote
            try await supabase
                .from("quotes")
                .update(["timestamp": quote.timestamp])
                .eq("id", value: quote.id)
                .execute()

        } catch {
            errorMessage = "Failed to update quote: \(error.localizedDescription)"
            print("Update quote error: \(error)")
        }
    }
}

// MARK: - Supabase Quote Model

struct SupabaseQuote: Codable {
    let id: UUID
    let userId: UUID
    let text: String
    let timestamp: Date
    let isFavorite: Bool
    let author: String?
    let categories: [String]
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case text
        case timestamp
        case isFavorite = "is_favorite"
        case author
        case categories
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: UUID, userId: UUID, text: String, timestamp: Date, isFavorite: Bool = false, author: String? = nil, categories: [String] = []) {
        self.id = id
        self.userId = userId
        self.text = text
        self.timestamp = timestamp
        self.isFavorite = isFavorite
        self.author = author
        self.categories = categories
        self.createdAt = nil
        self.updatedAt = nil
    }
}
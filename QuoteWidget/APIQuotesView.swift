import SwiftUI
import SwiftData

struct APIQuotesView: View {
    @StateObject private var apiService = QuoteAPIService()
    @EnvironmentObject var syncService: QuoteSyncService
    @Query(sort: \Quote.timestamp, order: .reverse) private var quotes: [Quote]
    @State private var selectedCategory: QuoteCategory = .quoteOfTheDay
    @State private var selectedFilters: Set<String> = []

    var currentQuote: Quote? {
        quotes.first
    }

    let availableFilters = ["success", "business", "marketing", "wisdom", "character", "growth", "motivation", "action", "relationships", "sales", "management", "truth", "entrepreneurship"]
    
    var filteredQuotes: [APIQuote] {
        if selectedFilters.isEmpty {
            return apiService.quotes
        }
        return apiService.quotes.filter { quote in
            !Set(quote.categories).isDisjoint(with: selectedFilters)
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            categoryPicker

            Divider()
                .padding(.horizontal)

            if selectedCategory == .quoteOfTheDay {
                ScrollView {
                    VStack(spacing: 16) {
                        if apiService.isLoading {
                            loadingView
                        } else if let errorMessage = apiService.errorMessage {
                            errorView(message: errorMessage)
                        } else if apiService.quotes.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(apiService.quotes) { quote in
                                QuoteRowView(quote: quote, isQuoteOfTheDay: true, syncService: syncService)
                                    .padding(.horizontal)
                            }

                            Divider()
                                .padding()

                            // Current Quote for Widget
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Current Quote for Widget")
                                    .font(.headline)
                                    .padding(.horizontal)

                                if let currentQuote = currentQuote {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("\"\(currentQuote.text)\"")
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .italic()
                                            .foregroundColor(.primary)

                                        if let author = currentQuote.author {
                                            Text("— \(author)")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                } else {
                                    Text("No quote yet")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            } else {
                VStack(spacing: 0) {
                    if apiService.isLoading {
                        loadingView
                    } else if let errorMessage = apiService.errorMessage {
                        errorView(message: errorMessage)
                    } else if apiService.quotes.isEmpty {
                        emptyStateView
                    } else {
                        // Filter chips
                        filterChipsView

                        // Filtered quotes list
                        List(filteredQuotes) { quote in
                            QuoteRowView(quote: quote, isQuoteOfTheDay: false, syncService: syncService)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        .listStyle(.plain)
                        .background(Color(.systemBackground))
                    }
                }
            }
        }
        .navigationTitle("Alex Hormozi's Quote")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchInitialQuotes()
        }
        .refreshable {
            await apiService.fetchQuotes(for: selectedCategory)
        }
    }

    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableFilters, id: \.self) { filter in
                    Button(action: {
                        if selectedFilters.contains(filter) {
                            selectedFilters.remove(filter)
                        } else {
                            selectedFilters.insert(filter)
                        }
                    }) {
                        Text(filter.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(selectedFilters.contains(filter) ? .white : .blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedFilters.contains(filter) ? Color.blue : Color.blue.opacity(0.15))
                            )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var categoryPicker: some View {
        Picker("Quote Category", selection: $selectedCategory) {
            ForEach(QuoteCategory.allCases, id: \.self) { category in
                Text(category.displayName)
                    .tag(category)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedCategory) { _, newCategory in
            Task {
                await apiService.fetchQuotes(for: newCategory)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Fetching \(selectedCategory.displayName.lowercased()) quotes...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Oops! Something went wrong")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                Task {
                    await apiService.fetchQuotes(for: selectedCategory)
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "quote.bubble")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No quotes available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Try selecting a different category or refresh the page")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private func fetchInitialQuotes() async {
        await apiService.fetchQuotes(for: selectedCategory)
    }
}

struct QuoteRowView: View {
    let quote: APIQuote
    let isQuoteOfTheDay: Bool
    let syncService: QuoteSyncService
    @State private var shouldShowTypewriter: Bool = false
    @State private var isFavorited: Bool = false
    @State private var existingQuote: Quote?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    // Use typewriter effect only for Quote of the Day
                    if isQuoteOfTheDay && shouldShowTypewriter {
                        TypewriterView(text: "\"\(quote.quote)\"")
                            .font(.body)
                            .fontWeight(.medium)
                            .italic()
                            .lineLimit(nil)
                            .foregroundColor(.primary)
                    } else {
                        Text("\"\(quote.quote)\"")
                            .font(.body)
                            .fontWeight(.medium)
                            .italic()
                            .lineLimit(nil)
                            .foregroundColor(.primary)
                            .onAppear {
                                if isQuoteOfTheDay {
                                    shouldShowTypewriter = true
                                }
                            }
                    }

                    authorSection

                    if !quote.categories.isEmpty {
                        categoriesSection
                    }
                }

                // Favorite button
                Button(action: {
                    Task {
                        await toggleFavorite()
                    }
                }) {
                    Image(systemName: isFavorited ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundColor(isFavorited ? .yellow : .gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onAppear {
            checkIfFavorited()
        }
    }

    private func checkIfFavorited() {
        existingQuote = syncService.findExistingQuote(text: quote.quote, author: quote.author)
        isFavorited = existingQuote != nil
    }

    private func toggleFavorite() async {
        if let existingQuote = existingQuote {
            // Already favorited, remove it
            await syncService.removeFavoriteQuote(existingQuote)
            isFavorited = false
            self.existingQuote = nil
        } else {
            // Not favorited, add it
            await syncService.addFavoriteQuote(
                text: quote.quote,
                author: quote.author,
                categories: quote.categories
            )
            isFavorited = true
            // Update the existing quote reference
            existingQuote = syncService.findExistingQuote(text: quote.quote, author: quote.author)
        }
    }
    
    private var authorSection: some View {
        HStack {
            Text("— \(quote.author)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            if !quote.work.isEmpty {
                Text("(\(quote.work))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
    }
    
    private var categoriesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(quote.categories, id: \.self) { category in
                    Text(category.capitalized)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.15))
                        )
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

#Preview {
    NavigationStack {
        APIQuotesView()
    }
}
import SwiftUI

struct APIQuotesView: View {
    @StateObject private var apiService = QuoteAPIService()
    @State private var selectedCategory: QuoteCategory = .quoteOfTheDay
    
    var body: some View {
        VStack(spacing: 0) {
            
            categoryPicker
            
            Divider()
                .padding(.horizontal)
            
            if apiService.isLoading {
                loadingView
            } else if let errorMessage = apiService.errorMessage {
                errorView(message: errorMessage)
            } else if apiService.quotes.isEmpty {
                emptyStateView
            } else {
                quotesListView
            }
        }
        .navigationTitle("Discover Quotes")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await fetchInitialQuotes()
        }
        .refreshable {
            await apiService.fetchQuotes(for: selectedCategory)
        }
    }
    
    private var categoryPicker: some View {
        VStack(spacing: 12) {
            Text("Choose Category")
                .font(.headline)
                .foregroundColor(.primary)
            
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
    
    private var quotesListView: some View {
        List(apiService.quotes) { quote in
            QuoteRowView(quote: quote)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.plain)
        .background(Color(.systemBackground))
    }
    
    private func fetchInitialQuotes() async {
        await apiService.fetchQuotes(for: selectedCategory)
    }
}

struct QuoteRowView: View {
    let quote: APIQuote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text("\"\(quote.quote)\"")
                .font(.body)
                .fontWeight(.medium)
                .italic()
                .lineLimit(nil)
                .foregroundColor(.primary)
            
            authorSection
            
            if !quote.categories.isEmpty {
                categoriesSection
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
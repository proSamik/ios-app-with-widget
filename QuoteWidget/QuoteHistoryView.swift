import SwiftUI
import SwiftData
import WidgetKit

struct QuoteHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var syncService: QuoteSyncService
    @Query(sort: \Quote.timestamp, order: .reverse) private var quotes: [Quote]

    var favoriteQuotes: [Quote] {
        quotes.filter { $0.isFavorite }
    }

    var body: some View {
        List {
            if favoriteQuotes.isEmpty {
                ContentUnavailableView(
                    "No Favourites Yet",
                    systemImage: "star",
                    description: Text("Star quotes from Discover to see them here")
                )
            } else {
                ForEach(favoriteQuotes) { quote in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(quote.text)
                            .font(.body)

                        if let author = quote.author {
                            Text("— \(author)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(quote.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .leading) {
                        Button {
                            Task {
                                await setAsCurrentQuote(quote)
                            }
                        } label: {
                            Label("Set Current", systemImage: "star.circle.fill")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteQuote(quote)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Favourites")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Refresh") {
                    Task {
                        await syncService.syncQuotesOnAppLaunch()
                    }
                }
                .disabled(syncService.isLoading)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .overlay {
            if syncService.isLoading {
                VStack {
                    ProgressView("Syncing...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            }
        }
    }
    
    func deleteQuote(_ quote: Quote) {
        Task {
            await syncService.deleteQuote(quote)
        }
    }

    func setAsCurrentQuote(_ quote: Quote) async {
        await syncService.updateQuoteAsCurrent(quote)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

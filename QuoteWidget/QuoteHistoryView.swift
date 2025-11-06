import SwiftUI
import SwiftData

struct QuoteHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var syncService: QuoteSyncService
    @Query(sort: \Quote.timestamp, order: .reverse) private var quotes: [Quote]
    
    var body: some View {
        List {
            if quotes.isEmpty {
                ContentUnavailableView(
                    "No Quotes Yet",
                    systemImage: "quote.bubble",
                    description: Text("Start writing quotes to see them here")
                )
            } else {
                ForEach(quotes) { quote in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(quote.text)
                            .font(.body)
                        
                        Text(quote.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteQuotes)
            }
        }
        .navigationTitle("Quote History")
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
    
    func deleteQuotes(at offsets: IndexSet) {
        for index in offsets {
            let quote = quotes[index]
            Task {
                await syncService.deleteQuote(quote)
            }
        }
    }
}

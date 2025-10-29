import SwiftUI
import SwiftData

struct QuoteHistoryView: View {
    @Environment(\.modelContext) private var modelContext
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
            EditButton()
        }
    }
    
    func deleteQuotes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(quotes[index])
        }
    }
}

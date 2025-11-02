import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry
struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: Quote?
    let allQuotes: [Quote]
    let currentIndex: Int
}

// MARK: - Timeline Provider
struct QuoteProvider: @MainActor TimelineProvider {
    typealias Entry = QuoteEntry
    
    // Placeholder for widget gallery
    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(
            date: Date(),
            quote: Quote(text: "Your inspiring quote will appear here", timestamp: Date()),
            allQuotes: [],
            currentIndex: 0
        )
    }
    
    // Quick snapshot for widget preview
    @MainActor func getSnapshot(in context: Context, completion: @escaping (QuoteEntry) -> Void) {
        let entry = fetchCurrentEntry()
        completion(entry)
    }
    
    // Main timeline generation
    @MainActor func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteEntry>) -> Void) {
        let entry = fetchCurrentEntry()
        
        // Refresh widget every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    // Helper to fetch quotes from SwiftData
    @MainActor
    private func fetchCurrentEntry() -> QuoteEntry {
        let modelContext = SharedModelContainer.shared.container.mainContext
        
        let descriptor = FetchDescriptor<Quote>(
            sortBy: [SortDescriptor(\Quote.timestamp, order: .reverse)]
        )
        
        do {
            let quotes = try modelContext.fetch(descriptor)
            let currentQuote = quotes.first
            return QuoteEntry(
                date: Date(),
                quote: currentQuote,
                allQuotes: quotes,
                currentIndex: 0
            )
        } catch {
            print("Error fetching quotes: \(error)")
            return QuoteEntry(date: Date(), quote: nil, allQuotes: [], currentIndex: 0)
        }
    }
}

// MARK: - Widget View
struct QuoteWidgetView: View {
    let entry: QuoteEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Image(systemName: "quote.bubble.fill")
                    .foregroundColor(.blue)
                Text("Latest Quote")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Spacer()
            
            // Quote display - reusing our component!
            QuoteDisplayView(quote: entry.quote)
            
            Spacer()
            
            // Navigation info
            if !entry.allQuotes.isEmpty {
                HStack {
                    Spacer()
                    Text("Quote \(entry.currentIndex + 1) of \(entry.allQuotes.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Widget Configuration
struct QuoteWidget: Widget {
    let kind: String = "QuoteWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuoteProvider()) { entry in
            QuoteWidgetView(entry: entry)
        }
        .configurationDisplayName("Quote Widget")
        .description("Displays your latest saved quote")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle
@main
struct QuoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuoteWidget()
    }
}

// MARK: - Preview
#Preview(as: .systemMedium) {
    QuoteWidget()
} timeline: {
    QuoteEntry(
        date: Date(),
        quote: Quote(text: "The only way to do great work is to love what you do.", timestamp: Date()),
        allQuotes: [],
        currentIndex: 0
    )
}

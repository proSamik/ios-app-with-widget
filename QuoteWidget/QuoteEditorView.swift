import SwiftUI
import SwiftData
import WidgetKit

struct QuoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var syncService: QuoteSyncService
    @Query(sort: \Quote.timestamp, order: .reverse) private var quotes: [Quote]
    
    @State private var quoteText: String = ""
    @State private var showingSavedAlert = false
    
    var currentQuote: Quote? {
        quotes.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Display current quote
            Text("Current Quote")
                .font(.headline)
            
            QuoteDisplayView(quote: currentQuote)
            
            // Editor section
            Text("Write a New Quote")
                .font(.headline)
                .padding(.top)
            
            TextField("Enter your quote here...", text: $quoteText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(5...10)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            Button(action: saveQuote) {
                Text("Save Quote")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(quoteText.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(10)
            }
            .disabled(quoteText.isEmpty)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Write Quote")
        .alert("Saved!", isPresented: $showingSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your quote has been saved successfully.")
        }
    }
    
    func saveQuote() {
        guard !quoteText.isEmpty else { return }
        
        Task {
            await syncService.addQuote(quoteText)
            
            // Reload widget
            WidgetCenter.shared.reloadAllTimelines()
            
            await MainActor.run {
                quoteText = ""
                showingSavedAlert = true
            }
        }
    }

}

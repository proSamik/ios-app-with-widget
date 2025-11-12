import SwiftUI
import SwiftData
import WidgetKit
import StoreKit

struct QuoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject var syncService: QuoteSyncService
    @Query(sort: \Quote.timestamp, order: .reverse) private var quotes: [Quote]
    
    @State private var quoteText: String = ""
    @State private var showingSavedAlert = false
    @AppStorage("userQuoteCount") private var userQuoteCount: Int = 0
    @AppStorage("hasUserReviewedApp") private var hasUserReviewedApp: Bool = false
    @AppStorage("reviewPromptHistory") private var reviewPromptHistoryData: Data = Data()
    @AppStorage("lastReviewPromptTime") private var lastReviewPromptTime: Double = 0
    
    var currentQuote: Quote? {
        quotes.first
    }
    
    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
    
    private var reviewPromptHistory: Set<Int> {
        guard let history = try? JSONDecoder().decode(Set<Int>.self, from: reviewPromptHistoryData) else {
            return Set<Int>()
        }
        return history
    }
    
    private func updateReviewPromptHistory(_ newHistory: Set<Int>) {
        guard let data = try? JSONEncoder().encode(newHistory) else { return }
        reviewPromptHistoryData = data
    }
    
    private var nextReviewPromptCount: Int {
        let validPrompts = reviewPromptHistory.filter { $0 > 0 } // Exclude soft dismiss markers (-1)
        
        if validPrompts.isEmpty {
            return 4 // First prompt at 4th quote
        }
        
        let softDismissCount = reviewPromptHistory.filter { $0 == -1 }.count
        let lastPromptCount = validPrompts.max() ?? 0
        
        // Increase interval if user has soft dismissed before
        let interval = softDismissCount > 0 ? 4 : 2
        return lastPromptCount + interval
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
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            hideKeyboard()
                        }
                    }
                }
            
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
        .onTapGesture {
            hideKeyboard()
        }
        .alert("Saved!", isPresented: $showingSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your quote has been saved successfully.")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkForReviewCompletion()
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
                
                // Increment quote count and check for review prompt
                userQuoteCount += 1
                requestReviewIfAppropriate()
            }
        }
    }
    
    private func requestReviewIfAppropriate() {
        // Don't prompt if user has already reviewed the app
        guard !hasUserReviewedApp else { return }
        
        // Check if we should prompt at this quote count
        guard userQuoteCount >= nextReviewPromptCount,
              !reviewPromptHistory.contains(userQuoteCount)
        else { return }
        
        // Add this prompt count to history
        var history = reviewPromptHistory
        history.insert(userQuoteCount)
        updateReviewPromptHistory(history)
        
        // Add slight delay so prompt doesn't interrupt user experience
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                // Record the time we're showing the prompt
                lastReviewPromptTime = Date().timeIntervalSince1970
                requestReview()
            }
        }
    }
    
    private func checkForReviewCompletion() {
        // Check if we recently showed a review prompt and enough time has passed
        guard lastReviewPromptTime > 0 else { return }
        
        let timeElapsed = Date().timeIntervalSince1970 - lastReviewPromptTime
        
        // Different scenarios:
        // 1. If less than 3 seconds: User quickly dismissed (don't mark as reviewed)
        // 2. If 3-30 seconds: User might have reviewed or thoughtfully dismissed
        // 3. If more than 30 seconds: User definitely engaged with App Store
        
        if timeElapsed >= 3 {
            if timeElapsed >= 15 {
                // Likely reviewed or spent time in App Store
                hasUserReviewedApp = true
            } else {
                // User engaged with prompt but may have dismissed
                // Don't mark as reviewed, but reduce future prompt frequency
                // by adding a "soft dismiss" to history
                var history = reviewPromptHistory
                history.insert(-1) // Special marker for soft dismiss
                updateReviewPromptHistory(history)
            }
            lastReviewPromptTime = 0 // Reset the timer
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

}

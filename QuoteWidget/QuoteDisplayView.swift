import SwiftUI

struct QuoteDisplayView: View {
    let quote: Quote?
    
    var body: some View {
        VStack(spacing: 12) {
            if let quote = quote {
                Text(quote.text)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding()
                
                Text(quote.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No quote yet")
                    .font(.body)
                    .foregroundColor(.secondary)
                Text("Write your first quote!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

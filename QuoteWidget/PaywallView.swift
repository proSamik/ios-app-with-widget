//
//  PaywallView.swift
//  QuoteWidget
//
//  Created by Samik Choudhury on 08/11/25.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

struct SubscriptionPaywallView: View {
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Group {
            if let offering = revenueCatManager.currentOffering {
                PaywallView(offering: offering)
            } else {
                // Loading state while offerings are being fetched
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Loading subscription options...")
                        .foregroundColor(.secondary)
                }
                .task {
                    await revenueCatManager.loadOfferings()
                }
            }
        }
    }
}


#Preview {
    SubscriptionPaywallView()
        .environmentObject(RevenueCatManager.shared)
}


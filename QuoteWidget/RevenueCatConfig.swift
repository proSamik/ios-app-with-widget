import Foundation
import RevenueCat

// MARK: - RevenueCat Configuration
let revenueCatPublicKey = "test_CHawOtfsUmPKzCENHDQKzWICwvS"

// Initialize RevenueCat
func initializeRevenueCat() {
    Purchases.logLevel = .debug
    Purchases.configure(withAPIKey: revenueCatPublicKey, appUserID: nil, purchasesAreCompletedBy: .revenueCat, storeKitVersion: .storeKit2)
}

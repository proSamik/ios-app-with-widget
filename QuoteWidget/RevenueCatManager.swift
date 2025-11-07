import SwiftUI
import RevenueCat
import Combine

@MainActor
class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    
    @Published var isSubscribed = false
    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    @Published var currentOffering: Offering?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let entitlementID = "test_premium" // Your entitlement ID from dashboard
    
    private override init() {
        super.init()
        // Set as delegate to listen for updates
        Purchases.shared.delegate = self
        // Check initial subscription status for anonymous user
        Task {
            await checkSubscriptionStatus()
        }
    }
    
    // MARK: - Setup with User ID
    /// Call this after user logs in with their Supabase user ID
    func setupWithUserID(_ userID: String) async {
        // Set the user ID so RevenueCat knows who this is
        Purchases.shared.logIn(userID) { customerInfo, _, error in
            print("RevenueCat user set to: \(userID)")
            if let error = error {
                print("Error setting RevenueCat user: \(error.localizedDescription)")
            }
        }
        
        // Load offerings immediately
        await loadOfferings()
        await checkSubscriptionStatus()
    }
    
    // MARK: - Check Subscription Status
    func checkSubscriptionStatus() async {
        isLoading = true
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            self.customerInfo = customerInfo
            
            // Check if user has the premium entitlement
            self.isSubscribed = customerInfo.entitlements[entitlementID]?.isActive == true
            errorMessage = nil
            
            print("✅ Subscription status checked: \(isSubscribed)")
            print("Entitlements: \(customerInfo.entitlements.description)")
            
        } catch {
            print("❌ Error checking subscription: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isSubscribed = false
        }
        isLoading = false
    }
    
    // MARK: - Load Offerings
    func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            self.offerings = offerings
            self.currentOffering = offerings.current
            
            print("✅ Offerings loaded")
            if let current = offerings.current {
                print("Current offering: \(current.identifier)")
                print("Available packages: \(current.availablePackages.count)")
            }
            
        } catch {
            print("❌ Error loading offerings: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Make Purchase
    func purchase(package: Package) async -> Bool {
        isLoading = true
        do {
            let result = try await Purchases.shared.purchase(package: package)
            
            if !result.userCancelled {
                print("✅ Purchase successful!")
                await checkSubscriptionStatus()
                isLoading = false
                return true
            } else {
                print("User cancelled purchase")
                isLoading = false
                return false
            }
        } catch {
            print("❌ Purchase failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
            self.isSubscribed = customerInfo.entitlements[entitlementID]?.isActive == true
            
            print("✅ Purchases restored")
            errorMessage = nil
            
        } catch {
            print("❌ Error restoring purchases: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    // MARK: - Sign Out
    func signOut() async {
        do {
            _ = try await Purchases.shared.logOut()
            self.isSubscribed = false
            self.customerInfo = nil
            self.offerings = nil
            self.currentOffering = nil
            print("✅ RevenueCat user logged out")
        } catch {
            print("❌ Error logging out: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - PurchasesDelegate
extension RevenueCatManager: PurchasesDelegate {
    /// Called when subscription status changes
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            self.isSubscribed = customerInfo.entitlements[self.entitlementID]?.isActive == true
            print("🔄 Subscription status updated: \(self.isSubscribed)")
        }
    }
}

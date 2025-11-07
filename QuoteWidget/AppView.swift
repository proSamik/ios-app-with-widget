import SwiftUI
import Supabase
import RevenueCat

struct AppView: View {
    @State var isAuthenticated = false
    @State var currentUserID: String?
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    
    var body: some View {
        Group {
            if isAuthenticated {
                ProfileView()
                    .environmentObject(revenueCatManager)
            } else {
                AuthView()
                    .environmentObject(revenueCatManager)
            }
        }
        .task {
            // Listen to auth state changes
            for await (event, session) in supabase.auth.authStateChanges {
                await handleAuthStateChange(event: event, session: session)
            }
        }
    }
    
    // MARK: - Handle Auth State Change
    @MainActor
    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) async {
        if event == .signedIn || event == .initialSession {
            // User is signed in
            if let session = session {
                let userID = session.user.id.uuidString
                isAuthenticated = true
                currentUserID = userID
                
                print("✅ Auth: User signed in - \(userID)")
                
                // 🎯 REGISTER WITH REVENUECAT
                await revenueCatManager.setupWithUserID(userID)
                
                // Check subscription status
                await revenueCatManager.checkSubscriptionStatus()
            } else {
                isAuthenticated = false
            }
            
        } else if event == .signedOut {
            // User is signed out
            print("✅ Auth: User signed out")
            isAuthenticated = false
            currentUserID = nil
            
            // 🎯 SIGN OUT FROM REVENUECAT
            await revenueCatManager.signOut()
            
        } else {
            // Handle all other auth events (.passwordRecovery, .tokenRefreshed, .userUpdated, .mfaChallengeVerified, etc)
            print("ℹ️ Auth: State changed - \(event)")
        }
    }
}

#Preview {
    AppView()
        .environmentObject(RevenueCatManager.shared)
}

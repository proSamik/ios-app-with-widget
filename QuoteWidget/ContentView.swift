import SwiftUI
import SwiftData
import Supabase

extension Notification.Name {
    static let userDidSignIn = Notification.Name("userDidSignIn")
    static let userDidSignOut = Notification.Name("userDidSignOut")
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @State private var selectedTab = 0
    @State private var showPaywall = false
    @State private var syncService: QuoteSyncService?
    @State private var isAuthenticated = false
    @State private var isRevenueCatSetup = false
    @State private var isCheckingAuth = true
    
    var body: some View {
        Group {
            if isCheckingAuth {
                // Show loading while checking authentication state
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
                .task {
                    await checkInitialAuthState()
                }
            } else if !isAuthenticated {
                // Show authentication first
                AuthView()
                    .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { notification in
                        if let userID = notification.object as? String {
                            isAuthenticated = true
                            // Set up RevenueCat with user ID
                            Task {
                                await revenueCatManager.setupWithUserID(userID)
                                isRevenueCatSetup = true
                            }
                        }
                    }
            } else if !isRevenueCatSetup {
                // Loading state while setting up RevenueCat
                VStack(spacing: 20) {
                    ProgressView()
                    Text("Setting up your account...")
                        .foregroundColor(.secondary)
                }
            } else if !revenueCatManager.isSubscribed {
                // Show onboarding/paywall for authenticated but non-subscribed users
                OnboardingView(showPaywall: $showPaywall)
            } else {
                // Show main app for subscribers
                MainAppView(selectedTab: $selectedTab, syncService: $syncService, modelContext: modelContext)
            }
        }
        .sheet(isPresented: $showPaywall) {
            SubscriptionPaywallView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
            isAuthenticated = false
            isRevenueCatSetup = false
        }
    }
    
    @MainActor
    private func checkInitialAuthState() async {
        do {
            // Check if user is already authenticated with Supabase
            let currentUser = try await supabase.auth.user()
            
            // User is authenticated
            isAuthenticated = true
            print("✅ User already authenticated: \(currentUser.id.uuidString)")
            
            // Set up RevenueCat with the existing user ID
            await revenueCatManager.setupWithUserID(currentUser.id.uuidString)
            isRevenueCatSetup = true
            
        } catch {
            // User is not authenticated
            print("ℹ️ User not authenticated, showing auth screen")
            isAuthenticated = false
        }
        
        isCheckingAuth = false
    }
}

struct OnboardingView: View {
    @Binding var showPaywall: Bool
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("Welcome to QuoteWidget")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Save and share your favorite quotes")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button(action: {
                showPaywall = true
            }) {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

struct MainAppView: View {
    @Binding var selectedTab: Int
    @Binding var syncService: QuoteSyncService?
    let modelContext: ModelContext
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                QuoteEditorView()
                    .environmentObject(syncService ?? QuoteSyncService(modelContext: modelContext))
            }
            .tabItem {
                Label("Write", systemImage: "pencil")
            }
            .tag(0)
            
            NavigationStack {
                QuoteHistoryView()
                    .environmentObject(syncService ?? QuoteSyncService(modelContext: modelContext))
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .tag(1)
            
            NavigationStack {
                APIQuotesView()
            }
            .tabItem {
                Label("Discover", systemImage: "globe")
            }
            .tag(2)
            
            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
            .tag(3)
        }
        .onAppear {
            if syncService == nil {
                syncService = QuoteSyncService(modelContext: modelContext)
            }
        }
        .task {
            await syncService?.syncQuotesOnAppLaunch()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(SharedModelContainer.shared.container)
        .environmentObject(RevenueCatManager.shared)
}

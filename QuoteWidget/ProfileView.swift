import SwiftUI
import Supabase
import StoreKit

struct ProfileView: View {
    @State var isLoading = false
    @State var profile: UserProfile?
    @State var errorMessage: String?
    @State var isEditingName = false
    @State var editedName = ""
    @State var isSaving = false
    @AppStorage("hasUserReviewedApp") private var hasUserReviewedApp: Bool = false
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    // Profile Image
                    if let imageUrl = profile?.profileImageUrl, !imageUrl.isEmpty {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                    } else {
                        // Placeholder for profile image
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                            .frame(width: 120, height: 120)
                    }

                    // Name editing section
                    VStack {
                        if isEditingName {
                            HStack {
                                TextField("Enter your name", text: $editedName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .disabled(isSaving)
                                
                                Button("Save") {
                                    Task {
                                        await saveName()
                                    }
                                }
                                .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                                
                                Button("Cancel") {
                                    isEditingName = false
                                    editedName = profile?.name ?? ""
                                }
                                .disabled(isSaving)
                            }
                            
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        } else {
                            HStack {
                                if let name = profile?.name, !name.isEmpty {
                                    Text(name)
                                        .font(.title)
                                        .fontWeight(.bold)
                                } else {
                                    Text("No Name Set")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.gray)
                                }
                                
                                Button(action: {
                                    editedName = profile?.name ?? ""
                                    isEditingName = true
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }

                    // Email
                    if let email = profile?.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                    }

                    // Theme Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Theme")
                            .font(.headline)
                            .padding(.top)
                        
                        VStack(spacing: 8) {
                            ForEach(AppTheme.allCases, id: \.self) { theme in
                                HStack {
                                    Image(systemName: themeManager.currentTheme == theme ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(themeManager.currentTheme == theme ? .blue : .gray)
                                    
                                    Text(theme.displayName)
                                        .font(.body)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .onTapGesture {
                                    themeManager.currentTheme = theme
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }

                    Spacer()

                    // App Store Review Button
                    VStack {
                        Button(hasUserReviewedApp ? "Thank you for reviewing!" : "Rate App on App Store") {
                            if !hasUserReviewedApp {
                                openAppStoreReview()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(hasUserReviewedApp ? .green : .blue)
                        .disabled(hasUserReviewedApp)
                        .onLongPressGesture {
                            if hasUserReviewedApp {
                                // Reset review status (for testing)
                                hasUserReviewedApp = false
                            }
                        }
                        
                        if hasUserReviewedApp {
                            Text("Long press to reset")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Button("Sign out", role: .destructive) {
                        Task {
                            try? await supabase.auth.signOut()
                            // Post notification to update the UI
                            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Profile")
            .task {
                await fetchProfile()
            }
            .refreshable {
                await fetchProfile()
            }
            .onAppear {
                Task {
                    await fetchProfile()
                }
            }
        }
    }

    func saveName() async {
        isSaving = true
        errorMessage = nil
        
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            let user = try await supabase.auth.user()
            
            // Update profile in Supabase
            try await supabase
                .from("profiles")
                .update(["name": trimmedName])
                .eq("id", value: user.id.uuidString)
                .execute()
            
            // Update local profile only if save was successful
            var updatedProfile = profile
            updatedProfile?.name = trimmedName
            profile = updatedProfile
            
            isEditingName = false
        } catch {
            errorMessage = "Failed to update name: \(error.localizedDescription)"
            print("Name update error: \(error)")
        }
        
        isSaving = false
    }

    func fetchProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            // Get the current user - this will throw if no session exists
            let user = try await supabase.auth.user()

            // Fetch profile from Supabase
            let response: [UserProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: user.id.uuidString)
                .execute()
                .value

            if let existingProfile = response.first {
                // Profile exists, use it
                profile = existingProfile
            } else {
                // Profile should be created by database trigger, wait a bit and retry
                try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
                
                let retryResponse: [UserProfile] = try await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: user.id.uuidString)
                    .execute()
                    .value
                
                profile = retryResponse.first
            }
        } catch {
            // Don't show error message for session missing - it's expected after sign out
            if error.localizedDescription.contains("sessionMissing") || error.localizedDescription.contains("Auth session is missing") {
                print("Profile fetch: No auth session (user likely signed out)")
                profile = nil
            } else {
                errorMessage = "Failed to load profile: \(error.localizedDescription)"
                print("Profile fetch error: \(error)")
            }
        }

        isLoading = false
    }
    
    private func openAppStoreReview() {
        // Mark that user has reviewed the app (they clicked the review button)
        hasUserReviewedApp = true
        
        // TODO: Replace YOUR_APP_ID with your actual App Store ID when available
        // For now, this will open the App Store app directly
        guard let url = URL(string: "https://apps.apple.com/app/id1234567890?action=write-review") else { 
            // Fallback to main App Store if review URL fails
            if let fallbackURL = URL(string: "https://apps.apple.com/") {
                UIApplication.shared.open(fallbackURL)
            }
            return 
        }
        UIApplication.shared.open(url)
    }
}

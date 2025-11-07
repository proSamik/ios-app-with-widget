import SwiftUI
import Supabase

struct ProfileView: View {
    @State var isLoading = false
    @State var profile: UserProfile?
    @State var errorMessage: String?
    @State var isEditingName = false
    @State var editedName = ""
    @State var isSaving = false

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

                    Spacer()

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
}

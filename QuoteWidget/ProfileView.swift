import SwiftUI
import Supabase

struct ProfileView: View {
    @State var isLoading = false
    @State var profile: UserProfile?
    @State var errorMessage: String?

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

                    // Name
                    if let name = profile?.name, !name.isEmpty {
                        Text(name)
                            .font(.title)
                            .fontWeight(.bold)
                    } else {
                        // Placeholder for name
                        Text("No Name Set")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
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
        }
    }

    func fetchProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            // Get the current user
            guard let user = try await supabase.auth.session.user else {
                errorMessage = "No user logged in"
                isLoading = false
                return
            }

            // Fetch profile from Supabase
            let response: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: user.id.uuidString)
                .single()
                .execute()
                .value

            profile = response
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
            print("Profile fetch error: \(error)")
        }

        isLoading = false
    }
}

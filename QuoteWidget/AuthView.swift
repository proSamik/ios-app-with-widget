import SwiftUI
import AuthenticationServices
import Supabase
import GoogleSignIn

struct ProfileInsert: Codable {
    let id: String
    let email: String
    let name: String?
    let profileImageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case profileImageUrl = "profile_image_url"
    }
}

struct AuthView: View {
    @State var isSignedIn = false
    @State var user: User?
    @State var errorMessage: String?
    @State var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to QuoteWidget")
                .font(.title)
                .fontWeight(.bold)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Apple Sign In Button
            SignInWithAppleButton { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                Task {
                    await handleAppleSignIn(result)
                }
            }
            .frame(height: 50)
            .signInWithAppleButtonStyle(.black)
            
            // Google Sign In Button
            Button(action: {
                Task {
                    await handleGoogleSignIn()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.blue)
                    
                    Text("Sign in with Google")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .padding(.horizontal, 16)
                .background(Color.white)
                .border(Color.gray.opacity(0.3), width: 1)
                .cornerRadius(8)
            }
            
            if isLoading {
                ProgressView()
            }
            
            if isSignedIn {
                VStack(spacing: 12) {
                    Text("Signed in!")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    Text(user?.email ?? "User")
                        .font(.caption)
                    
                    Button(action: {
                        Task {
                            do {
                                try await supabase.auth.signOut()
                                isSignedIn = false
                                user = nil
                                errorMessage = nil
                            } catch {
                                errorMessage = "Sign out failed: \(error.localizedDescription)"
                            }
                        }
                    }) {
                        Text("Sign Out")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Apple Sign In
    @MainActor
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Failed to get Apple ID credential"
                return
            }
            
            guard let idToken = credential.identityToken
                .flatMap({ String(data: $0, encoding: .utf8) })
            else {
                errorMessage = "Unable to extract identity token"
                return
            }
            
            try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken
                )
            )
            
            // Update user profile with full name from Apple
            await updateAppleUserProfile(credential: credential)
            
            print("Sign in with Apple successful!")
            
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            print("Sign in with Apple failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Google Sign In
    @MainActor
    private func handleGoogleSignIn() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let clientID = Bundle.main.infoDictionary?["GIDClientID"] as? String else {
                errorMessage = "Google Client ID not configured"
                return
            }
            
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                errorMessage = "Unable to get view controller"
                return
            }
            
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController
            )
            
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Unable to extract identity token from Google"
                return
            }
            
            let accessToken = result.user.accessToken.tokenString
            
            // Supabase recommended approach
            try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )
            
            // Update user profile with data from Google
            await updateGoogleUserProfile(googleUser: result.user)
            
            print("Sign in with Google successful!")
            
        } catch {
            errorMessage = "Google sign in failed: \(error.localizedDescription)"
            print("Google sign in failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    private func handlePostSignIn() async {
        do {
            let currentUser = try await supabase.auth.user()
            print("User signed in: \(currentUser.id.uuidString)")
            
            user = currentUser
            isSignedIn = true
            errorMessage = nil
        } catch {
            errorMessage = "Failed to get user: \(error.localizedDescription)"
            print("Post sign-in error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Update User Profile Methods
    @MainActor
    private func updateAppleUserProfile(credential: ASAuthorizationAppleIDCredential) async {
        await handlePostSignIn()
    }
    
    @MainActor
    private func updateGoogleUserProfile(googleUser: GIDGoogleUser) async {
        await handlePostSignIn()
    }
}

#Preview {
    AuthView()
}

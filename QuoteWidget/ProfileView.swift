import SwiftUI
import Supabase

struct ProfileView: View {
    @State var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Welcome to your profile!")
                    .font(.title)
                
                Button("Sign out", role: .destructive) {
                    Task {
                        try? await supabase.auth.signOut()
                    }
                }
            }
            .padding()
            .navigationTitle("Profile")
        }
    }
}

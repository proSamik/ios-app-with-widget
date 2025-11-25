import SwiftUI
import LocalAuthentication

struct AuthenticationGateView: View {
    @EnvironmentObject var revenueCatManager: RevenueCatManager
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var biometricAuthManager = BiometricAuthManager()
    @StateObject private var pinManager = PINManager()
    @AppStorage("isBiometricEnabled") private var isBiometricEnabled: Bool = false
    @State private var isAuthenticated = false
    @State private var showPINEntry = false
    @State private var enteredPIN = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var attempts = 0
    @State private var isLocked = false
    @State private var lockTimeRemaining = 0
    @State private var hasTriedBiometric = false

    let maxAttempts = 3
    let lockDuration = 30 // seconds
    let content: AnyView

    init<Content: View>(@ViewBuilder content: () -> Content) {
        self.content = AnyView(content())
    }

    var body: some View {
        Group {
            if isAuthenticated {
                content
                    .environmentObject(revenueCatManager)
                    .environmentObject(themeManager)
            } else {
                authenticationView
            }
        }
        .onAppear {
            checkAuthenticationRequired()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Re-authenticate when app comes to foreground
            if needsAuthentication() {
                isAuthenticated = false
                hasTriedBiometric = false
                resetAttempts()
                checkAuthenticationRequired()
            }
        }
    }
    
    private var authenticationView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: isLocked ? "lock.fill" : "lock.shield")
                    .font(.system(size: 80))
                    .foregroundColor(isLocked ? .red : .blue)
                
                VStack(spacing: 10) {
                    Text("QuoteWidget")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if isLocked {
                        VStack(spacing: 8) {
                            Text("Too Many Attempts")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                            
                            Text("Try again in \(lockTimeRemaining) seconds")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Authenticate to continue")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !isLocked {
                authenticationButtons
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK") {
                enteredPIN = ""
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var authenticationButtons: some View {
        VStack(spacing: 20) {
            // Biometric Authentication Button
            if isBiometricEnabled && biometricAuthManager.canUseBiometrics() && !hasTriedBiometric {
                Button(action: authenticateWithBiometrics) {
                    HStack {
                        Image(systemName: biometricAuthManager.getBiometricType() == "Face ID" ? "faceid" : "touchid")
                        Text("Use \(biometricAuthManager.getBiometricType())")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            // PIN Authentication
            if pinManager.isPINEnabled {
                if !showPINEntry {
                    Button(action: { showPINEntry = true }) {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("Use PIN")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                } else {
                    VStack(spacing: 15) {
                        PINEntryView(
                            pin: $enteredPIN,
                            title: "Enter PIN",
                            subtitle: attempts > 0 ? "Incorrect PIN. \(maxAttempts - attempts) attempts remaining." : nil
                        )
                        .onChange(of: enteredPIN) { oldValue, newValue in
                            if newValue.count == 4 {
                                verifyPIN()
                            }
                        }
                        
                        if showError {
                            Text("Incorrect PIN")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        Button("Cancel") {
                            showPINEntry = false
                            enteredPIN = ""
                            showError = false
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            
            // If no authentication methods are enabled, allow access
            if !isBiometricEnabled && !pinManager.isPINEnabled {
                Button("Continue") {
                    isAuthenticated = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
    
    private func checkAuthenticationRequired() {
        if needsAuthentication() {
            if isBiometricEnabled && biometricAuthManager.canUseBiometrics() {
                // Auto-trigger biometric authentication
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    authenticateWithBiometrics()
                }
            }
            // Otherwise wait for user to choose authentication method
        } else {
            isAuthenticated = true
        }
    }
    
    private func needsAuthentication() -> Bool {
        return isBiometricEnabled || pinManager.isPINEnabled
    }
    
    private func authenticateWithBiometrics() {
        hasTriedBiometric = true
        biometricAuthManager.authenticateWithDeviceOwner { success, error in
            if success {
                isAuthenticated = true
                resetAttempts()
            } else {
                errorMessage = error?.localizedDescription ?? "Biometric authentication failed"
                showError = true
                
                // Show PIN option if available
                if pinManager.isPINEnabled {
                    showPINEntry = true
                }
            }
        }
    }
    
    private func verifyPIN() {
        let success = pinManager.verifyPIN(enteredPIN)
        
        if success {
            isAuthenticated = true
            resetAttempts()
        } else {
            attempts += 1
            showError = true
            enteredPIN = ""
            
            if attempts >= maxAttempts {
                lockApp()
            }
            
            // Haptic feedback for wrong PIN
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
    
    private func lockApp() {
        isLocked = true
        showPINEntry = false
        lockTimeRemaining = lockDuration
        
        // Store lock time
        UserDefaults.standard.set(Date().timeIntervalSince1970 + Double(lockDuration), forKey: "appLockUntil")
        
        // Start countdown timer
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            lockTimeRemaining -= 1
            
            if lockTimeRemaining <= 0 {
                timer.invalidate()
                resetAttempts()
                isLocked = false
            }
        }
    }
    
    private func resetAttempts() {
        attempts = 0
        showError = false
        enteredPIN = ""
        UserDefaults.standard.removeObject(forKey: "appLockUntil")
    }
}
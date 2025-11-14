import LocalAuthentication
import Foundation
import Combine

class BiometricAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var authenticationError: String?
    
    enum AuthPolicy {
        case biometricOnly
        case biometricWithDevicePasscode
    }
    
    // Check if biometrics are available
    func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    // Get biometric type available
    func getBiometricType() -> String {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "None"
        }
        
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "None"
        @unknown default:
            return "Unknown"
        }
    }
    
    // Authenticate with biometrics using .deviceOwnerAuthentication policy
    func authenticateWithDeviceOwner(completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(false, error)
            return
        }
        
        let reason = "Authenticate to access secure features"
        
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                if success {
                    self.isAuthenticated = true
                    completion(true, nil)
                } else {
                    self.authenticationError = authError?.localizedDescription
                    completion(false, authError)
                }
            }
        }
    }
    
    // Authenticate with specific policy
    func authenticate(policy: AuthPolicy = .biometricOnly, completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // Determine which policy to use
        let laPolicy: LAPolicy = policy == .biometricOnly 
            ? .deviceOwnerAuthenticationWithBiometrics 
            : .deviceOwnerAuthentication
        
        // Check if authentication is available
        guard context.canEvaluatePolicy(laPolicy, error: &error) else {
            completion(false, error)
            return
        }
        
        let reason = "Authenticate to access secure features"
        
        context.evaluatePolicy(laPolicy, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                if success {
                    self.isAuthenticated = true
                    completion(true, nil)
                } else {
                    self.authenticationError = authError?.localizedDescription
                    completion(false, authError)
                }
            }
        }
    }
    
    // Reset authentication state
    func resetAuthentication() {
        isAuthenticated = false
        authenticationError = nil
    }
}
import Security
import Foundation
import CommonCrypto
import Combine

class PINManager: ObservableObject {
    private let service = "com.quotewidget.app.pin"
    private let account = "userPIN"
    private let enabledKey = "isPINEnabled"
    
    @Published var isPINEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isPINEnabled, forKey: enabledKey)
        }
    }
    
    init() {
        self.isPINEnabled = UserDefaults.standard.bool(forKey: enabledKey)
    }
    
    // Save PIN to Keychain (hashed with salt)
    func savePIN(_ pin: String) -> Bool {
        guard let hashedPIN = hashPINWithSalt(pin) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: hashedPIN,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing PIN first
        SecItemDelete(query as CFDictionary)
        
        // Add new PIN
        let status = SecItemAdd(query as CFDictionary, nil)
        let success = status == errSecSuccess
        
        if success {
            isPINEnabled = true
        }
        
        return success
    }
    
    // Verify PIN
    func verifyPIN(_ pin: String) -> Bool {
        guard isPINEnabled else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let storedData = result as? Data else {
            return false
        }
        
        guard let hashedPIN = hashPINWithSalt(pin) else { return false }
        
        return storedData == hashedPIN
    }
    
    // Delete PIN from Keychain
    func deletePIN() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        let success = status == errSecSuccess || status == errSecItemNotFound
        
        if success {
            isPINEnabled = false
        }
        
        return success
    }
    
    // Check if PIN exists
    func hasPIN() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // Hash PIN with salt using PBKDF2
    private func hashPINWithSalt(_ pin: String) -> Data? {
        guard let pinData = pin.data(using: .utf8) else { return nil }
        
        // Use a fixed salt for simplicity (in production, use a random salt per user)
        let salt = "QuoteWidgetSalt2024".data(using: .utf8)!
        let iterations = 100000 // PBKDF2 iterations
        let keyLength = 32 // 256 bits
        
        var derivedKey = [UInt8](repeating: 0, count: keyLength)
        
        let result = pinData.withUnsafeBytes { pinBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    pinBytes.bindMemory(to: Int8.self).baseAddress,
                    pinData.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    &derivedKey,
                    keyLength
                )
            }
        }
        
        guard result == kCCSuccess else { return nil }
        
        return Data(derivedKey)
    }
}
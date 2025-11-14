import SwiftUI
import Combine

class SecurityManager: ObservableObject {
    @Published var shouldRequireAuthentication = false
    @AppStorage("isBiometricEnabled") private var isBiometricEnabled: Bool = false
    @StateObject private var pinManager = PINManager()
    
    private var backgroundTime: Date?
    private let backgroundTimeout: TimeInterval = 60 // 1 minute
    
    init() {
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        if hasSecurityEnabled() {
            backgroundTime = Date()
        }
    }
    
    @objc private func appWillEnterForeground() {
        if hasSecurityEnabled() {
            if let backgroundTime = backgroundTime {
                let timeInBackground = Date().timeIntervalSince(backgroundTime)
                if timeInBackground > backgroundTimeout {
                    shouldRequireAuthentication = true
                }
            }
        }
        backgroundTime = nil
    }
    
    func hasSecurityEnabled() -> Bool {
        return isBiometricEnabled || pinManager.isPINEnabled
    }
    
    func resetAuthenticationRequirement() {
        shouldRequireAuthentication = false
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
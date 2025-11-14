import SwiftUI

struct PINEntryView: View {
    @Binding var pin: String
    @State private var pins: [String] = ["", "", "", ""]
    @FocusState private var focusedField: Int?
    let numberOfFields = 4
    let title: String
    let subtitle: String?
    
    init(pin: Binding<String>, title: String = "Enter PIN", subtitle: String? = nil) {
        self._pin = pin
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            HStack(spacing: 15) {
                ForEach(0..<numberOfFields, id: \.self) { index in
                    SecureField("", text: $pins[index])
                        .frame(width: 50, height: 50)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(focusedField == index ? Color.blue : Color.gray.opacity(0.5), lineWidth: 2)
                        )
                        .focused($focusedField, equals: index)
                        .onChange(of: pins[index]) { oldValue, newValue in
                            handlePINInput(index: index, value: newValue)
                        }
                        .onTapGesture {
                            focusedField = index
                        }
                }
            }
            
            if pin.count == numberOfFields {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("PIN Complete")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
        .onAppear {
            focusedField = 0
            pins = ["", "", "", ""]
            pin = ""
        }
        .onTapGesture {
            if focusedField == nil {
                focusedField = pins.firstIndex(where: { $0.isEmpty }) ?? 0
            }
        }
    }
    
    private func handlePINInput(index: Int, value: String) {
        // Only allow numeric input
        let filtered = value.filter { $0.isNumber }
        
        // Limit to single digit
        if filtered.count > 1 {
            pins[index] = String(filtered.prefix(1))
        } else {
            pins[index] = filtered
        }
        
        // Auto-advance to next field when entering a digit
        if !pins[index].isEmpty && index < numberOfFields - 1 {
            focusedField = index + 1
        }
        
        // Auto-go back to previous field when deleting
        if pins[index].isEmpty && index > 0 && value.isEmpty {
            focusedField = index - 1
        }
        
        // Update complete PIN
        pin = pins.joined()
    }
}

struct PINSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var pinManager: PINManager
    @State private var currentStep: SetupStep = .enterPIN
    @State private var firstPIN = ""
    @State private var confirmPIN = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    enum SetupStep {
        case enterPIN
        case confirmPIN
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                switch currentStep {
                case .enterPIN:
                    PINEntryView(
                        pin: $firstPIN,
                        title: "Set up PIN",
                        subtitle: "Enter a 4-digit PIN to secure your app"
                    )
                    .onChange(of: firstPIN) { oldValue, newValue in
                        if newValue.count == 4 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation {
                                    currentStep = .confirmPIN
                                }
                            }
                        }
                    }
                    
                case .confirmPIN:
                    PINEntryView(
                        pin: $confirmPIN,
                        title: "Confirm PIN",
                        subtitle: "Enter your PIN again to confirm"
                    )
                    .onChange(of: confirmPIN) { oldValue, newValue in
                        if newValue.count == 4 {
                            setupPIN()
                        }
                    }
                }
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Spacer()
                
                if currentStep == .confirmPIN {
                    Button("Go Back") {
                        withAnimation {
                            currentStep = .enterPIN
                            confirmPIN = ""
                        }
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .navigationTitle("Security Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    withAnimation {
                        currentStep = .enterPIN
                        firstPIN = ""
                        confirmPIN = ""
                    }
                }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func setupPIN() {
        isLoading = true
        
        guard firstPIN == confirmPIN else {
            errorMessage = "PINs don't match. Please try again."
            showError = true
            isLoading = false
            return
        }
        
        guard firstPIN.count == 4 else {
            errorMessage = "PIN must be 4 digits."
            showError = true
            isLoading = false
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let success = pinManager.savePIN(firstPIN)
            
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    dismiss()
                } else {
                    errorMessage = "Failed to save PIN. Please try again."
                    showError = true
                }
            }
        }
    }
}

struct PINVerificationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var pinManager: PINManager
    @State private var enteredPIN = ""
    @State private var showError = false
    @State private var attempts = 0
    @State private var isLocked = false
    @State private var lockTimeRemaining = 0
    let onSuccess: () -> Void
    let maxAttempts = 3
    let lockDuration = 30 // seconds
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: isLocked ? "lock.fill" : "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(isLocked ? .red : .blue)
            
            if isLocked {
                VStack(spacing: 10) {
                    Text("Too Many Attempts")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                    
                    Text("Try again in \(lockTimeRemaining) seconds")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
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
            }
            
            if showError && !isLocked {
                Text("Incorrect PIN")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            checkLockStatus()
        }
    }
    
    private func verifyPIN() {
        let success = pinManager.verifyPIN(enteredPIN)
        
        if success {
            resetAttempts()
            onSuccess()
            dismiss()
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
        lockTimeRemaining = lockDuration
        
        // Store lock time
        UserDefaults.standard.set(Date().timeIntervalSince1970 + Double(lockDuration), forKey: "pinLockUntil")
        
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
    
    private func checkLockStatus() {
        let lockUntil = UserDefaults.standard.double(forKey: "pinLockUntil")
        let now = Date().timeIntervalSince1970
        
        if lockUntil > now {
            isLocked = true
            lockTimeRemaining = Int(lockUntil - now)
            
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                lockTimeRemaining -= 1
                
                if lockTimeRemaining <= 0 {
                    timer.invalidate()
                    resetAttempts()
                    isLocked = false
                }
            }
        }
    }
    
    private func resetAttempts() {
        attempts = 0
        showError = false
        UserDefaults.standard.removeObject(forKey: "pinLockUntil")
    }
}
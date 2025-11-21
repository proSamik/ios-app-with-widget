import SwiftUI

struct TypewriterView: View {
    let text: String
    @State private var displayedText: String = ""
    @State private var typingTimer: Timer?

    let typingSpeed: Double = 0.03 // Fast typing speed (in seconds per character)
    let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light
    let shouldHaveHaptic: Bool = true
    let hapticInterval: Int = 3 // Trigger haptic every 3 characters to stay under 32Hz limit

    var body: some View {
        Text(displayedText)
            .onAppear {
                startTypewriter()
            }
            .onDisappear {
                stopTypewriter()
            }
    }

    private func startTypewriter() {
        displayedText = ""
        var characterIndex = 0
        let characters = Array(text)

        // Prepare the haptic generator for better performance
        let generator = UIImpactFeedbackGenerator(style: hapticStyle)
        generator.prepare()

        typingTimer = Timer.scheduledTimer(withTimeInterval: typingSpeed, repeats: true) { _ in
            if characterIndex < characters.count {
                displayedText.append(characters[characterIndex])

                // Only trigger haptic every N characters to avoid rate limiting
                if shouldHaveHaptic && characterIndex % hapticInterval == 0 {
                    generator.impactOccurred(intensity: 0.5)
                }

                characterIndex += 1
            } else {
                stopTypewriter()
            }
        }
    }
    
    private func stopTypewriter() {
        typingTimer?.invalidate()
        typingTimer = nil
    }
}

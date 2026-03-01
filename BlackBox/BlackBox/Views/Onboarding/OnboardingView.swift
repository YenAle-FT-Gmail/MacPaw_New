import SwiftUI
import AppKit

struct OnboardingView: View {
    @Binding var hasGrantedAccess: Bool
    @Binding var showOnboarding: Bool
    @State private var currentStep: Int = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                switch currentStep {
                case 0:
                    welcomeStep
                case 1:
                    privacyExplanationStep
                case 2:
                    fullDiskAccessStep
                default:
                    EmptyView()
                }
                
                Spacer()
                
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { step in
                        Circle()
                            .fill(step == currentStep ? Color.white : Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 24)
                
                // Navigation
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation { currentStep -= 1 }
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: { advance() }) {
                        Text(currentStep == 2 ? "Open System Settings" : "Continue")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(Color.white)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: 600)
        }
    }
    
    // MARK: - Step 1: Welcome
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Text("BLACK")
                .font(.system(size: 42, weight: .black, design: .monospaced))
                .foregroundColor(.white) +
            Text("BOX")
                .font(.system(size: 42, weight: .black, design: .monospaced))
                .foregroundColor(Color(hex: "00FF66"))
            
            Text("Privacy Audit System")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(4)
            
            Spacer().frame(height: 20)
            
            Text("Your Mac stores more about you than you might expect.\nBlackBox scans locally — nothing leaves your machine.")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 450)
        }
    }
    
    // MARK: - Step 2: What We Scan
    private var privacyExplanationStep: some View {
        VStack(spacing: 24) {
            Text("WHAT WE LOOK FOR")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .tracking(2)
            
            VStack(alignment: .leading, spacing: 16) {
                OnboardingItem(
                    icon: "mappin.circle",
                    title: "GPS in Photos",
                    description: "Photos often contain embedded latitude/longitude. If shared online, this can reveal where you live and travel."
                )
                OnboardingItem(
                    icon: "doc.text.magnifyingglass",
                    title: "Sensitive Data in Files",
                    description: "Documents may contain credit card numbers, SSNs, or passwords stored in plaintext."
                )
                OnboardingItem(
                    icon: "trash",
                    title: "Recoverable Deleted Files",
                    description: "Deleted files remain on disk until overwritten. Anyone with physical access could recover them."
                )
                OnboardingItem(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Active Telemetry",
                    description: "Apps and the OS may transmit usage data to remote servers."
                )
            }
            .frame(maxWidth: 420)
        }
    }
    
    // MARK: - Step 3: Full Disk Access
    private var fullDiskAccessStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(.cyan)
            
            Text("FULL DISK ACCESS REQUIRED")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .tracking(2)
            
            Text("To perform a thorough privacy audit, BlackBox needs Full Disk Access. This allows the scanner to check files that macOS restricts by default — including your Photos library and Documents.\n\nBlackBox only reads files during the audit. No data is modified during scanning, and nothing is sent to any server.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 450)
            
            VStack(alignment: .leading, spacing: 8) {
                InstructionStep(number: 1, text: "Click \"Open System Settings\" below")
                InstructionStep(number: 2, text: "Navigate to Privacy & Security → Full Disk Access")
                InstructionStep(number: 3, text: "Toggle BlackBox ON")
                InstructionStep(number: 4, text: "Return to BlackBox to start your audit")
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
            
            // Skip option
            Button("Skip for now (limited scan)") {
                showOnboarding = false
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.gray)
        }
    }
    
    private func advance() {
        if currentStep < 2 {
            withAnimation { currentStep += 1 }
        } else {
            // Open System Preferences > Full Disk Access
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Onboarding Item
struct OnboardingItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.cyan)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineSpacing(2)
            }
        }
    }
}

// MARK: - Instruction Step
struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.cyan))
            
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

import SwiftUI
import AppKit

/// A "Hold to Confirm" button that requires the user to press and hold for a specified duration
/// before the destructive action fires. This prevents accidental clicks on neutralize operations.
struct HoldToConfirmButton: View {
    let label: String
    let icon: String
    let holdDuration: TimeInterval
    let gradient: LinearGradient
    let shadowColor: Color
    let action: () -> Void
    
    @State private var isHolding = false
    @State private var holdProgress: CGFloat = 0
    @State private var holdTimer: Timer?
    @State private var didFire = false
    
    init(
        label: String,
        icon: String = "bolt.shield.fill",
        holdDuration: TimeInterval = 2.0,
        gradient: LinearGradient = LinearGradient(colors: [Color(hex: "FF2D2D"), Color(hex: "DC2626")], startPoint: .leading, endPoint: .trailing),
        shadowColor: Color = Color(hex: "FF2D2D"),
        action: @escaping () -> Void
    ) {
        self.label = label
        self.icon = icon
        self.holdDuration = holdDuration
        self.gradient = gradient
        self.shadowColor = shadowColor
        self.action = action
    }
    
    var body: some View {
        ZStack {
            // Background track
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .frame(height: 44)
            
            // Fill progress
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 10)
                    .fill(gradient)
                    .frame(width: geo.size.width * holdProgress)
                    .animation(.linear(duration: 0.05), value: holdProgress)
            }
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Label
            HStack(spacing: 8) {
                Image(systemName: isHolding ? "hand.raised.fill" : icon)
                    .font(.system(size: 14, weight: .bold))
                
                Text(isHolding ? "HOLD \(Int((1 - holdProgress) * holdDuration))s..." : label)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .shadow(color: shadowColor.opacity(isHolding ? 0.6 : 0.3), radius: isHolding ? 20 : 12, y: 4)
        .scaleEffect(isHolding ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHolding)
        .onLongPressGesture(minimumDuration: holdDuration, pressing: { pressing in
            if pressing {
                startHold()
            } else {
                cancelHold()
            }
        }, perform: {
            completeHold()
        })
    }
    
    private func startHold() {
        isHolding = true
        didFire = false
        holdProgress = 0
        
        // Haptic feedback on press start
        HapticManager.alignment()
        
        // Animate progress via timer
        let interval: TimeInterval = 0.03
        let increment = CGFloat(interval / holdDuration)
        
        holdTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            holdProgress += increment
            if holdProgress >= 1.0 {
                timer.invalidate()
            }
        }
    }
    
    private func cancelHold() {
        isHolding = false
        holdProgress = 0
        holdTimer?.invalidate()
        holdTimer = nil
    }
    
    private func completeHold() {
        guard !didFire else { return }
        didFire = true
        isHolding = false
        holdProgress = 1.0
        holdTimer?.invalidate()
        holdTimer = nil
        
        // Strong haptic on completion
        HapticManager.levelChange()
        
        action()
    }
}

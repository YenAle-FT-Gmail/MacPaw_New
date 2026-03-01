import AppKit

/// Provides haptic feedback on macOS using NSHapticFeedbackManager.
/// Used for state transitions, confirmations, and alerts throughout the app.
struct HapticManager {
    
    private static let performer = NSHapticFeedbackManager.defaultPerformer
    
    /// Light tap — used for UI navigation, tab switches.
    static func alignment() {
        performer.perform(.alignment, performanceTime: .now)
    }
    
    /// Medium bump — used for state transitions (auditing → exposed).
    static func levelChange() {
        performer.perform(.levelChange, performanceTime: .now)
    }
    
    /// Generic feedback — used for scan progress milestones.
    static func generic() {
        performer.perform(.generic, performanceTime: .now)
    }
    
    // MARK: - App-Specific Haptic Events
    
    /// Fired when audit completes and findings are revealed.
    static func auditComplete(findingsCount: Int) {
        if findingsCount > 0 {
            // Multiple rapid bumps for "exposed" state
            for i in 0..<min(findingsCount, 3) {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    performer.perform(.levelChange, performanceTime: .now)
                }
            }
        } else {
            // Single gentle tap for "all clear"
            performer.perform(.alignment, performanceTime: .now)
        }
    }
    
    /// Fired during neutralization progress at each milestone.
    static func neutralizeProgress() {
        performer.perform(.alignment, performanceTime: .now)
    }
    
    /// Fired when neutralization is complete — system is "cloaked".
    static func neutralizeComplete() {
        // Two firm bumps
        performer.perform(.levelChange, performanceTime: .now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            performer.perform(.levelChange, performanceTime: .now)
        }
    }
    
    /// Fired when the user attempts a blocked/denied action.
    static func denied() {
        performer.perform(.generic, performanceTime: .now)
    }
}

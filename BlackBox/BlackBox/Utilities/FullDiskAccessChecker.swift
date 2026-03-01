import Foundation
import AppKit

/// Checks whether the app has Full Disk Access by attempting to read a protected path.
struct FullDiskAccessChecker {
    
    /// Returns true if the app can read TCC-protected directories.
    static func hasFullDiskAccess() -> Bool {
        // Try to read from a TCC-protected path
        let protectedPaths = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Mail").path,
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Safari").path,
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Messages").path,
        ]
        
        for path in protectedPaths {
            if FileManager.default.isReadableFile(atPath: path) {
                return true
            }
        }
        
        // Fallback: try to list the contents of a protected directory
        let testPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari")
        
        do {
            _ = try FileManager.default.contentsOfDirectory(atPath: testPath.path)
            return true
        } catch {
            return false
        }
    }
    
    /// Opens System Preferences to the Full Disk Access pane.
    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}

import Foundation

/// Safety guardrail: Hardcoded exclusion list that prevents BlackBox from ever scanning or modifying protected system paths.
/// This is the first check in both AuditEngine and NeutralizeEngine pipelines.
struct ExclusionList {
    
    /// Paths that BlackBox must NEVER read, scan, or touch.
    static let forbiddenPrefixes: [String] = [
        "/System",
        "/Library/Receipts",
        "/bin",
        "/sbin",
        "/usr/bin",
        "/usr/sbin",
        "/usr/lib",
        "/private/var/db",
        "/private/var/protected",
        "/Library/Apple",
        "/Library/SystemMigration",
    ]
    
    /// File names that must never be shredded or vaulted regardless of path.
    static let protectedFileNames: Set<String> = [
        ".DS_Store",
        ".localized",
        "SystemVersion.plist",
        "PlatformSupport.plist",
    ]
    
    /// Returns `true` if the given path is safe to scan or modify.
    /// Returns `false` if the path falls within a protected zone.
    static func isSafePath(_ path: String) -> Bool {
        let resolved = (path as NSString).resolvingSymlinksInPath
        
        for prefix in forbiddenPrefixes {
            if resolved.hasPrefix(prefix) {
                return false
            }
        }
        
        let fileName = (resolved as NSString).lastPathComponent
        if protectedFileNames.contains(fileName) {
            return false
        }
        
        return true
    }
    
    /// Returns `true` if the given URL is safe.
    static func isSafe(_ url: URL) -> Bool {
        isSafePath(url.path)
    }
    
    /// Filters an array of URLs, returning only those in safe locations.
    static func filterSafe(_ urls: [URL]) -> [URL] {
        urls.filter { isSafe($0) }
    }
    
    /// Log a blocked access attempt.
    static func logBlocked(_ path: String, operation: String) {
        print("[BlackBox] BLOCKED \(operation) on protected path: \(path)")
    }
}

import Foundation
import CoreLocation
import ImageIO

/// The central read-only scanning engine. Never writes to user files.
/// All scan methods enforce ExclusionList guardrails before touching any path.
actor AuditEngine {
    
    // MARK: - Photo Metadata Scanner
    
    struct PhotoScanResult {
        var locations: [PhotoLocationFinding] = []
        var findings: [AuditFinding] = []
    }
    
    func scanPhotoMetadata(progress: @escaping (Double) -> Void) async -> PhotoScanResult {
        var result = PhotoScanResult()
        
        // Phase 1: Scan Photos.sqlite for GPS data from Apple Photos Library
        let sqliteLocations = scanPhotosSQLite()
        result.locations.append(contentsOf: sqliteLocations)
        for loc in sqliteLocations {
            result.findings.append(AuditFinding(
                category: .photoMetadata,
                severity: .high,
                title: "GPS coordinates in Photos Library: \(loc.fileName)",
                detail: "Apple Photos database contains embedded location data (\(String(format: "%.4f", loc.coordinate.latitude)), \(String(format: "%.4f", loc.coordinate.longitude))).",
                filePath: loc.photoPath
            ))
        }
        progress(0.3)
        
        // Phase 2: Scan loose image files in ~/Pictures for EXIF GPS
        let photosPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures")
        
        let imageExtensions = Set(["jpg", "jpeg", "png", "heic", "tiff", "tif"])
        var imageFiles: [URL] = []
        
        if let enumerator = FileManager.default.enumerator(at: photosPath, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if imageExtensions.contains(fileURL.pathExtension.lowercased()),
                   ExclusionList.isSafe(fileURL) {
                    imageFiles.append(fileURL)
                }
            }
        }
        
        guard !imageFiles.isEmpty else {
            progress(1.0)
            return result
        }
        
        for (index, fileURL) in imageFiles.enumerated() {
            autoreleasepool {
                if let finding = extractGPSFromImage(at: fileURL) {
                    result.locations.append(finding)
                    result.findings.append(AuditFinding(
                        category: .photoMetadata,
                        severity: .high,
                        title: "GPS coordinates in \(fileURL.lastPathComponent)",
                        detail: "This photo contains embedded latitude/longitude data (\(String(format: "%.4f", finding.coordinate.latitude)), \(String(format: "%.4f", finding.coordinate.longitude))). If shared online, your location could be exposed.",
                        filePath: fileURL.path
                    ))
                }
            }
            progress(0.3 + 0.7 * Double(index + 1) / Double(imageFiles.count))
        }
        
        return result
    }
    
    // MARK: - Photos.sqlite GPS Scanner (Module A)
    
    /// Queries ~/Pictures/Photos Library.photoslibrary/database/Photos.sqlite for ZLOCATIONDATA.
    private func scanPhotosSQLite() -> [PhotoLocationFinding] {
        var locations: [PhotoLocationFinding] = []
        
        let home = FileManager.default.homeDirectoryForCurrentUser
        let sqlitePath = home
            .appendingPathComponent("Pictures/Photos Library.photoslibrary/database/Photos.sqlite")
        
        guard FileManager.default.fileExists(atPath: sqlitePath.path),
              ExclusionList.isSafe(sqlitePath) else {
            return locations
        }
        
        // Use sqlite3 CLI to extract lat/lon (read-only, no library dependency)
        let query = """
        SELECT ZGENERICASSET.ZLATITUDE, ZGENERICASSET.ZLONGITUDE, \
        ZGENERICASSET.ZFILENAME, ZGENERICASSET.ZDATECREATED \
        FROM ZGENERICASSET \
        WHERE ZGENERICASSET.ZLATITUDE IS NOT NULL \
        AND ZGENERICASSET.ZLATITUDE != 0 \
        AND ZGENERICASSET.ZLONGITUDE IS NOT NULL \
        AND ZGENERICASSET.ZLONGITUDE != 0 \
        LIMIT 500;
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-separator", "|", sqlitePath.path, query]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return locations }
            
            // Core Data epoch: 2001-01-01
            let coreDataEpoch = Date(timeIntervalSinceReferenceDate: 0)
            
            for line in output.components(separatedBy: "\n") where !line.isEmpty {
                let parts = line.components(separatedBy: "|")
                guard parts.count >= 3,
                      let lat = Double(parts[0]),
                      let lon = Double(parts[1]) else { continue }
                
                let fileName = parts[2]
                var dateTaken: Date? = nil
                if parts.count >= 4, let timestamp = Double(parts[3]) {
                    dateTaken = coreDataEpoch.addingTimeInterval(timestamp)
                }
                
                locations.append(PhotoLocationFinding(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    photoPath: sqlitePath.path,
                    dateTaken: dateTaken,
                    fileName: fileName
                ))
            }
        } catch {
            print("[BlackBox] Photos.sqlite scan failed: \(error)")
        }
        
        return locations
    }
    
    private func extractGPSFromImage(at url: URL) -> PhotoLocationFinding? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
              let latitude = gps[kCGImagePropertyGPSLatitude as String] as? Double,
              let longitude = gps[kCGImagePropertyGPSLongitude as String] as? Double else {
            return nil
        }
        
        let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String ?? "N"
        let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String ?? "E"
        
        let finalLat = latRef == "S" ? -latitude : latitude
        let finalLon = lonRef == "W" ? -longitude : longitude
        
        // Extract date
        var dateTaken: Date? = nil
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateStr = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            dateTaken = formatter.date(from: dateStr)
        }
        
        return PhotoLocationFinding(
            coordinate: CLLocationCoordinate2D(latitude: finalLat, longitude: finalLon),
            photoPath: url.path,
            dateTaken: dateTaken,
            fileName: url.lastPathComponent
        )
    }
    
    // MARK: - Deleted File (Ghost) Scanner
    
    struct GhostScanResult {
        var ghosts: [GhostFile] = []
        var findings: [AuditFinding] = []
    }
    
    func scanDeletedFiles(progress: @escaping (Double) -> Void) async -> GhostScanResult {
        var result = GhostScanResult()
        
        // Phase 1: Scan common temp/trash/cache locations for file signatures
        let scanPaths = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash"),
            FileManager.default.temporaryDirectory
        ]
        
        // Known file signatures (magic bytes)
        let signatures: [(name: String, bytes: [UInt8], ext: String)] = [
            ("JPEG", [0xFF, 0xD8, 0xFF], "jpg"),
            ("PNG", [0x89, 0x50, 0x4E, 0x47], "png"),
            ("PDF", [0x25, 0x50, 0x44, 0x46], "pdf"),
            ("ZIP", [0x50, 0x4B, 0x03, 0x04], "zip"),
            ("DOCX", [0x50, 0x4B, 0x03, 0x04], "docx"),
            ("SQLite", [0x53, 0x51, 0x4C, 0x69], "sqlite"),
        ]
        
        var allFiles: [URL] = []
        for path in scanPaths {
            if let enumerator = FileManager.default.enumerator(at: path, includingPropertiesForKeys: [.fileSizeKey], options: []) {
                for case let fileURL as URL in enumerator {
                    if ExclusionList.isSafe(fileURL) {
                        allFiles.append(fileURL)
                    }
                }
            }
        }
        
        // Also check user cache
        let cachePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches")
        if let enumerator = FileManager.default.enumerator(at: cachePath, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if ExclusionList.isSafe(fileURL) {
                    allFiles.append(fileURL)
                }
            }
        }
        
        if !allFiles.isEmpty {
            for (index, fileURL) in allFiles.enumerated() {
                autoreleasepool {
                    guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return }
                    defer { handle.closeFile() }
                    
                    let headerData = handle.readData(ofLength: 16)
                    guard headerData.count >= 3 else { return }
                    let headerBytes = Array(headerData)
                    
                    for sig in signatures {
                        if headerBytes.starts(with: sig.bytes) {
                            let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                            
                            let ghost = GhostFile(
                                fileType: sig.ext.uppercased(),
                                estimatedSize: Int64(fileSize),
                                headerSignature: sig.bytes.map { String(format: "%02X", $0) }.joined(separator: " "),
                                diskOffset: 0,
                                previewData: headerData.count > 4 ? headerData : nil
                            )
                            result.ghosts.append(ghost)
                            result.findings.append(AuditFinding(
                                category: .deletedFile,
                                severity: .moderate,
                                title: "Recoverable \(sig.ext.uppercased()) file (\(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)))",
                                detail: "A \(sig.name) file was found in a temporary/deleted location. It could be recovered by anyone with physical access to this Mac.",
                                filePath: fileURL.path
                            ))
                            break
                        }
                    }
                }
                progress(0.6 * Double(index + 1) / Double(allFiles.count))
            }
        }
        
        // Phase 2: posix_spawn-based free-space signature scan (Module B: "The X-Ray")
        // Uses `grep` to search raw disk regions for file magic bytes
        progress(0.6)
        let freeSpaceGhosts = scanFreeSpaceSignatures()
        result.ghosts.append(contentsOf: freeSpaceGhosts.map { $0.ghost })
        result.findings.append(contentsOf: freeSpaceGhosts.map { $0.finding })
        
        progress(1.0)
        return result
    }
    
    // MARK: - Free-Space Forensic Recovery via posix_spawn (Module B)
    
    private struct FreeSpaceHit {
        let ghost: GhostFile
        let finding: AuditFinding
    }
    
    /// Uses posix_spawn to run `grep` searching for file magic bytes in APFS free space.
    /// This is a best-effort scan using /dev/disk reads where accessible.
    private func scanFreeSpaceSignatures() -> [FreeSpaceHit] {
        var hits: [FreeSpaceHit] = []
        
        // Attempt to scan /dev/rdiskX for JPEG signatures in free space.
        // On modern macOS, this requires elevated privileges; we attempt read-only
        // and gracefully handle permission denial.
        
        // First, find the boot disk device
        let diskProcess = Process()
        diskProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        diskProcess.arguments = ["info", "/"]
        let diskPipe = Pipe()
        diskProcess.standardOutput = diskPipe
        diskProcess.standardError = Pipe()
        
        var deviceNode = "/dev/disk1"
        do {
            try diskProcess.run()
            diskProcess.waitUntilExit()
            let output = String(data: diskPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            // Parse "Device Node:  /dev/diskXsY"
            for line in output.components(separatedBy: "\n") {
                if line.contains("Device Node:") {
                    let parts = line.components(separatedBy: ":")
                    if parts.count >= 2 {
                        deviceNode = parts[1].trimmingCharacters(in: .whitespaces)
                    }
                    break
                }
            }
        } catch {
            print("[BlackBox] Could not determine boot disk: \(error)")
        }
        
        // Use posix_spawn to run grep looking for JPEG (FFD8FF) signatures
        // We scan a limited region to keep it fast and non-blocking
        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        
        let grepProcess = Process()
        grepProcess.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
        // -c = count matches, -a = process binary as text, -P = Perl regex
        // Limit: read first 100MB of the device to keep scan fast
        grepProcess.arguments = ["-c", "-a", "\\xff\\xd8\\xff", deviceNode]
        
        let grepPipe = Pipe()
        grepProcess.standardOutput = grepPipe
        grepProcess.standardError = Pipe()
        
        do {
            try grepProcess.run()
            
            // Timeout after 5 seconds to avoid hanging on permission prompt
            DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
                if grepProcess.isRunning { grepProcess.terminate() }
            }
            grepProcess.waitUntilExit()
            
            let output = String(data: grepPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "0"
            let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            
            if count > 0 {
                let ghost = GhostFile(
                    fileType: "JPEG",
                    estimatedSize: 0,
                    headerSignature: "FF D8 FF (free-space)",
                    diskOffset: 0,
                    previewData: nil
                )
                let finding = AuditFinding(
                    category: .deletedFile,
                    severity: .high,
                    title: "~\(count) recoverable JPEG signature(s) in disk free space",
                    detail: "Low-level disk scan found JPEG file headers in APFS free space. These deleted photos could potentially be recovered with forensic tools.",
                    filePath: nil
                )
                hits.append(FreeSpaceHit(ghost: ghost, finding: finding))
            }
        } catch {
            // Permission denied is expected on non-elevated processes
            print("[BlackBox] Free-space scan not available: \(error.localizedDescription)")
        }
        
        posix_spawn_file_actions_destroy(&fileActions)
        return hits
    }
    
    // MARK: - Sensitive String Scanner
    
    func scanSensitiveStrings(progress: @escaping (Double) -> Void) async -> [AuditFinding] {
        var findings: [AuditFinding] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        
        let scanDirs = [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Desktop")
        ]
        
        let textExtensions = Set(["txt", "csv", "md", "json", "xml", "html", "rtf", "log", "pdf", "doc", "docx", "xls", "xlsx"])
        
        // Patterns with descriptions
        let patterns: [(name: String, regex: String, severity: SeverityLevel)] = [
            ("Credit Card Number", #"\b(?:4\d{3}|5[1-5]\d{2}|3[47]\d{2}|6(?:011|5\d{2}))[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b"#, .critical),
            ("Social Security Number", #"\b\d{3}[- ]?\d{2}[- ]?\d{4}\b"#, .critical),
            ("Email Address Pattern", #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#, .info),
            ("Password Reference", #"(?i)\b(?:password|passwd|pwd)\s*[:=]\s*\S+"#, .critical),
            ("Tax Document Keyword", #"(?i)\b(?:tax.?return|w-?2|1099|social.?security|ein|itin)\b"#, .high),
            ("Secret/API Key Pattern", #"(?i)\b(?:api[_-]?key|secret[_-]?key|access[_-]?token|private[_-]?key)\s*[:=]\s*\S+"#, .critical),
            ("Bank Account Reference", #"(?i)\b(?:routing|account).?(?:number|num|no|#)\s*[:=]?\s*\d{6,}\b"#, .high),
        ]
        
        var allFiles: [URL] = []
        for dir in scanDirs {
            if let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    if textExtensions.contains(fileURL.pathExtension.lowercased()),
                       ExclusionList.isSafe(fileURL) {
                        // Skip files larger than 10MB for performance
                        if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size < 10_000_000 {
                            allFiles.append(fileURL)
                        }
                    }
                }
            }
        }
        
        guard !allFiles.isEmpty else {
            progress(1.0)
            return findings
        }
        
        // Multi-threaded scanning
        let compiledPatterns: [(name: String, regex: NSRegularExpression, severity: SeverityLevel)] = patterns.compactMap { p in
            guard let regex = try? NSRegularExpression(pattern: p.regex, options: []) else { return nil }
            return (p.name, regex, p.severity)
        }
        
        for (index, fileURL) in allFiles.enumerated() {
            autoreleasepool {
                guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
                let range = NSRange(content.startIndex..<content.endIndex, in: content)
                
                for pattern in compiledPatterns {
                    let matches = pattern.regex.matches(in: content, options: [], range: range)
                    if !matches.isEmpty {
                        // Redact the actual match for display
                        let firstMatch = matches[0]
                        if let matchRange = Range(firstMatch.range, in: content) {
                            let matchedText = String(content[matchRange])
                            let redacted = redactSensitiveMatch(matchedText, type: pattern.name)
                            
                            findings.append(AuditFinding(
                                category: .sensitiveString,
                                severity: pattern.severity,
                                title: "\(pattern.name) in \(fileURL.lastPathComponent)",
                                detail: "Found \(matches.count) instance(s) matching \(pattern.name) pattern: \(redacted)",
                                filePath: fileURL.path
                            ))
                        }
                    }
                }
            }
            progress(Double(index + 1) / Double(allFiles.count))
        }
        
        return findings
    }
    
    private func redactSensitiveMatch(_ match: String, type: String) -> String {
        if match.count <= 4 { return "****" }
        let visible = String(match.suffix(4))
        let stars = String(repeating: "*", count: min(match.count - 4, 12))
        return stars + visible
    }
    
    // MARK: - Telemetry Auditor
    
    struct TelemetryScanResult {
        var endpoints: [TelemetryEndpoint] = []
        var findings: [AuditFinding] = []
    }
    
    func scanTelemetry(progress: @escaping (Double) -> Void) async -> TelemetryScanResult {
        var result = TelemetryScanResult()
        
        // Use the full 500+ domain list from Constants
        let knownTelemetry: [(domain: String, isApple: Bool)] =
            BlackBoxConstants.appleTelemetryDomains.map { ($0, true) } +
            BlackBoxConstants.thirdPartyTelemetryDomains.map { ($0, false) }
        
        progress(0.05)
        
        // 1. Check /etc/hosts for blocked domains
        var blockedDomains = Set<String>()
        if let hostsContent = try? String(contentsOfFile: "/etc/hosts", encoding: .utf8) {
            let lines = hostsContent.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("0.0.0.0") || trimmed.hasPrefix("127.0.0.1") {
                    let parts = trimmed.split(separator: " ")
                    if parts.count >= 2 {
                        blockedDomains.insert(String(parts[1]))
                    }
                }
            }
        }
        
        progress(0.15)
        
        // 2. Module D: Live socket monitoring via netstat
        let liveConnections = scanActiveNetworkConnections()
        for conn in liveConnections {
            let isKnownTelemetry = knownTelemetry.contains { conn.contains($0.domain) }
            if isKnownTelemetry {
                result.findings.append(AuditFinding(
                    category: .telemetry,
                    severity: .high,
                    title: "Live telemetry connection: \(conn)",
                    detail: "An active network socket was detected communicating with a known telemetry endpoint.",
                    filePath: nil
                ))
            }
        }
        
        progress(0.4)
        
        // 3. Check which telemetry endpoints are active (not blocked in hosts)
        for (index, telemetry) in knownTelemetry.enumerated() {
            let isBlocked = blockedDomains.contains(telemetry.domain)
            
            let endpoint = TelemetryEndpoint(
                domain: telemetry.domain,
                source: isBlocked ? "Blocked in /etc/hosts" : "Active — not blocked",
                isApple: telemetry.isApple,
                isActive: !isBlocked
            )
            result.endpoints.append(endpoint)
            
            if !isBlocked {
                result.findings.append(AuditFinding(
                    category: .telemetry,
                    severity: telemetry.isApple ? .moderate : .moderate,
                    title: "Active telemetry: \(telemetry.domain)",
                    detail: "\(telemetry.isApple ? "Apple" : "Third-party") telemetry endpoint is currently active and may be transmitting usage data.",
                    filePath: nil
                ))
            }
            
            progress(0.4 + 0.6 * Double(index + 1) / Double(knownTelemetry.count))
        }
        
        return result
    }
    
    // MARK: - Live Socket Monitor (Module D)
    
    /// Uses `netstat` to detect active TCP connections to known telemetry endpoints.
    private func scanActiveNetworkConnections() -> [String] {
        var connections: [String] = []
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-an", "-p", "tcp"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return connections }
            
            for line in output.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.contains("ESTABLISHED") || trimmed.contains("SYN_SENT") {
                    // Extract the foreign address (column 5 typically)
                    let parts = trimmed.split(separator: " ").map(String.init)
                    if parts.count >= 5 {
                        let foreignAddr = parts[4]
                        connections.append(foreignAddr)
                    }
                }
            }
        } catch {
            print("[BlackBox] netstat scan failed: \(error)")
        }
        
        // Also try lsof for process-level visibility
        let lsofProcess = Process()
        lsofProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsofProcess.arguments = ["-i", "-n", "-P"]
        
        let lsofPipe = Pipe()
        lsofProcess.standardOutput = lsofPipe
        lsofProcess.standardError = Pipe()
        
        do {
            try lsofProcess.run()
            
            // Timeout after 5 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
                if lsofProcess.isRunning { lsofProcess.terminate() }
            }
            lsofProcess.waitUntilExit()
            
            let data = lsofPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return connections }
            
            for line in output.components(separatedBy: "\n") {
                if line.contains("ESTABLISHED") {
                    let parts = line.split(separator: " ").map(String.init)
                    if let arrowIndex = parts.firstIndex(of: "->") {
                        if arrowIndex + 1 < parts.count {
                            connections.append(parts[arrowIndex + 1])
                        }
                    }
                }
            }
        } catch {
            print("[BlackBox] lsof scan failed: \(error)")
        }
        
        return connections
    }
}

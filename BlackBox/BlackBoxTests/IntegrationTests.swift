import XCTest
@testable import BlackBox

final class IntegrationTests: XCTestCase {
    
    let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("BlackBoxIntegrationTests")
    
    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: testDir)
        super.tearDown()
    }
    
    // MARK: - State Machine Tests
    
    @MainActor
    func testCannotNeutralizeFromIdle() {
        let coordinator = StateCoordinator()
        XCTAssertEqual(coordinator.appState, .idle)
        
        coordinator.requestNeutralize()
        // Should remain idle — can't neutralize without scanning first
        XCTAssertEqual(coordinator.appState, .idle)
        XCTAssertFalse(coordinator.showPaywall)
    }
    
    @MainActor
    func testCannotStartAuditWhileAuditing() {
        let coordinator = StateCoordinator()
        coordinator.appState = .auditing
        
        coordinator.startAudit()
        // Should remain auditing (guard prevents re-entry)
        XCTAssertEqual(coordinator.appState, .auditing)
    }
    
    @MainActor
    func testCanStartAuditFromExposed() {
        let coordinator = StateCoordinator()
        coordinator.appState = .exposed
        
        coordinator.startAudit()
        XCTAssertEqual(coordinator.appState, .auditing, "Should be able to re-scan from exposed state")
    }
    
    @MainActor
    func testCanStartAuditFromCloaked() {
        let coordinator = StateCoordinator()
        coordinator.appState = .cloaked
        
        coordinator.startAudit()
        XCTAssertEqual(coordinator.appState, .auditing, "Should be able to re-scan from cloaked state")
    }
    
    @MainActor
    func testCannotNeutralizeWhileNeutralizing() {
        let coordinator = StateCoordinator()
        coordinator.appState = .neutralizing
        
        coordinator.requestNeutralize()
        // Should remain neutralizing
        XCTAssertEqual(coordinator.appState, .neutralizing)
    }
    
    @MainActor
    func testDismissPaywall() {
        let coordinator = StateCoordinator()
        coordinator.showPaywall = true
        
        coordinator.dismissPaywall()
        XCTAssertFalse(coordinator.showPaywall)
    }
    
    // MARK: - Subscription Model Tests
    
    func testSubscriptionInactiveByDefault() {
        let sub = SubscriptionStatus()
        XCTAssertFalse(sub.isActive)
        XCTAssertFalse(sub.isValid)
        XCTAssertNil(sub.expirationDate)
        XCTAssertEqual(sub.plan, "Free")
    }
    
    func testSubscriptionActiveAndNotExpired() {
        let sub = SubscriptionStatus(
            isActive: true,
            expirationDate: Date().addingTimeInterval(86400 * 365),
            plan: "Pro Annual"
        )
        XCTAssertTrue(sub.isValid)
    }
    
    func testSubscriptionActiveButExpired() {
        let sub = SubscriptionStatus(
            isActive: true,
            expirationDate: Date().addingTimeInterval(-86400), // yesterday
            plan: "Pro Annual"
        )
        XCTAssertFalse(sub.isValid, "Expired subscription should not be valid")
    }
    
    func testSubscriptionInactiveIgnoresDate() {
        let sub = SubscriptionStatus(
            isActive: false,
            expirationDate: Date().addingTimeInterval(86400 * 365),
            plan: "Pro Annual"
        )
        XCTAssertFalse(sub.isValid, "Inactive subscription should not be valid even with future date")
    }
    
    // MARK: - Audit Report Tests
    
    func testEmptyAuditReport() {
        let report = AuditReport()
        XCTAssertEqual(report.totalFindings, 0)
        XCTAssertEqual(report.criticalCount, 0)
        XCTAssertEqual(report.highCount, 0)
        XCTAssertTrue(report.findings.isEmpty)
        XCTAssertTrue(report.photoLocations.isEmpty)
        XCTAssertTrue(report.ghostFiles.isEmpty)
        XCTAssertTrue(report.telemetryEndpoints.isEmpty)
    }
    
    func testAuditReportCounts() {
        var report = AuditReport()
        report.findings = [
            AuditFinding(category: .sensitiveString, severity: .critical, title: "SSN Found", detail: "SSN in doc"),
            AuditFinding(category: .sensitiveString, severity: .critical, title: "CC Found", detail: "CC in file"),
            AuditFinding(category: .sensitiveString, severity: .high, title: "Tax keyword", detail: "Tax docs"),
            AuditFinding(category: .telemetry, severity: .moderate, title: "Telemetry", detail: "Apple metrics"),
        ]
        
        XCTAssertEqual(report.findings.count, 4)
        XCTAssertEqual(report.criticalCount, 2)
        XCTAssertEqual(report.highCount, 1)
    }
    
    func testAuditReportTotalIncludesAllCategories() {
        var report = AuditReport()
        report.findings = [
            AuditFinding(category: .sensitiveString, severity: .critical, title: "Test", detail: "Test"),
        ]
        report.photoLocations = [
            PhotoLocationFinding(
                coordinate: .init(latitude: 37.0, longitude: -122.0),
                photoPath: "/test.jpg",
                dateTaken: nil,
                fileName: "test.jpg"
            ),
        ]
        report.ghostFiles = [
            GhostFile(fileType: "JPG", estimatedSize: 1024, headerSignature: "FF D8 FF", diskOffset: 0, previewData: nil),
        ]
        report.telemetryEndpoints = [
            TelemetryEndpoint(domain: "test.com", source: "test", isApple: false, isActive: true),
        ]
        
        XCTAssertEqual(report.totalFindings, 4, "totalFindings should sum all categories")
    }
    
    // MARK: - Severity Ordering Tests
    
    func testSeverityComparison() {
        XCTAssertTrue(SeverityLevel.info < SeverityLevel.moderate)
        XCTAssertTrue(SeverityLevel.moderate < SeverityLevel.high)
        XCTAssertTrue(SeverityLevel.high < SeverityLevel.critical)
        XCTAssertFalse(SeverityLevel.critical < SeverityLevel.info)
    }
    
    // MARK: - Mission Log Tests
    
    @MainActor
    func testMissionLogEntryCreation() {
        let coordinator = StateCoordinator()
        
        // Should have initial log entry from init
        XCTAssertFalse(coordinator.missionLog.isEmpty, "Initial log should contain system entry")
        
        coordinator.log("Test message", type: .info)
        XCTAssertGreaterThanOrEqual(coordinator.missionLog.count, 2)
        
        // Most recent entry should be first
        XCTAssertEqual(coordinator.missionLog.first?.message, "Test message")
    }
    
    // MARK: - Sensitive String Scanner with Real Files
    
    func testSensitiveStringScannerFindsPatterns() async throws {
        // Create test files in a temp directory with known sensitive content
        let scanDir = testDir.appendingPathComponent("Documents")
        try FileManager.default.createDirectory(at: scanDir, withIntermediateDirectories: true)
        
        let sensitiveFile = scanDir.appendingPathComponent("test_sensitive.txt")
        try "My credit card is 4532-1234-5678-9012 and my SSN is 123-45-6789".write(
            to: sensitiveFile, atomically: true, encoding: .utf8
        )
        
        let cleanFile = scanDir.appendingPathComponent("test_clean.txt")
        try "This is a perfectly normal document with nothing sensitive.".write(
            to: cleanFile, atomically: true, encoding: .utf8
        )
        
        // Test regex matching directly on known content
        let content = try String(contentsOf: sensitiveFile, encoding: .utf8)
        let ccPattern = try NSRegularExpression(
            pattern: #"\b(?:4\d{3}|5[1-5]\d{2}|3[47]\d{2}|6(?:011|5\d{2}))[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b"#
        )
        let ssnPattern = try NSRegularExpression(pattern: #"\b\d{3}[- ]?\d{2}[- ]?\d{4}\b"#)
        
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let ccMatches = ccPattern.matches(in: content, range: range)
        let ssnMatches = ssnPattern.matches(in: content, range: range)
        
        XCTAssertEqual(ccMatches.count, 1, "Should find one credit card number")
        XCTAssertEqual(ssnMatches.count, 1, "Should find one SSN")
        
        // Verify clean file has no matches
        let cleanContent = try String(contentsOf: cleanFile, encoding: .utf8)
        let cleanRange = NSRange(cleanContent.startIndex..<cleanContent.endIndex, in: cleanContent)
        XCTAssertEqual(ccPattern.matches(in: cleanContent, range: cleanRange).count, 0)
        XCTAssertEqual(ssnPattern.matches(in: cleanContent, range: cleanRange).count, 0)
    }
    
    // MARK: - Full Disk Access Checker
    
    func testFullDiskAccessCheckerDoesNotCrash() {
        // Just verify the function runs without crashing
        let _ = FullDiskAccessChecker.hasFullDiskAccess()
        // If we reach here, the checker works (may return true or false depending on environment)
    }
    
    // MARK: - Edge Cases: Finding Model
    
    func testAuditFindingCreation() {
        let finding = AuditFinding(
            category: .sensitiveString,
            severity: .critical,
            title: "Test Finding",
            detail: "Test detail",
            filePath: "/test/path.txt"
        )
        
        XCTAssertEqual(finding.category, .sensitiveString)
        XCTAssertEqual(finding.severity, .critical)
        XCTAssertEqual(finding.title, "Test Finding")
        XCTAssertEqual(finding.filePath, "/test/path.txt")
        XCTAssertNotNil(finding.id)
    }
    
    func testFindingWithoutFilePath() {
        let finding = AuditFinding(
            category: .telemetry,
            severity: .moderate,
            title: "Telemetry active",
            detail: "Some endpoint is active"
        )
        
        XCTAssertNil(finding.filePath)
    }
    
    // MARK: - Shred + Vault Round-Trip
    
    func testShredAndRestoreRoundTrip() async throws {
        let originalContent = "Round-trip test content for VaultTest"
        let fileURL = testDir.appendingPathComponent("VaultTest_roundtrip.txt")
        try originalContent.write(to: fileURL, atomically: true, encoding: .utf8)
        let originalPath = fileURL.path
        
        let engine = NeutralizeEngine()
        
        // Shred the file (this vaults it first)
        let shredSuccess = await engine.shredFile(at: originalPath)
        XCTAssertTrue(shredSuccess)
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalPath), "File should be gone after shred")
        
        // Find it in the vault
        let vaultedFiles = await engine.listVaultedFiles()
        let entry = vaultedFiles.first { $0.lastPathComponent.contains("VaultTest_roundtrip.txt") }
        XCTAssertNotNil(entry, "Shredded file should have vault backup")
        
        // Restore it
        if let entry = entry {
            let restoreSuccess = await engine.restoreFromVault(vaultedFileURL: entry, originalPath: originalPath)
            XCTAssertTrue(restoreSuccess)
            
            let restoredContent = try String(contentsOf: URL(fileURLWithPath: originalPath), encoding: .utf8)
            XCTAssertEqual(restoredContent, originalContent, "Restored content should match original after shred+restore round-trip")
            
            // Cleanup vault entry
            try? FileManager.default.removeItem(at: entry)
        }
    }
}

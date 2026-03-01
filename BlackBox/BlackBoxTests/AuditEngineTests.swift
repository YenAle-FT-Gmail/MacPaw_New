import XCTest
@testable import BlackBox

final class AuditEngineTests: XCTestCase {
    
    let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("BlackBoxAuditTests")
    
    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: testDir)
        super.tearDown()
    }
    
    // MARK: - Sensitive String Pattern Tests
    
    func testCreditCardPatternDetection() {
        let patterns = [
            ("Visa", "4532-1234-5678-9012"),
            ("Mastercard", "5412 7534 5678 9012"),
            ("Discover", "6011-1234-5678-9012"),
        ]
        
        let ccRegex = try! NSRegularExpression(
            pattern: #"\b(?:4\d{3}|5[1-5]\d{2}|3[47]\d{2}|6(?:011|5\d{2}))[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b"#
        )
        
        for (name, number) in patterns {
            let range = NSRange(number.startIndex..<number.endIndex, in: number)
            let matches = ccRegex.matches(in: number, range: range)
            XCTAssertGreaterThan(matches.count, 0, "\(name) pattern should be detected: \(number)")
        }
    }
    
    func testSSNPatternDetection() {
        let ssns = ["123-45-6789", "123 45 6789", "123456789"]
        let ssnRegex = try! NSRegularExpression(pattern: #"\b\d{3}[- ]?\d{2}[- ]?\d{4}\b"#)
        
        for ssn in ssns {
            let range = NSRange(ssn.startIndex..<ssn.endIndex, in: ssn)
            let matches = ssnRegex.matches(in: ssn, range: range)
            XCTAssertGreaterThan(matches.count, 0, "SSN pattern should match: \(ssn)")
        }
    }
    
    func testPasswordPatternDetection() {
        let texts = [
            "password: mySecret123",
            "Password=admin",
            "pwd: test1234",
        ]
        
        let pwRegex = try! NSRegularExpression(pattern: #"(?i)\b(?:password|passwd|pwd)\s*[:=]\s*\S+"#)
        
        for text in texts {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = pwRegex.matches(in: text, range: range)
            XCTAssertGreaterThan(matches.count, 0, "Password pattern should match: \(text)")
        }
    }
    
    func testNonSensitiveTextNotFlagged() {
        let safeTexts = [
            "The weather is nice today.",
            "Call me at 555-0123.",
            "Meeting at 3pm.",
        ]
        
        let ccRegex = try! NSRegularExpression(
            pattern: #"\b(?:4\d{3}|5[1-5]\d{2}|3[47]\d{2}|6(?:011|5\d{2}))[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b"#
        )
        
        for text in safeTexts {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = ccRegex.matches(in: text, range: range)
            XCTAssertEqual(matches.count, 0, "Safe text should not trigger CC pattern: \(text)")
        }
    }
    
    // MARK: - File Signature Tests
    
    func testJPEGSignatureDetection() {
        let jpegHeader: [UInt8] = [0xFF, 0xD8, 0xFF, 0xE0]
        let data = Data(jpegHeader)
        let sig: [UInt8] = [0xFF, 0xD8, 0xFF]
        XCTAssertTrue(Array(data).starts(with: sig), "JPEG signature should be detected")
    }
    
    func testPDFSignatureDetection() {
        let pdfHeader = "%PDF-1.4".data(using: .utf8)!
        let sig: [UInt8] = [0x25, 0x50, 0x44, 0x46] // %PDF
        XCTAssertTrue(Array(pdfHeader).starts(with: sig), "PDF signature should be detected")
    }
    
    func testPNGSignatureDetection() {
        let pngHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        let sig: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        XCTAssertTrue(pngHeader.starts(with: sig), "PNG signature should be detected")
    }
    
    // MARK: - State Coordinator Tests
    
    @MainActor
    func testStateTransitions() {
        let coordinator = StateCoordinator()
        
        XCTAssertEqual(coordinator.appState, .idle)
        
        // Starting audit from idle should work
        coordinator.startAudit()
        XCTAssertEqual(coordinator.appState, .auditing)
    }
    
    @MainActor
    func testNeutralizeRequiresSubscription() {
        let coordinator = StateCoordinator()
        coordinator.appState = .exposed
        
        // Without subscription, should show paywall
        coordinator.requestNeutralize()
        XCTAssertTrue(coordinator.showPaywall, "Paywall should appear without active subscription")
    }
    
    @MainActor
    func testNeutralizeWithSubscription() {
        let coordinator = StateCoordinator()
        coordinator.appState = .exposed
        coordinator.subscription = SubscriptionStatus(
            isActive: true,
            expirationDate: Date().addingTimeInterval(86400),
            plan: "Pro Annual"
        )
        
        coordinator.requestNeutralize()
        XCTAssertFalse(coordinator.showPaywall, "Paywall should NOT appear with active subscription")
        XCTAssertEqual(coordinator.appState, .neutralizing, "Should transition to neutralizing")
    }
}

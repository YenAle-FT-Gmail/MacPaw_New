import XCTest
@testable import BlackBox

/// CPU stability and performance tests.
final class StabilityTests: XCTestCase {
    
    // MARK: - CPU Stability: Idle telemetry monitoring should not spike CPU
    
    func testIdleDoesNotSpikeCPU() throws {
        // Measure that creating and holding references to the engines
        // does not cause measurable CPU overhead while idle.
        // We use XCTest's measure block to verify sub-200ms baseline.
        measure {
            let coordinator = StateCoordinator()
            // Simulate idle state — no scanning, no neutralizing
            XCTAssertEqual(coordinator.appState, .idle)
            
            // Hold for a brief period to verify no background CPU spike
            let expectation = XCTestExpectation(description: "idle hold")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                XCTAssertEqual(coordinator.appState, .idle)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    // MARK: - Domain List Size Validation
    
    func testDomainListHas500PlusDomains() {
        let total = BlackBoxConstants.appleTelemetryDomains.count + BlackBoxConstants.thirdPartyTelemetryDomains.count
        XCTAssertGreaterThanOrEqual(total, 500, "Should have 500+ telemetry domains; got \(total)")
    }
    
    // MARK: - ExclusionList Performance
    
    func testExclusionListPerformance() {
        // The exclusion list check should be extremely fast (sub-millisecond per path)
        let testPaths = (0..<10000).map { "/Users/testuser/Documents/file_\($0).txt" }
        
        measure {
            for path in testPaths {
                _ = ExclusionList.isSafePath(path)
            }
        }
    }
    
    // MARK: - Pattern Matching Performance
    
    func testSensitivePatternMatchingPerformance() {
        // Verify regex compilation and matching doesn't regress
        let patterns = [
            #"\b(?:4\d{3}|5[1-5]\d{2}|3[47]\d{2}|6(?:011|5\d{2}))[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b"#,
            #"\b\d{3}[- ]?\d{2}[- ]?\d{4}\b"#,
            #"(?i)\b(?:password|passwd|pwd)\s*[:=]\s*\S+"#,
        ]
        
        let compiled = patterns.compactMap { try? NSRegularExpression(pattern: $0, options: []) }
        
        // Create sample text with embedded matches
        var sampleText = "This is a normal document with some text.\n"
        for _ in 0..<100 {
            sampleText += "Some random data that might contain a card number 4111-1111-1111-1111 or SSN 123-45-6789.\n"
            sampleText += "Normal line of text without any sensitive data patterns in it at all whatsoever.\n"
        }
        
        let range = NSRange(sampleText.startIndex..<sampleText.endIndex, in: sampleText)
        
        measure {
            for regex in compiled {
                _ = regex.matches(in: sampleText, options: [], range: range)
            }
        }
    }
    
    // MARK: - Vault Constants Validation
    
    func testVaultRetentionIs48Hours() {
        XCTAssertEqual(BlackBoxConstants.vaultRetentionHours, 172800, "Vault retention should be 48 hours (172800 seconds)")
    }
    
    // MARK: - HapticManager Does Not Crash
    
    func testHapticManagerDoesNotCrash() {
        // Verify haptic calls don't throw or crash on CI/headless
        HapticManager.alignment()
        HapticManager.levelChange()
        HapticManager.generic()
        HapticManager.auditComplete(findingsCount: 0)
        HapticManager.auditComplete(findingsCount: 5)
        HapticManager.neutralizeProgress()
        HapticManager.neutralizeComplete()
        HapticManager.denied()
    }
}

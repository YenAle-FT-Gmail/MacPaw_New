import XCTest
@testable import BlackBox

final class TelemetryTests: XCTestCase {
    
    // MARK: - Hosts File Parsing Tests
    
    func testHostsFileBlockedDomainDetection() {
        // Simulate /etc/hosts content
        let hostsContent = """
        # Standard entries
        127.0.0.1 localhost
        255.255.255.255 broadcasthost
        ::1 localhost
        
        # Blocked telemetry
        0.0.0.0 metrics.apple.com
        0.0.0.0 telemetry.apple.com
        127.0.0.1 dc.services.visualstudio.com
        """
        
        var blockedDomains = Set<String>()
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
        
        XCTAssertTrue(blockedDomains.contains("metrics.apple.com"))
        XCTAssertTrue(blockedDomains.contains("telemetry.apple.com"))
        XCTAssertTrue(blockedDomains.contains("dc.services.visualstudio.com"))
        XCTAssertTrue(blockedDomains.contains("localhost")) // localhost is also a 127.0.0.1 entry
        XCTAssertFalse(blockedDomains.contains("broadcasthost")) // 255.x.x.x isn't blocked
    }
    
    func testHostsFileCommentLinesIgnored() {
        let hostsContent = """
        # 0.0.0.0 should.be.ignored.com
        # This is a comment
        0.0.0.0 actually.blocked.com
        """
        
        var blockedDomains = Set<String>()
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
        
        XCTAssertFalse(blockedDomains.contains("should.be.ignored.com"), "Comment lines should be ignored")
        XCTAssertTrue(blockedDomains.contains("actually.blocked.com"))
    }
    
    func testEmptyHostsFile() {
        let hostsContent = ""
        var blockedDomains = Set<String>()
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
        XCTAssertTrue(blockedDomains.isEmpty)
    }
    
    // MARK: - Telemetry Endpoint Model Tests
    
    func testTelemetryEndpointActiveState() {
        let endpoint = TelemetryEndpoint(
            domain: "metrics.apple.com",
            source: "Active — not blocked",
            isApple: true,
            isActive: true
        )
        
        XCTAssertTrue(endpoint.isActive)
        XCTAssertTrue(endpoint.isApple)
        XCTAssertEqual(endpoint.domain, "metrics.apple.com")
    }
    
    func testTelemetryEndpointBlockedState() {
        let endpoint = TelemetryEndpoint(
            domain: "telemetry.apple.com",
            source: "Blocked in /etc/hosts",
            isApple: true,
            isActive: false
        )
        
        XCTAssertFalse(endpoint.isActive)
    }
    
    // MARK: - Host Blocker Entry Generation
    
    func testHostBlockerEntryFormat() {
        let endpoints = [
            TelemetryEndpoint(domain: "metrics.apple.com", source: "Active", isApple: true, isActive: true),
            TelemetryEndpoint(domain: "telemetry.firefox.com", source: "Active", isApple: false, isActive: true),
            TelemetryEndpoint(domain: "already.blocked.com", source: "Blocked", isApple: false, isActive: false),
        ]
        
        let activeEndpoints = endpoints.filter { $0.isActive }
        XCTAssertEqual(activeEndpoints.count, 2, "Only active endpoints should be selected for blocking")
        
        var entries = ""
        for endpoint in activeEndpoints {
            entries += "0.0.0.0 \(endpoint.domain)\n"
        }
        
        XCTAssertTrue(entries.contains("0.0.0.0 metrics.apple.com"))
        XCTAssertTrue(entries.contains("0.0.0.0 telemetry.firefox.com"))
        XCTAssertFalse(entries.contains("already.blocked.com"), "Already-blocked endpoints should not be re-added")
    }
    
    // MARK: - Telemetry Auditor Integration (reads real /etc/hosts)
    
    func testTelemetryAuditorReturnsResults() async {
        let engine = AuditEngine()
        let result = await engine.scanTelemetry { _ in }
        
        // Should always return some endpoints (the known list)
        XCTAssertGreaterThan(result.endpoints.count, 0, "Telemetry auditor should return known endpoints")
        
        // Every endpoint should have a non-empty domain
        for endpoint in result.endpoints {
            XCTAssertFalse(endpoint.domain.isEmpty, "Every endpoint should have a domain")
        }
    }
    
    func testTelemetryProgressCallbackFires() async {
        let engine = AuditEngine()
        var progressValues: [Double] = []
        
        let _ = await engine.scanTelemetry { progress in
            progressValues.append(progress)
        }
        
        XCTAssertGreaterThan(progressValues.count, 0, "Progress callback should fire during telemetry scan")
        
        if let last = progressValues.last {
            XCTAssertEqual(last, 1.0, accuracy: 0.01, "Final progress should be ~1.0")
        }
    }
    
    // MARK: - Known Domain List Coverage
    
    func testKnownAppleTelemetryDomainsAreChecked() async {
        let engine = AuditEngine()
        let result = await engine.scanTelemetry { _ in }
        
        let domains = Set(result.endpoints.map { $0.domain })
        
        // Verify key Apple domains are in the scan
        XCTAssertTrue(domains.contains("metrics.apple.com"))
        XCTAssertTrue(domains.contains("telemetry.apple.com"))
        XCTAssertTrue(domains.contains("analytics.apple.com"))
    }
    
    func testKnownThirdPartyDomainsAreChecked() async {
        let engine = AuditEngine()
        let result = await engine.scanTelemetry { _ in }
        
        let domains = Set(result.endpoints.map { $0.domain })
        
        XCTAssertTrue(domains.contains("dc.services.visualstudio.com"))
        XCTAssertTrue(domains.contains("vortex.data.microsoft.com"))
    }
}

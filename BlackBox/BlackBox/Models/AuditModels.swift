import Foundation
import CoreLocation

// MARK: - App State
enum AppState: String, CaseIterable {
    case idle = "Idle"
    case auditing = "Auditing"
    case exposed = "Exposed"
    case neutralizing = "Neutralizing"
    case cloaked = "Cloaked"
}

// MARK: - Audit Finding Types
enum FindingCategory: String, Codable, CaseIterable {
    case photoMetadata = "Photo Metadata"
    case deletedFile = "Recoverable File"
    case sensitiveString = "Sensitive Data"
    case telemetry = "Telemetry Endpoint"
}

enum SeverityLevel: String, Codable, Comparable {
    case info = "Info"
    case moderate = "Moderate"
    case high = "High"
    case critical = "Critical"
    
    private var rank: Int {
        switch self {
        case .info: return 0
        case .moderate: return 1
        case .high: return 2
        case .critical: return 3
        }
    }
    
    static func < (lhs: SeverityLevel, rhs: SeverityLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

// MARK: - Audit Findings
struct AuditFinding: Identifiable, Codable {
    let id: UUID
    let category: FindingCategory
    let severity: SeverityLevel
    let title: String
    let detail: String
    let filePath: String?
    let timestamp: Date
    
    init(category: FindingCategory, severity: SeverityLevel, title: String, detail: String, filePath: String? = nil) {
        self.id = UUID()
        self.category = category
        self.severity = severity
        self.title = title
        self.detail = detail
        self.filePath = filePath
        self.timestamp = Date()
    }
}

// MARK: - Photo Location Finding
struct PhotoLocationFinding: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let photoPath: String
    let dateTaken: Date?
    let fileName: String
}

// MARK: - Deleted File Ghost
struct GhostFile: Identifiable {
    let id = UUID()
    let fileType: String
    let estimatedSize: Int64
    let headerSignature: String
    let diskOffset: UInt64
    let previewData: Data?
}

// MARK: - Telemetry Endpoint
struct TelemetryEndpoint: Identifiable, Codable {
    let id = UUID()
    let domain: String
    let source: String // "hosts file", "daemon", etc.
    let isApple: Bool
    let isActive: Bool
}

// MARK: - Subscription
struct SubscriptionStatus {
    var isActive: Bool = false
    var expirationDate: Date? = nil
    var plan: String = "Free"
    
    var isValid: Bool {
        guard isActive, let exp = expirationDate else { return false }
        return exp > Date()
    }
}

// MARK: - Audit Report
struct AuditReport {
    var findings: [AuditFinding] = []
    var photoLocations: [PhotoLocationFinding] = []
    var ghostFiles: [GhostFile] = []
    var telemetryEndpoints: [TelemetryEndpoint] = []
    var scanDate: Date = Date()
    var scanDuration: TimeInterval = 0
    
    var totalFindings: Int {
        findings.count + photoLocations.count + ghostFiles.count + telemetryEndpoints.count
    }
    
    var criticalCount: Int {
        findings.filter { $0.severity == .critical }.count
    }
    
    var highCount: Int {
        findings.filter { $0.severity == .high }.count
    }
}

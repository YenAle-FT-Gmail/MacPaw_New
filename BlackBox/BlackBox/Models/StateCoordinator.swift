import Foundation
import SwiftUI
import Combine

/// Central state coordinator managing application flow and audit lifecycle.
/// Implements the state machine: Idle -> Auditing -> Exposed -> Neutralizing -> Cloaked
@MainActor
class StateCoordinator: ObservableObject {
    // MARK: - Published State
    @Published var appState: AppState = .idle
    @Published var auditReport: AuditReport = AuditReport()
    @Published var subscription: SubscriptionStatus = SubscriptionStatus()
    @Published var showPaywall: Bool = false
    @Published var scanProgress: Double = 0.0
    @Published var currentScanPhase: String = "Ready"
    @Published var neutralizeProgress: Double = 0.0
    @Published var missionLog: [MissionLogEntry] = []
    
    // MARK: - Engines
    let auditEngine = AuditEngine()
    let neutralizeEngine = NeutralizeEngine()
    
    // MARK: - Mission Log
    struct MissionLogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let type: LogType
        
        enum LogType {
            case info, warning, critical, success, system
        }
    }
    
    init() {
        log("BlackBox initialized. Standing by.", type: .system)
    }
    
    // MARK: - State Transitions
    
    func startAudit() {
        guard appState == .idle || appState == .cloaked || appState == .exposed else { return }
        appState = .auditing
        scanProgress = 0
        auditReport = AuditReport()
        log("Identity audit initiated.", type: .info)
        
        Task {
            await performAudit()
        }
    }
    
    func requestNeutralize() {
        guard appState == .exposed else { return }
        
        if subscription.isValid {
            beginNeutralize()
        } else {
            showPaywall = true
            log("Subscription required. Presenting upgrade options.", type: .system)
        }
    }
    
    func beginNeutralize() {
        appState = .neutralizing
        neutralizeProgress = 0
        log("Neutralization sequence started.", type: .info)
        
        Task {
            await performNeutralize()
        }
    }
    
    func dismissPaywall() {
        showPaywall = false
    }
    
    // MARK: - Audit Execution
    
    private func performAudit() async {
        let startTime = Date()
        
        // Phase 1: Photo Metadata (0-25%)
        currentScanPhase = "Scanning photo metadata..."
        log("Scanning photo library for embedded GPS coordinates...", type: .info)
        let photoFindings = await auditEngine.scanPhotoMetadata { progress in
            Task { @MainActor in
                self.scanProgress = progress * 0.25
            }
        }
        auditReport.photoLocations = photoFindings.locations
        auditReport.findings.append(contentsOf: photoFindings.findings)
        if !photoFindings.locations.isEmpty {
            log("\(photoFindings.locations.count) photos contain GPS coordinates.", type: .warning)
        }
        
        // Phase 2: Deleted File Recovery (25-50%)
        currentScanPhase = "Scanning for recoverable deleted files..."
        log("Analyzing free space for recoverable file signatures...", type: .info)
        let ghostFindings = await auditEngine.scanDeletedFiles { progress in
            Task { @MainActor in
                self.scanProgress = 0.25 + progress * 0.25
            }
        }
        auditReport.ghostFiles = ghostFindings.ghosts
        auditReport.findings.append(contentsOf: ghostFindings.findings)
        if !ghostFindings.ghosts.isEmpty {
            log("\(ghostFindings.ghosts.count) deleted files still recoverable on disk.", type: .warning)
        }
        
        // Phase 3: Sensitive Strings (50-75%)
        currentScanPhase = "Scanning documents for sensitive data patterns..."
        log("Running pattern analysis on documents...", type: .info)
        let stringFindings = await auditEngine.scanSensitiveStrings { progress in
            Task { @MainActor in
                self.scanProgress = 0.50 + progress * 0.25
            }
        }
        auditReport.findings.append(contentsOf: stringFindings)
        let sensitiveCount = stringFindings.filter { $0.severity >= .high }.count
        if sensitiveCount > 0 {
            log("\(sensitiveCount) high-severity sensitive data patterns detected.", type: .critical)
        }
        
        // Phase 4: Telemetry (75-100%)
        currentScanPhase = "Auditing system telemetry endpoints..."
        log("Checking active telemetry and tracking endpoints...", type: .info)
        let telemetryFindings = await auditEngine.scanTelemetry { progress in
            Task { @MainActor in
                self.scanProgress = 0.75 + progress * 0.25
            }
        }
        auditReport.telemetryEndpoints = telemetryFindings.endpoints
        auditReport.findings.append(contentsOf: telemetryFindings.findings)
        if !telemetryFindings.endpoints.isEmpty {
            log("\(telemetryFindings.endpoints.count) active telemetry endpoints identified.", type: .warning)
        }
        
        // Complete
        scanProgress = 1.0
        auditReport.scanDuration = Date().timeIntervalSince(startTime)
        auditReport.scanDate = Date()
        
        if auditReport.totalFindings > 0 {
            appState = .exposed
            currentScanPhase = "Audit complete — \(auditReport.totalFindings) items found"
            log("Audit complete. \(auditReport.totalFindings) privacy items identified.", type: .critical)
            HapticManager.auditComplete(findingsCount: auditReport.totalFindings)
        } else {
            appState = .cloaked
            currentScanPhase = "All clear — no issues detected"
            log("Audit complete. No significant privacy issues found.", type: .success)
            HapticManager.auditComplete(findingsCount: 0)
        }
    }
    
    // MARK: - Neutralize Execution
    
    private func performNeutralize() async {
        log("Creating system snapshot for rollback safety...", type: .system)
        await neutralizeEngine.createSnapshot()
        
        let totalSteps = Double(auditReport.findings.count + auditReport.photoLocations.count + auditReport.ghostFiles.count)
        var completedSteps = 0.0
        
        // Strip photo metadata
        log("Stripping GPS metadata from photos...", type: .info)
        for location in auditReport.photoLocations {
            await neutralizeEngine.stripMetadata(filePath: location.photoPath)
            completedSteps += 1
            neutralizeProgress = completedSteps / max(totalSteps, 1)
        }
        
        // Shred ghost files
        log("Overwriting recoverable file remnants...", type: .info)
        for ghost in auditReport.ghostFiles {
            await neutralizeEngine.shredGhostFile(ghost: ghost)
            completedSteps += 1
            neutralizeProgress = completedSteps / max(totalSteps, 1)
        }
        
        // Vault sensitive files
        log("Securing sensitive documents in encrypted vault...", type: .info)
        for finding in auditReport.findings where finding.filePath != nil {
            if let path = finding.filePath {
                await neutralizeEngine.vaultFile(filePath: path)
            }
            completedSteps += 1
            neutralizeProgress = completedSteps / max(totalSteps, 1)
        }
        
        // Block telemetry
        log("Updating host rules for telemetry endpoints...", type: .info)
        await neutralizeEngine.blockTelemetryEndpoints(auditReport.telemetryEndpoints)
        
        neutralizeProgress = 1.0
        appState = .cloaked
        log("Neutralization complete. System status: Cloaked.", type: .success)
        HapticManager.neutralizeComplete()
    }
    
    // MARK: - Logging
    
    func log(_ message: String, type: MissionLogEntry.LogType) {
        let entry = MissionLogEntry(timestamp: Date(), message: message, type: type)
        missionLog.insert(entry, at: 0)
    }
}

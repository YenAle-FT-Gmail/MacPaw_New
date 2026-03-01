import SwiftUI

struct OverviewPanel: View {
    @EnvironmentObject var coordinator: StateCoordinator
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if coordinator.appState == .idle {
                    idleState
                } else {
                    reportSummary
                    findingsBreakdown
                    recentFindings
                }
            }
            .padding(24)
        }
        .background(Color(hex: "0D1117"))
    }
    
    // MARK: - Idle State
    private var idleState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 60)
            
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Audit Performed")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Text("Run an identity audit to scan your system for privacy exposure.\nThis is a read-only scan — no files will be modified.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            Spacer()
        }
    }
    
    // MARK: - Report Summary
    private var reportSummary: some View {
        HStack(spacing: 16) {
            StatCard(title: "Total Items", value: "\(coordinator.auditReport.totalFindings)", color: .white)
            StatCard(title: "Critical", value: "\(coordinator.auditReport.criticalCount)", color: Color(hex: "FF2D2D"))
            StatCard(title: "High", value: "\(coordinator.auditReport.highCount)", color: .orange)
            StatCard(title: "Scan Time", value: String(format: "%.1fs", coordinator.auditReport.scanDuration), color: .cyan)
        }
    }
    
    // MARK: - Findings Breakdown
    private var findingsBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FINDINGS BREAKDOWN")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            HStack(spacing: 12) {
                BreakdownRow(
                    icon: "mappin.circle.fill",
                    label: "Photos with GPS",
                    count: coordinator.auditReport.photoLocations.count,
                    color: .orange
                )
                BreakdownRow(
                    icon: "doc.circle.fill",
                    label: "Recoverable Files",
                    count: coordinator.auditReport.ghostFiles.count,
                    color: .purple
                )
                BreakdownRow(
                    icon: "exclamationmark.triangle.fill",
                    label: "Sensitive Data",
                    count: coordinator.auditReport.findings.filter { $0.category == .sensitiveString }.count,
                    color: Color(hex: "FF2D2D")
                )
                BreakdownRow(
                    icon: "antenna.radiowaves.left.and.right",
                    label: "Telemetry Active",
                    count: coordinator.auditReport.telemetryEndpoints.filter { $0.isActive }.count,
                    color: .cyan
                )
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
    
    // MARK: - Recent Findings
    private var recentFindings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT FINDINGS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            
            ForEach(coordinator.auditReport.findings.prefix(10)) { finding in
                FindingRow(finding: finding)
            }
            
            if coordinator.auditReport.findings.isEmpty {
                Text("No findings to display.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            
            Text(title.uppercased())
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Breakdown Row
struct BreakdownRow: View {
    let icon: String
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Finding Row
struct FindingRow: View {
    let finding: AuditFinding
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(severityColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(finding.title)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(finding.detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Text(finding.severity.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(severityColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(severityColor.opacity(0.15)))
        }
        .padding(.vertical, 4)
    }
    
    private var severityColor: Color {
        switch finding.severity {
        case .info: return .gray
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return Color(hex: "FF2D2D")
        }
    }
}

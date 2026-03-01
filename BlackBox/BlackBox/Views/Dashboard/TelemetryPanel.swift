import SwiftUI

struct TelemetryPanel: View {
    @EnvironmentObject var coordinator: StateCoordinator
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if coordinator.auditReport.telemetryEndpoints.isEmpty {
                    emptyState
                } else {
                    summaryBar
                    
                    // Apple telemetry section
                    sectionHeader("APPLE TELEMETRY ENDPOINTS")
                    ForEach(coordinator.auditReport.telemetryEndpoints.filter { $0.isApple }) { endpoint in
                        TelemetryRow(endpoint: endpoint)
                    }
                    
                    // Third-party telemetry section
                    sectionHeader("THIRD-PARTY TELEMETRY ENDPOINTS")
                    ForEach(coordinator.auditReport.telemetryEndpoints.filter { !$0.isApple }) { endpoint in
                        TelemetryRow(endpoint: endpoint)
                    }
                }
            }
            .padding(24)
        }
        .background(Color(hex: "0D1117"))
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 60)
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 36))
                .foregroundColor(.gray)
            Text("Run an audit to check telemetry endpoints.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var summaryBar: some View {
        HStack(spacing: 16) {
            let active = coordinator.auditReport.telemetryEndpoints.filter { $0.isActive }.count
            let blocked = coordinator.auditReport.telemetryEndpoints.filter { !$0.isActive }.count
            
            HStack(spacing: 6) {
                Circle().fill(Color(hex: "FF6B35")).frame(width: 8, height: 8)
                Text("\(active) active")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 6) {
                Circle().fill(Color(hex: "00FF66")).frame(width: 8, height: 8)
                Text("\(blocked) blocked")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(.gray)
            .padding(.top, 8)
    }
}

struct TelemetryRow: View {
    let endpoint: TelemetryEndpoint
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(endpoint.isActive ? Color(hex: "FF6B35") : Color(hex: "00FF66"))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(endpoint.domain)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(endpoint.source)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(endpoint.isActive ? "ACTIVE" : "BLOCKED")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(endpoint.isActive ? .orange : Color(hex: "00FF66"))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(
                        (endpoint.isActive ? Color.orange : Color(hex: "00FF66")).opacity(0.15)
                    )
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.02)))
    }
}

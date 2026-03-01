import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var coordinator: StateCoordinator
    @State private var selectedTab: DashboardTab = .overview
    
    enum DashboardTab: String, CaseIterable {
        case overview = "Overview"
        case locations = "Locations"
        case files = "Files"
        case telemetry = "Telemetry"
        case log = "Mission Log"
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebar
                .frame(width: 220)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Main content
            VStack(spacing: 0) {
                headerBar
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                mainContent
            }
        }
        .background(Color(hex: "0D1117"))
    }
    
    // MARK: - Sidebar
    private var sidebar: some View {
        VStack(spacing: 0) {
            // Logo area
            VStack(spacing: 8) {
                Text("BLACK")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(.white) +
                Text("BOX")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(coordinator.appState == .exposed ? Color(hex: "FF2D2D") : Color(hex: "00FF66"))
                
                Text("PRIVACY AUDIT SYSTEM")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                    .tracking(3)
            }
            .padding(.top, 40)
            .padding(.bottom, 24)
            
            // Core Orb
            CoreOrbSection(appState: coordinator.appState, scanProgress: coordinator.scanProgress)
                .frame(height: 300)
            
            Spacer()
            
            // Navigation tabs
            VStack(spacing: 2) {
                ForEach(DashboardTab.allCases, id: \.self) { tab in
                    sidebarButton(tab)
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
            
            // Action Button
            actionButton
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
        }
        .background(Color(hex: "0A0E1A"))
    }
    
    private func sidebarButton(_ tab: DashboardTab) -> some View {
        Button(action: { selectedTab = tab }) {
            HStack(spacing: 10) {
                Image(systemName: iconForTab(tab))
                    .font(.system(size: 13))
                    .frame(width: 20)
                
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                
                Spacer()
                
                if tab == .overview, coordinator.auditReport.totalFindings > 0 {
                    Text("\(coordinator.auditReport.totalFindings)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(hex: "FF2D2D")))
                }
            }
            .foregroundColor(selectedTab == tab ? .white : .gray)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedTab == tab ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func iconForTab(_ tab: DashboardTab) -> String {
        switch tab {
        case .overview: return "shield.lefthalf.filled"
        case .locations: return "mappin.and.ellipse"
        case .files: return "doc.text.magnifyingglass"
        case .telemetry: return "antenna.radiowaves.left.and.right"
        case .log: return "terminal"
        }
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTab.rawValue.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(coordinator.currentScanPhase)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(coordinator.appState.rawValue.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(statusColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .stroke(statusColor.opacity(0.3), lineWidth: 1)
                    .background(Capsule().fill(statusColor.opacity(0.1)))
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color(hex: "0D1117"))
    }
    
    private var statusColor: Color {
        switch coordinator.appState {
        case .idle: return .gray
        case .auditing: return .cyan
        case .exposed: return Color(hex: "FF2D2D")
        case .neutralizing: return .orange
        case .cloaked: return Color(hex: "00FF66")
        }
    }
    
    // MARK: - Main Content
    @ViewBuilder
    private var mainContent: some View {
        switch selectedTab {
        case .overview:
            OverviewPanel()
        case .locations:
            LocationsPanel()
        case .files:
            FilesPanel()
        case .telemetry:
            TelemetryPanel()
        case .log:
            MissionLogPanel()
        }
    }
    
    // MARK: - Action Button
    private var actionButton: some View {
        Group {
            if coordinator.appState == .exposed {
                // Destructive action requires Hold to Confirm
                HoldToConfirmButton(
                    label: "HOLD TO NEUTRALIZE",
                    icon: "bolt.shield.fill",
                    holdDuration: 2.0,
                    gradient: LinearGradient(colors: [Color(hex: "FF2D2D"), Color(hex: "DC2626")], startPoint: .leading, endPoint: .trailing),
                    shadowColor: Color(hex: "FF2D2D")
                ) {
                    coordinator.requestNeutralize()
                }
            } else {
                Button(action: {
                    switch coordinator.appState {
                    case .idle, .cloaked:
                        HapticManager.alignment()
                        coordinator.startAudit()
                    default:
                        break
                    }
                }) {
                    HStack(spacing: 8) {
                        if coordinator.appState == .auditing || coordinator.appState == .neutralizing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: actionIcon)
                                .font(.system(size: 14, weight: .bold))
                        }
                        
                        Text(actionLabel)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(actionGradient)
                    )
                    .shadow(color: actionShadowColor.opacity(0.4), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(coordinator.appState == .auditing || coordinator.appState == .neutralizing)
            }
        }
    }
    
    private var actionLabel: String {
        switch coordinator.appState {
        case .idle: return "BEGIN AUDIT"
        case .auditing: return "SCANNING..."
        case .exposed: return "NEUTRALIZE"
        case .neutralizing: return "WORKING..."
        case .cloaked: return "RE-SCAN"
        }
    }
    
    private var actionIcon: String {
        switch coordinator.appState {
        case .idle, .cloaked: return "shield.checkered"
        case .exposed: return "bolt.shield.fill"
        default: return "arrow.triangle.2.circlepath"
        }
    }
    
    private var actionGradient: LinearGradient {
        switch coordinator.appState {
        case .idle:
            return LinearGradient(colors: [Color(hex: "2563EB"), Color(hex: "1D4ED8")], startPoint: .leading, endPoint: .trailing)
        case .exposed:
            return LinearGradient(colors: [Color(hex: "FF2D2D"), Color(hex: "DC2626")], startPoint: .leading, endPoint: .trailing)
        case .cloaked:
            return LinearGradient(colors: [Color(hex: "059669"), Color(hex: "047857")], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private var actionShadowColor: Color {
        switch coordinator.appState {
        case .exposed: return Color(hex: "FF2D2D")
        case .cloaked: return Color(hex: "00FF66")
        default: return .blue
        }
    }
}

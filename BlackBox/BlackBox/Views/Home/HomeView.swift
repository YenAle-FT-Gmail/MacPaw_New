import SwiftUI

/// The main landing homepage. Core Orb dominates the center with
/// privacy status, quick stats, and the primary action button.
struct HomeView: View {
    @EnvironmentObject var coordinator: StateCoordinator
    @Binding var showDashboard: Bool
    
    @State private var orbScale: CGFloat = 0.6
    @State private var textOpacity: Double = 0
    @State private var statsOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 40
    
    var body: some View {
        ZStack {
            // Deep dark background
            LinearGradient(
                colors: [Color(hex: "000000"), Color(hex: "070B14"), Color(hex: "0D1117")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Ambient glow behind the orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [orbGlowColor.opacity(0.25), orbGlowColor.opacity(0.05), .clear],
                        center: .center,
                        startRadius: 40,
                        endRadius: 350
                    )
                )
                .frame(width: 700, height: 700)
                .blur(radius: 80)
                .offset(y: -40)
            
            VStack(spacing: 0) {
                Spacer()
                
                // ── Branding ──
                branding
                    .opacity(textOpacity)
                
                Spacer().frame(height: 28)
                
                // ── Core Orb (Hero) ──
                ZStack {
                    CoreOrbSection(appState: coordinator.appState, scanProgress: coordinator.scanProgress)
                        .frame(width: 360, height: 360)
                        .scaleEffect(orbScale)
                }
                
                Spacer().frame(height: 20)
                
                // ── Status Message ──
                statusMessage
                    .opacity(textOpacity)
                
                Spacer().frame(height: 32)
                
                // ── Quick Stats (after scan) ──
                if coordinator.appState == .exposed || coordinator.appState == .cloaked {
                    quickStats
                        .opacity(statsOpacity)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                    Spacer().frame(height: 28)
                }
                
                // ── Action Button ──
                actionArea
                    .offset(y: buttonOffset)
                    .opacity(textOpacity)
                
                Spacer().frame(height: 16)
                
                // ── View Details link ──
                if coordinator.appState != .idle {
                    Button(action: { withAnimation(.spring(response: 0.5)) { showDashboard = true } }) {
                        HStack(spacing: 6) {
                            Text("VIEW DETAILED REPORT")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(orbGlowColor.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                    .transition(.opacity)
                }
                
                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                orbScale = 1.0
                textOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                statsOpacity = 1.0
                buttonOffset = 0
            }
        }
        .animation(.easeInOut(duration: 0.5), value: coordinator.appState)
    }
    
    // MARK: - Branding
    
    private var branding: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                Text("BLACK")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text("BOX")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(coordinator.appState == .exposed ? Color(hex: "FF2D2D") : Color(hex: "00FF66"))
            }
            
            Text("PRIVACY AUDIT SYSTEM")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.35))
                .tracking(5)
        }
    }
    
    // MARK: - Status Message
    
    private var statusMessage: some View {
        VStack(spacing: 6) {
            Text(statusTitle)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Text(statusSubtitle)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
        }
    }
    
    private var statusTitle: String {
        switch coordinator.appState {
        case .idle:         return "System ready for audit"
        case .auditing:     return "Scanning your system…"
        case .exposed:      return "\(coordinator.auditReport.totalFindings) privacy items found"
        case .neutralizing: return "Neutralizing threats…"
        case .cloaked:      return "Your system is protected"
        }
    }
    
    private var statusSubtitle: String {
        switch coordinator.appState {
        case .idle:         return "Run a read-only scan to discover what your Mac knows about you."
        case .auditing:     return coordinator.currentScanPhase
        case .exposed:      return "GPS metadata, recoverable files, and tracking endpoints were detected."
        case .neutralizing: return "Stripping metadata, shredding remnants, blocking trackers…"
        case .cloaked:      return "All identified exposure has been resolved."
        }
    }
    
    // MARK: - Quick Stats
    
    private var quickStats: some View {
        HStack(spacing: 14) {
            homeStatPill(
                icon: "mappin.and.ellipse",
                value: "\(coordinator.auditReport.photoLocations.count)",
                label: "Locations",
                color: .orange
            )
            homeStatPill(
                icon: "doc.text.magnifyingglass",
                value: "\(coordinator.auditReport.ghostFiles.count)",
                label: "Ghost Files",
                color: .purple
            )
            homeStatPill(
                icon: "exclamationmark.triangle.fill",
                value: "\(coordinator.auditReport.findings.filter { $0.severity >= .high }.count)",
                label: "Critical",
                color: Color(hex: "FF2D2D")
            )
            homeStatPill(
                icon: "antenna.radiowaves.left.and.right",
                value: "\(coordinator.auditReport.telemetryEndpoints.filter { $0.isActive }.count)",
                label: "Trackers",
                color: .cyan
            )
        }
    }
    
    private func homeStatPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Text(label.uppercased())
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.15), lineWidth: 1))
        )
    }
    
    // MARK: - Action Area
    
    private var actionArea: some View {
        Group {
            if coordinator.appState == .exposed {
                HoldToConfirmButton(
                    label: "HOLD TO NEUTRALIZE",
                    icon: "bolt.shield.fill",
                    holdDuration: 2.0,
                    gradient: LinearGradient(
                        colors: [Color(hex: "FF2D2D"), Color(hex: "DC2626")],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    shadowColor: Color(hex: "FF2D2D")
                ) {
                    coordinator.requestNeutralize()
                }
                .frame(maxWidth: 320)
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
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: 320)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(actionGradient)
                    )
                    .shadow(color: actionShadowColor.opacity(0.5), radius: 16, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(coordinator.appState == .auditing || coordinator.appState == .neutralizing)
            }
        }
    }
    
    // MARK: - Action Helpers
    
    private var actionLabel: String {
        switch coordinator.appState {
        case .idle:         return "BEGIN AUDIT"
        case .auditing:     return "SCANNING…"
        case .exposed:      return "NEUTRALIZE"
        case .neutralizing: return "WORKING…"
        case .cloaked:      return "RE-SCAN"
        }
    }
    
    private var actionIcon: String {
        switch coordinator.appState {
        case .idle, .cloaked: return "shield.checkered"
        case .exposed:        return "bolt.shield.fill"
        default:              return "arrow.triangle.2.circlepath"
        }
    }
    
    private var actionGradient: LinearGradient {
        switch coordinator.appState {
        case .idle:
            return LinearGradient(colors: [Color(hex: "2563EB"), Color(hex: "1D4ED8")], startPoint: .leading, endPoint: .trailing)
        case .cloaked:
            return LinearGradient(colors: [Color(hex: "059669"), Color(hex: "047857")], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private var actionShadowColor: Color {
        switch coordinator.appState {
        case .exposed:  return Color(hex: "FF2D2D")
        case .cloaked:  return Color(hex: "00FF66")
        default:        return .blue
        }
    }
    
    private var orbGlowColor: Color {
        switch coordinator.appState {
        case .idle:         return .gray
        case .auditing:     return .cyan
        case .exposed:      return Color(hex: "FF2D2D")
        case .neutralizing: return .orange
        case .cloaked:      return Color(hex: "00FF66")
        }
    }
}

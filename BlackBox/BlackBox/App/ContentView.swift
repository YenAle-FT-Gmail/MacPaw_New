import SwiftUI

struct ContentView: View {
    @EnvironmentObject var coordinator: StateCoordinator
    @State private var hasFullDiskAccess = false
    @State private var showOnboarding = true
    @State private var showDashboard = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.black, Color(hex: "0A0E1A"), Color(hex: "0D1117")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if showOnboarding && !hasFullDiskAccess {
                OnboardingView(hasGrantedAccess: $hasFullDiskAccess, showOnboarding: $showOnboarding)
                    .transition(.opacity)
            } else if showDashboard {
                // Detailed dashboard with sidebar + panels
                ZStack(alignment: .topLeading) {
                    DashboardView()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    
                    // Back to Home button
                    Button(action: {
                        withAnimation(.spring(response: 0.4)) {
                            showDashboard = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                            Text("HOME")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .padding(.leading, 12)
                }
            } else {
                // Homepage — Core Orb hero landing
                HomeView(showDashboard: $showDashboard)
                    .transition(.opacity)
            }
            
            // Paywall overlay
            if coordinator.showPaywall {
                PaywallView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showOnboarding)
        .animation(.easeInOut(duration: 0.3), value: coordinator.showPaywall)
        .animation(.spring(response: 0.5), value: showDashboard)
        .onAppear {
            hasFullDiskAccess = FullDiskAccessChecker.hasFullDiskAccess()
            if hasFullDiskAccess {
                showOnboarding = false
            }
        }
    }
}

// MARK: - Hex Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

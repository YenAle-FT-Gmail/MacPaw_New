import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var coordinator: StateCoordinator
    @State private var selectedPlan: Plan = .annual
    @State private var isProcessing = false
    
    enum Plan: String, CaseIterable {
        case annual = "Annual"
        case monthly = "Monthly"
        
        var price: String {
            switch self {
            case .annual: return "$29.99/yr"
            case .monthly: return "$4.99/mo"
            }
        }
        
        var savings: String? {
            switch self {
            case .annual: return "Save 50%"
            case .monthly: return nil
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { coordinator.dismissPaywall() }
            
            // Modal
            VStack(spacing: 0) {
                closeBar
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        featuresSection
                        plansSection
                        subscribeButton
                        legalNote
                    }
                    .padding(32)
                }
            }
            .frame(width: 480, height: 640)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "12161F"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
        }
    }
    
    // MARK: - Close bar
    private var closeBar: some View {
        HStack {
            Spacer()
            Button(action: { coordinator.dismissPaywall() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 36))
                .foregroundColor(Color(hex: "00FF66"))
            
            Text("Upgrade to BlackBox Pro")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Text("Take action on your audit findings.\nClean, shred, and protect your data.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Features
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FeatureRow(icon: "scissors", text: "Strip GPS & metadata from photos")
            FeatureRow(icon: "flame.fill", text: "3-pass forensic file shredder")
            FeatureRow(icon: "lock.shield.fill", text: "Encrypted Shadow Vault backup")
            FeatureRow(icon: "network.slash", text: "Block telemetry endpoints")
            FeatureRow(icon: "arrow.counterclockwise", text: "24-hour Emergency Rewind rollback")
            FeatureRow(icon: "clock.arrow.2.circlepath", text: "Weekly automated re-scans")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
    }
    
    // MARK: - Plans
    private var plansSection: some View {
        HStack(spacing: 12) {
            ForEach(Plan.allCases, id: \.self) { plan in
                PlanCard(plan: plan, isSelected: selectedPlan == plan) {
                    selectedPlan = plan
                }
            }
        }
    }
    
    // MARK: - Subscribe Button
    private var subscribeButton: some View {
        Button(action: { handleSubscription() }) {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Image(systemName: "lock.open.fill")
                    Text("ACTIVATE PRO — \(selectedPlan.price)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [Color(hex: "00CC55"), Color(hex: "00AA44")],
                        startPoint: .leading, endPoint: .trailing
                    ))
            )
            .shadow(color: Color(hex: "00FF66").opacity(0.3), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
    }
    
    // MARK: - Legal
    private var legalNote: some View {
        Text("Cancel anytime. Subscription renews automatically.\nPayment processed securely via Stripe.")
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.gray.opacity(0.5))
            .multilineTextAlignment(.center)
    }
    
    // MARK: - Subscription Logic
    private func handleSubscription() {
        isProcessing = true
        
        // TODO: Integrate Stripe/Paddle SDK here
        // For MVP, simulate subscription activation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            coordinator.subscription = SubscriptionStatus(
                isActive: true,
                expirationDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()),
                plan: selectedPlan == .annual ? "Pro Annual" : "Pro Monthly"
            )
            isProcessing = false
            coordinator.dismissPaywall()
            coordinator.beginNeutralize()
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "00FF66"))
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Plan Card
struct PlanCard: View {
    let plan: PaywallView.Plan
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let savings = plan.savings {
                    Text(savings)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00FF66"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(hex: "00FF66").opacity(0.15)))
                }
                
                Text(plan.rawValue)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(plan.price)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? Color(hex: "00FF66") : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color(hex: "00FF66").opacity(0.08) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color(hex: "00FF66").opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

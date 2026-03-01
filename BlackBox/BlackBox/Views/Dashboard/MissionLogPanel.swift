import SwiftUI

struct MissionLogPanel: View {
    @EnvironmentObject var coordinator: StateCoordinator
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal header
            HStack {
                Text("$ blackbox --mission-log")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: "00FF66"))
                
                Spacer()
                
                Text("\(coordinator.missionLog.count) entries")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.3))
            
            Divider().background(Color.white.opacity(0.1))
            
            // Log entries
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(coordinator.missionLog) { entry in
                        LogEntryRow(entry: entry)
                    }
                    
                    if coordinator.missionLog.isEmpty {
                        Text("  No log entries yet. Start an audit to begin.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray)
                            .padding(16)
                    }
                }
            }
        }
        .background(Color(hex: "0A0E14"))
    }
}

struct LogEntryRow: View {
    let entry: StateCoordinator.MissionLogEntry
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(Self.timeFormatter.string(from: entry.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray.opacity(0.5))
                .frame(width: 60, alignment: .leading)
            
            Text(typePrefix)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(typeColor)
                .frame(width: 40, alignment: .leading)
            
            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(typeColor.opacity(0.9))
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private var typePrefix: String {
        switch entry.type {
        case .info: return "INFO"
        case .warning: return "WARN"
        case .critical: return "CRIT"
        case .success: return "DONE"
        case .system: return "SYS"
        }
    }
    
    private var typeColor: Color {
        switch entry.type {
        case .info: return .cyan
        case .warning: return .yellow
        case .critical: return Color(hex: "FF2D2D")
        case .success: return Color(hex: "00FF66")
        case .system: return .gray
        }
    }
}

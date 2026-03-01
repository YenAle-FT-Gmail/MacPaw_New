import SwiftUI

struct FilesPanel: View {
    @EnvironmentObject var coordinator: StateCoordinator
    @State private var selectedSegment: FileSegment = .sensitive
    
    enum FileSegment: String, CaseIterable {
        case sensitive = "Sensitive Data"
        case ghosts = "Recoverable Files"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Segment picker
            HStack(spacing: 0) {
                ForEach(FileSegment.allCases, id: \.self) { segment in
                    Button(action: { selectedSegment = segment }) {
                        Text(segment.rawValue.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(selectedSegment == segment ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedSegment == segment ? Color.white.opacity(0.08) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(hex: "0A0E1A"))
            
            Divider().background(Color.white.opacity(0.1))
            
            // Content
            switch selectedSegment {
            case .sensitive:
                sensitiveDataList
            case .ghosts:
                ghostFileList
            }
        }
        .background(Color(hex: "0D1117"))
    }
    
    // MARK: - Sensitive Data List (Terminal Style)
    private var sensitiveDataList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                let sensitiveFindings = coordinator.auditReport.findings.filter { $0.category == .sensitiveString }
                
                if sensitiveFindings.isEmpty {
                    emptyState(icon: "checkmark.shield", message: "No sensitive data patterns detected in scanned documents.")
                } else {
                    // Terminal header
                    HStack {
                        Text("$ blackbox scan --pattern-match --redacted")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(hex: "00FF66"))
                        Spacer()
                        Text("\(sensitiveFindings.count) matches")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.3))
                    
                    ForEach(sensitiveFindings) { finding in
                        TerminalFindingRow(finding: finding)
                    }
                }
            }
        }
    }
    
    // MARK: - Ghost File Gallery
    private var ghostFileList: some View {
        ScrollView {
            if coordinator.auditReport.ghostFiles.isEmpty {
                emptyState(icon: "trash.slash", message: "No recoverable deleted files found in scanned locations.")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(coordinator.auditReport.ghostFiles) { ghost in
                        GhostFileCard(ghost: ghost)
                    }
                }
                .padding(16)
            }
        }
    }
    
    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer(minLength: 60)
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.gray)
            Text(message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Terminal-Style Finding Row
struct TerminalFindingRow: View {
    let finding: AuditFinding
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(severityBadge)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(severityColor)
                
                Text(finding.title)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            Text("  → \(finding.detail)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(hex: "8B949E"))
                .lineLimit(3)
            
            if let path = finding.filePath {
                Text("  📁 \(shortenPath(path))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.015))
        .overlay(
            Rectangle()
                .fill(severityColor)
                .frame(width: 3),
            alignment: .leading
        )
    }
    
    private var severityBadge: String {
        switch finding.severity {
        case .info: return "[INFO]"
        case .moderate: return "[WARN]"
        case .high: return "[HIGH]"
        case .critical: return "[CRIT]"
        }
    }
    
    private var severityColor: Color {
        switch finding.severity {
        case .info: return .gray
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return Color(hex: "FF2D2D")
        }
    }
    
    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.replacingOccurrences(of: home, with: "~")
    }
}

// MARK: - Ghost File Card
struct GhostFileCard: View {
    let ghost: GhostFile
    
    var body: some View {
        VStack(spacing: 8) {
            // File type icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple.opacity(0.1))
                    .frame(height: 80)
                
                VStack(spacing: 4) {
                    Image(systemName: iconForType)
                        .font(.system(size: 28))
                        .foregroundColor(.purple)
                    
                    Text(ghost.fileType)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.purple)
                }
            }
            
            VStack(spacing: 2) {
                Text("Recoverable \(ghost.fileType)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(ByteCountFormatter.string(fromByteCount: ghost.estimatedSize, countStyle: .file))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray)
                
                Text("Sig: \(ghost.headerSignature)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.2), lineWidth: 1))
    }
    
    private var iconForType: String {
        switch ghost.fileType {
        case "JPG", "JPEG", "PNG": return "photo"
        case "PDF": return "doc.richtext"
        case "ZIP", "DOCX": return "doc.zipper"
        case "SQLITE": return "cylinder"
        default: return "doc"
        }
    }
}

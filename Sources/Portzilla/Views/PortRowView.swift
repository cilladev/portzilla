import SwiftUI

struct PortRowView: View {
    let port: PortInfo
    let onKill: () -> Void
    @State private var isHovering = false
    @State private var isKillHovering = false

    private var isSelf: Bool { port.pid == getpid() }

    var body: some View {
        HStack(spacing: 10) {
            Text(":\(port.port)")
                .font(.system(size: 13, design: .monospaced).weight(.semibold))
                .foregroundColor(.accentColor)
                .frame(width: 64, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(port.processName)
                    .font(.system(size: 13, weight: .medium))
                Text(port.command)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(port.command)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("PID \(port.pid)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 78, alignment: .leading)

            Button(action: onKill) {
                HStack(spacing: 4) {
                    Image(systemName: port.isOwnedByCurrentUser ? "xmark" : "lock")
                        .font(.system(size: 12))
                    Text("Kill")
                        .font(.system(size: 12))
                }
                .frame(width: 60, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(killBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(killBorder, lineWidth: 0.5)
                )
                .foregroundColor(killForeground)
            }
            .buttonStyle(.plain)
            .disabled(isSelf)
            .onHover { isKillHovering = $0 }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isHovering ? Color(NSColor.controlBackgroundColor) : Color.clear)
        .onHover { isHovering = $0 }
    }

    private var killBackground: Color {
        guard isKillHovering, port.isOwnedByCurrentUser else { return .clear }
        return Color.red.opacity(0.1)
    }

    private var killBorder: Color {
        guard isKillHovering, port.isOwnedByCurrentUser else { return Color(NSColor.separatorColor) }
        return Color.red.opacity(0.3)
    }

    private var killForeground: Color {
        guard isKillHovering, port.isOwnedByCurrentUser else { return .secondary }
        return .red
    }
}

import SwiftUI

struct EmptyStateView: View {
    let hasFilter: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "face.smiling")
                .font(.system(size: 22))
                .opacity(0.6)
            Text(hasFilter ? "No ports match." : "No listening ports.")
                .font(.system(size: 13))
        }
        .foregroundColor(Color(NSColor.tertiaryLabelColor))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

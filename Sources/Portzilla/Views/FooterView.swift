import SwiftUI

struct FooterView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack {
            Text("\(String(state.listeningCount)) listening port\(state.listeningCount == 1 ? "" : "s")")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

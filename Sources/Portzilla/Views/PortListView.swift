import SwiftUI

struct PortListView: View {
    @EnvironmentObject var state: AppState

    private var hasFilter: Bool {
        !state.filter.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        if state.filteredPorts.isEmpty {
            EmptyStateView(hasFilter: hasFilter)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(state.filteredPorts) { port in
                        PortRowView(port: port) {
                            Task { await state.kill(port) }
                        }
                        Divider().padding(.horizontal, 14)
                    }
                }
            }
            .frame(maxHeight: 360)
        }
    }
}

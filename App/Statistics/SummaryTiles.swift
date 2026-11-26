import SwiftUI

/// Tiles in one row when there's room, otherwise two to a row.
struct SummaryTiles<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { content }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) { content }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}

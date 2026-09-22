import SwiftUI

/// Centers a finite LazyVGrid as a group inside the available width.
/// The grid keeps its configured card widths instead of stretching them.
struct CenteredLazyGrid<Content: View>: View {
    let columns: [GridItem]
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let content: Content

    init(
        columns: [GridItem],
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.columns = columns
        self.alignment = alignment
        self.spacing = spacing ?? 0
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            LazyVGrid(
                columns: columns,
                alignment: alignment,
                spacing: spacing
            ) {
                content
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

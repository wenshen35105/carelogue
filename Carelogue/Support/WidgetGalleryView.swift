#if DEBUG
import SwiftData
import SwiftUI

/// -uitest-widget-gallery (M8 T58): the widget's two sizes drawn in the app
/// from the snapshot the store would publish, at the system's widget sizes —
/// for screenshots and the English-copy check, which cannot reach a real
/// home-screen widget.
struct WidgetGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var snapshot: WidgetSnapshot?

    var body: some View {
        VStack(spacing: 24) {
            if let snapshot {
                face(snapshot, medium: false)
                    .frame(width: 170, height: 170)
                face(snapshot, medium: true)
                    .frame(width: 364, height: 170)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.5).opacity(0.25))
        .task { snapshot = WidgetPublisher.build(in: modelContext, now: .now) }
    }

    private func face(_ snapshot: WidgetSnapshot, medium: Bool) -> some View {
        CarelogueWidgetView(snapshot: snapshot, date: .now, isMedium: medium)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22).fill(WidgetPalette.background))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(medium ? "widget.medium" : "widget.small")
    }
}
#endif

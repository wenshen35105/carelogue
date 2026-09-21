import SwiftUI
import SwiftData

/// P2 · Journey 时间线. Placeholder from T3; filled in during T4.
struct JourneyTimelineView: View {
    let journey: Journey

    var body: some View {
        VStack(spacing: 12) {
            Text(journey.name)
                .font(.title2.weight(.semibold))
            Text("时间线开发中（T4）")
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle(journey.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

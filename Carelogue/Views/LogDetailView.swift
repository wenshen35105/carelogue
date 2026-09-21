import SwiftUI
import SwiftData

/// 统一详情页. Placeholder from T4; view/edit/delete built out in T7.
struct LogDetailView: View {
    let log: Log

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(log.type.isEmpty ? log.kind.rawValue : log.type)
                .font(.title2.weight(.semibold))
            Text(log.occurredAt.formatted())
                .foregroundStyle(Theme.inkSecondary)
            if let note = log.note, !note.isEmpty {
                Text(note)
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

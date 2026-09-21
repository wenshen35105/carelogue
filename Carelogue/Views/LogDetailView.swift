import SwiftUI
import SwiftData

/// 统一详情页. Basic layout from T4; polished (delete swipe, richer
/// per-kind layout) in T7. Edit entry point needed as soon as T5/T6 land
/// real editors, so it's wired here already.
struct LogDetailView: View {
    let log: Log

    @State private var showingEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(log.type.isEmpty ? log.kind.rawValue : log.type)
                .font(.title2.weight(.semibold))
            Text(log.occurredAt.formatted(.dateTime.year().month().day().hour().minute().locale(Theme.locale)))
                .foregroundStyle(Theme.inkSecondary)
            if log.kind == .encounter, log.location?.isEmpty == false || log.doctor?.isEmpty == false {
                Text([log.location, log.doctor].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .foregroundStyle(Theme.inkSecondary)
            }
            if log.kind == .measurement, let value = log.value {
                Text("\(value.formatted()) \(log.unit ?? "")")
                    .font(.title3.weight(.medium))
            }
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("编辑") { showingEditor = true }
            }
        }
        .sheet(isPresented: $showingEditor) {
            if let journey = log.journey {
                LogEditorView(journey: journey, kind: log.kind, existingLog: log)
            }
        }
    }
}

import SwiftUI
import SwiftData

/// T2 scratch harness for verifying the SwiftData model layer end to end.
/// Replaced by the real Journey list (P1) in T3.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Journey.createdAt) private var journeys: [Journey]
    @Query(sort: \Log.occurredAt) private var logs: [Log]
    @State private var didSeed = false

    var body: some View {
        NavigationStack {
            List {
                Section("Journeys (\(journeys.count))") {
                    ForEach(journeys) { journey in
                        Text("\(journey.name) · \(journey.template.rawValue) · \(journey.status.rawValue)")
                    }
                }
                Section("Logs (\(logs.count))") {
                    ForEach(logs) { log in
                        Text("\(log.kind.rawValue) · \(log.type) · \(log.occurredAt.formatted())")
                    }
                }
            }
            .navigationTitle("Carelogue T2 Debug")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Insert Test Data", action: insertTestData)
                }
            }
            .onAppear {
                if !didSeed && journeys.isEmpty {
                    didSeed = true
                    insertTestData()
                }
            }
        }
    }

    private func insertTestData() {
        let journey = Journey(name: "孕期", template: .pregnancy)
        modelContext.insert(journey)

        let log = Log(kind: .encounter, type: "面诊", note: "常规产检")
        modelContext.insert(log)
        log.journey = journey

        do {
            try modelContext.save()
            print("[T2] inserted Journey id=\(journey.id) name=\(journey.name)")
            print("[T2] inserted Log id=\(log.id) kind=\(log.kind.rawValue) journey=\(log.journey?.name ?? "nil")")
            let journeyCount = (try? modelContext.fetchCount(FetchDescriptor<Journey>())) ?? -1
            let logCount = (try? modelContext.fetchCount(FetchDescriptor<Log>())) ?? -1
            print("[T2] total journeys=\(journeyCount) total logs=\(logCount)")
        } catch {
            print("[T2] save failed: \(error)")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Journey.self, Log.self, Artifact.self, Profile.self], inMemory: true)
}

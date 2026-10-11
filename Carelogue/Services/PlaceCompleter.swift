import MapKit
import Observation

/// M8 T60: real places (hospitals, clinics, labs) for the visit's 地点 field,
/// from Apple Maps' completer. Only the typed text goes to Apple — never
/// anything from the record. Offline, or on any error, it simply returns
/// nothing and the field falls back to the user's own history (T45).
@MainActor
@Observable
final class PlaceCompleter: NSObject, MKLocalSearchCompleterDelegate {
    struct Place: Hashable, Identifiable {
        let title: String
        let subtitle: String
        var id: String { "\(title)|\(subtitle)" }
    }

    private(set) var results: [Place] = []

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = .pointOfInterest
        completer.delegate = self
    }

    /// Two characters before asking Apple; anything shorter clears.
    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            completer.cancel()
            results = []
            return
        }
        completer.queryFragment = trimmed
    }

    /// Places worth offering next to the history chips: none already in the
    /// history (case-insensitive) or identical to what is typed, at most
    /// `limit` of them.
    func suggestions(excluding history: [String], typed: String, limit: Int = 4) -> [Place] {
        let taken = Set((history + [typed]).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        var seen: Set<String> = []
        return Array(results.filter { place in
            let key = place.title.lowercased()
            return !taken.contains(key) && seen.insert(key).inserted
        }.prefix(limit))
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let places = completer.results.map { Place(title: $0.title, subtitle: $0.subtitle) }
        MainActor.assumeIsolated { results = places }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated { results = [] }
    }
}

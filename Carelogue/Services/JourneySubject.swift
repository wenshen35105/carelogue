import CloudKit
import Foundation
import SwiftData

// M8 T61 · whose health a journey records. Apple Health only connects on the
// subject's own device, and AI explanations only add the device owner's
// profile when the journey is about them.

/// Who "I" am on this device: the CloudKit user record name when iCloud is
/// available (the same id every share participant sees for this person),
/// else an id made once for this install.
@MainActor
enum MyIdentity {
    private static let localKey = "identity.local"

    /// This install's own id; also what "me" falls back to without iCloud.
    static var localID: String {
        if let id = UserDefaults.standard.string(forKey: localKey) { return id }
        let id = "local-\(UUID().uuidString)"
        UserDefaults.standard.set(id, forKey: localKey)
        return id
    }

    /// Known after `load()`; the local id until then.
    private(set) static var current: String = localID

    /// Every id that means "me" here: iCloud's, and this install's (a journey
    /// claimed before signing in to iCloud stays mine).
    static func isMe(_ id: String?) -> Bool {
        guard let id else { return false }
        return id == current || id == localID
    }

    static func load() async {
        #if DEBUG
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-uitest-identity"),
           index + 1 < ProcessInfo.processInfo.arguments.count {
            current = ProcessInfo.processInfo.arguments[index + 1]
            return
        }
        #endif
        guard !ShareChannel.simulated, CloudSync.hasICloudAccount,
              let id = try? await ShareChannel.myUserID() else { return }
        current = id
    }
}

/// Someone a journey can be about, as offered in the editor.
struct SubjectCandidate: Hashable, Identifiable {
    /// CloudKit user record name (or local id for "me" without iCloud).
    let userID: String
    let name: String?
    var id: String { userID }
}

@MainActor
extension Journey {
    enum Subject: Equatable {
        /// Nothing said yet (journeys from before 1.1).
        case unspecified
        /// The person holding this device.
        case me
        /// Someone else; their name if known.
        case someoneElse(String?)
    }

    var subject: Subject {
        if subjectUserID == nil && subjectName == nil { return .unspecified }
        if MyIdentity.isMe(subjectUserID) { return .me }
        return .someoneElse(subjectName)
    }

    /// May this device bring Apple Health into, or out of, this journey?
    /// Not when it records someone else; unspecified journeys are claimed
    /// first (see `claimAsMine`).
    var healthBelongsHere: Bool { subject == .me }

    /// AI explanations add the device owner's profile only when the journey
    /// is (or may be) about them.
    var mayIncludeMyProfile: Bool {
        if case .someoneElse = subject { return false }
        return true
    }

    /// "This journey records me." The name, when CloudKit can tell, is how
    /// the other members will see the subject.
    func claimAsMine(name: String? = nil) {
        subjectUserID = MyIdentity.current
        subjectName = name
        updatedAt = .now
    }

    func setSubject(userID: String?, name: String?) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        subjectUserID = userID
        subjectName = (trimmed?.isEmpty ?? true) ? nil : trimmed
        updatedAt = .now
    }

    func clearSubject() {
        subjectUserID = nil
        subjectName = nil
        updatedAt = .now
    }
}

@MainActor
enum SubjectCandidates {
    /// Members of a shared journey (owner first), named as CloudKit shows
    /// them. Empty for a journey that isn't shared, or when CloudKit can't
    /// be reached — the editor then offers 我自己 / 其他人 only.
    static func members(of journey: Journey) async -> [SubjectCandidate] {
        guard journey.isShared else { return [] }
        #if DEBUG
        if ShareChannel.simulated {
            // -uitest-fake-share: the journey is shared with 太太.
            return [SubjectCandidate(userID: MyIdentity.current, name: nil),
                    SubjectCandidate(userID: "user-fake-wife", name: "太太")]
        }
        #endif
        guard let share = try? await ShareChannel.existingShare(of: journey) else { return [] }
        let people = [share.owner] + share.participants.filter { $0 != share.owner && $0.acceptanceStatus == .accepted }
        return people.compactMap { participant in
            guard let id = participant.userIdentity.userRecordID?.recordName else { return nil }
            let name = participant.userIdentity.nameComponents.map {
                PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
            }
            return SubjectCandidate(userID: id, name: (name?.isEmpty ?? true) ? nil : name)
        }
    }
}

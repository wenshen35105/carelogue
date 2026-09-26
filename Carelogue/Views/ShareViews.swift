import CloudKit
import SwiftUI
import SwiftData
import UIKit

/// "共享中 Shared" capsule — the share status marker (T39). Shown in the
/// timeline header and tappable for the explanation sheet.
struct ShareStatusPill: View {
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                Text("共享中")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Theme.accentTint))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("share.status")
    }
}

/// The share explanation (T39): what two-way sync means here, the coarse
/// conflict policy, and what revoking leaves behind — the copy the study
/// asked to be stated in plain words. The system UICloudSharingController
/// (invite / participants / revoke / remove me) sits behind 管理.
struct ShareInfoSheet: View {
    let journey: Journey

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var working = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.cardGap) {
                    header

                    row(icon: "arrow.left.arrow.right",
                        title: String(localized: "双向同步"),
                        gloss: AppLanguage.gloss(String(localized: "Two-way sync")),
                        detail: String(localized: "你们都能查看和编辑这段旅程；改动双向同步，只经过你们自己的 iCloud，不经任何其他服务器。"))
                    row(icon: "clock.arrow.circlepath",
                        title: String(localized: "同时改动"),
                        gloss: AppLanguage.gloss(String(localized: "Concurrent edits")),
                        detail: String(localized: "两个人改了同一条记录时，保留较新的一条；附件不会被自动合并。"))
                    row(icon: "person.2.slash",
                        title: String(localized: "停止共享"),
                        gloss: AppLanguage.gloss(String(localized: "Stop sharing")),
                        detail: String(localized: "停止共享后，对方的副本会保留在其设备上，但不再更新。"))

                    if !ShareChannel.simulated {
                        manageButton
                    }
                }
                .padding(.horizontal, Theme.Spacing.margin)
                .padding(.vertical, 18)
            }
            .background(Theme.background)
            .navigationTitle(String(localized: "关于这段共享"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "完成")) { dismiss() }
                }
            }
            .alert(String(localized: "共享暂不可用"), isPresented: Binding(
                get: { failure != nil }, set: { if !$0 { failure = nil } }
            )) {
                Button(String(localized: "好"), role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
            .accessibilityIdentifier("share.info")
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 64, height: 64)
                .background(RoundedRectangle(cornerRadius: 20).fill(Theme.accentTint))
            VStack(spacing: 4) {
                Text(verbatim: AppLanguage.isChinese ? "「\(journey.name)」" : journey.name)
                    .font(.headline)
                    .foregroundStyle(Theme.inkPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("已通过 iCloud 与家人共享")
                    if let gloss = AppLanguage.gloss(String(localized: "Shared via iCloud")) {
                        Text(gloss)
                    }
                }
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private func row(icon: String, title: String, gloss: String?, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Theme.accentTint))
            VStack(alignment: .leading, spacing: 4) {
                BilingualTitle(primary: title, secondary: gloss, font: .body.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cardSurface()
    }

    /// Opens the system controller on the existing share (participants,
    /// revoke, remove me). It needs the fetched CKShare, so the button's task
    /// fetches it first and only then presents the controller.
    private var manageButton: some View {
        Button {
            failure = nil
            // The system controller cannot fetch the share signed out; the
            // message then explains that, instead of blaming iCloud itself.
            guard CloudSync.hasICloudAccount else {
                failure = String(localized: "共享通过你自己的 iCloud 完成。请在系统「设置 → 登录 iPhone」后重试；不登录也能正常记录，只是无法共享。")
                return
            }
            Task { @MainActor in
                working = true
                defer { working = false }
                do {
                    guard let share = try await ShareChannel.existingShare(of: journey) else {
                        failure = String(localized: "暂时连不上 iCloud，请稍后再试。")
                        return
                    }
                    SharePresenter.presentManager(for: share, journey: journey)
                } catch {
                    failure = String(localized: "暂时连不上 iCloud，请稍后再试。")
                }
            }
        } label: {
            HStack(spacing: 8) {
                if working {
                    ProgressView().tint(Theme.onAccent)
                }
                Label("管理共享 · Manage", systemImage: "person.crop.circle.badge.gearshape")
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("share.info.manage")
    }
}

/// Presents the system sharing UI straight from UIKit (T39). Both system
/// controllers expect to be presented modally themselves: wrapped in a
/// SwiftUI `.sheet` through a representable they came up as an empty dialog
/// (TestFlight 1.0 (2)).
@MainActor
enum SharePresenter {
    /// Kept alive while the manage controller is up: its delegate is weak.
    private static var coordinator: ManageCoordinator?
    /// Why the last share creation failed. The system sheet only says
    /// "couldn't create a link" (or spins in Messages); the real reason is
    /// shown once the sheet is closed — nothing can be presented over it
    /// from the timeline while it is up.
    fileprivate static var pendingFailure: String?

    /// New share: the system share sheet with a CKShare item. The share is
    /// only created once the user picks how to send the invite.
    static func presentNewShare(for journey: Journey, context: ModelContext) {
        pendingFailure = nil
        let preparation = SharePreparation(journey: journey, context: context)
        let provider = NSItemProvider()
        provider.registerCKShare(container: ShareChannel.container) {
            try await preparation.run()
        }
        let configuration = UIActivityItemsConfiguration(itemProviders: [provider])
        // The sheet's header names the journey instead of a generic
        // "Collaboration".
        let title = journey.name
        configuration.metadataProvider = { key in key == .title ? title : nil }
        let controller = UIActivityViewController(activityItemsConfiguration: configuration)
        controller.completionWithItemsHandler = { _, _, _, _ in
            Task { @MainActor in
                guard let reason = pendingFailure else { return }
                pendingFailure = nil
                let alert = UIAlertController(
                    title: String(localized: "共享暂不可用"),
                    message: String(localized: "没能创建共享，这段旅程没有被改动。原因：\(reason)"),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: String(localized: "好"), style: .cancel))
                present(alert)
            }
        }
        present(controller)
    }

    /// Existing share: participants, revoke, remove me.
    static func presentManager(for share: CKShare, journey: Journey) {
        let controller = UICloudSharingController(share: share, container: ShareChannel.container)
        let coordinator = ManageCoordinator(journey: journey)
        self.coordinator = coordinator
        controller.delegate = coordinator
        present(controller)
    }

    private static func present(_ controller: UIViewController) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard var top = scene?.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        // iPad would need an anchor; the app is iPhone-only, this is a guard.
        controller.popoverPresentationController?.sourceView = top.view
        top.present(controller, animated: true)
    }
}

/// Carries the journey into the share item's @Sendable preparation closure;
/// the work itself happens back on the main actor.
@MainActor
private final class SharePreparation: @unchecked Sendable {
    let journey: Journey
    let context: ModelContext

    init(journey: Journey, context: ModelContext) {
        self.journey = journey
        self.context = context
    }

    func run() async throws -> CKShare {
        do {
            return try await ShareChannel.prepare(journey: journey, context: context)
        } catch {
            SharePresenter.pendingFailure = error.localizedDescription
            throw error
        }
    }
}

/// Routes "sharing stopped" from the manage controller back into ShareChannel.
private final class ManageCoordinator: NSObject, UICloudSharingControllerDelegate {
    let journey: Journey

    init(journey: Journey) {
        self.journey = journey
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        journey.name
    }

    /// Owner stopped sharing, or the participant removed themselves —
    /// either way this device is out of the channel now.
    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        Task { @MainActor in
            guard let context = CarelogueApp.modelContainer?.mainContext else { return }
            await ShareChannel.stopSharing(journey: journey, in: context)
        }
    }

    /// Participants changed: nothing to do — the zone already holds the full
    /// tree for a newcomer.
    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {}

    /// The system controller surfaces save failures itself; the next sync
    /// re-attempts whatever did not land.
    func cloudSharingController(_ csc: UICloudSharingController,
                                failedToSaveShareWithError error: Error) {}
}

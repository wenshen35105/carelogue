import Foundation
import StoreKit

/// Carelogue Plus (T27): the single auto-renewing subscription that unlocks
/// the AI features. Records, attachments and everything else stay free.
///
/// The app never asks a server whether someone is subscribed — StoreKit is the
/// source of truth on the device, and the signed transaction it hands over
/// (`jwsRepresentation`) is what the relay verifies (spec §11: no accounts).
@MainActor
@Observable
final class SubscriptionService {
    static let shared = SubscriptionService()

    static let productID = "com.jiajinlinpersonalteam.Carelogue.plus.monthly"

    enum Status: Equatable {
        /// Before the first entitlement check finishes.
        case unknown
        case subscribed(expires: Date?)
        case notSubscribed
    }

    private(set) var status: Status = .unknown
    /// Nil until the App Store answers — the paywall shows a placeholder price.
    private(set) var product: Product?
    private(set) var isWorking = false

    var isSubscribed: Bool {
        if case .subscribed = status { return true }
        return false
    }

    var renewalDate: Date? {
        if case .subscribed(let expires) = status { return expires }
        return nil
    }

    /// Formatted by the store itself, in the user's own currency.
    var displayPrice: String? { product?.displayPrice }

    private var updates: Task<Void, Never>?

    private init() {}

    /// Loads the product, checks the current entitlement, and keeps watching
    /// for renewals, refunds and purchases made on another device.
    func start() {
        #if DEBUG
        if let forced = UITestSupport.forcedSubscriptionStatus {
            status = forced
            return
        }
        #endif
        updates = updates ?? Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
        Task {
            await loadProduct()
            await refresh()
        }
    }

    func loadProduct() async {
        product = try? await Product.products(for: [Self.productID]).first
    }

    /// Re-reads the current entitlement. Anything unverified is treated as no
    /// subscription — a tampered receipt must not unlock anything.
    func refresh() async {
        #if DEBUG
        if let forced = UITestSupport.forcedSubscriptionStatus {
            status = forced
            return
        }
        #endif
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  transaction.productID == Self.productID,
                  transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate, expiry < .now { continue }
            status = .subscribed(expires: transaction.expirationDate)
            return
        }
        status = .notSubscribed
    }

    enum PurchaseOutcome: Equatable {
        case subscribed
        case cancelled
        /// Ask-to-buy / SCA: the sheet closed but nothing is decided yet.
        case pending
    }

    func purchase() async throws -> PurchaseOutcome {
        if product == nil { await loadProduct() }
        guard let product else { throw SubscriptionError.productUnavailable }
        isWorking = true
        defer { isWorking = false }

        switch try await product.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw SubscriptionError.unverified
            }
            await transaction.finish()
            await refresh()
            return .subscribed
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    /// 恢复购买: asks the App Store to re-sync this Apple ID's purchases.
    func restore() async throws {
        isWorking = true
        defer { isWorking = false }
        try await AppStore.sync()
        await refresh()
    }

    /// The signed transaction the relay verifies. Nil when nothing entitles
    /// this device, so a request is never sent without one.
    func entitlementToken() async -> String? {
        #if DEBUG
        if UITestSupport.forcedSubscriptionStatus != nil {
            return isSubscribed ? "uitest-entitlement" : nil
        }
        #endif
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  transaction.productID == Self.productID,
                  transaction.revocationDate == nil else { continue }
            if let expiry = transaction.expirationDate, expiry < .now { continue }
            return entitlement.jwsRepresentation
        }
        return nil
    }
}

enum SubscriptionError: LocalizedError, Equatable {
    case productUnavailable
    case unverified

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return String(localized: "暂时拿不到订阅信息，请稍后再试")
        case .unverified:
            return String(localized: "这笔交易无法验证，请联系 App Store 支持")
        }
    }
}

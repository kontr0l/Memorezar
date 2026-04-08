import Foundation
import RevenueCat
import SwiftUI

/// Manages in-app purchases and entitlements via RevenueCat.
/// Singleton following the same pattern as AuthService.
///
/// **Current state:** All features are free. Gating will be added later.
/// Install date is recorded silently so early adopters can be grandfathered.
final class PurchaseService: NSObject, ObservableObject {
    static let shared = PurchaseService()

    // MARK: - Published State

    @Published var isPro: Bool = false
    @Published var offerings: Offerings?

    // MARK: - Early Adopter

    /// Users who installed before this date get Pro free forever.
    /// Set to .distantFuture while the app is free for everyone.
    /// When monetizing, change to the cutoff date.
    static let earlyAdopterCutoff: Date = .distantFuture

    /// First install date, recorded once and persisted forever.
    var installDate: Date {
        let key = "memorezar_first_install"
        if let stored = UserDefaults.standard.object(forKey: key) as? Date {
            return stored
        }
        let now = Date()
        UserDefaults.standard.set(now, forKey: key)
        return now
    }

    var isEarlyAdopter: Bool {
        installDate < Self.earlyAdopterCutoff
    }

    /// Whether the user has full access (Pro subscriber OR early adopter).
    var hasFullAccess: Bool {
        isPro || isEarlyAdopter
    }

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Configuration

    /// Call once at app launch before any purchases.
    func configure() {
        // Record install date on first launch
        _ = installDate

        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        Purchases.shared.delegate = self

        Task {
            await refreshCustomerInfo()
            await fetchOfferings()
        }
    }

    // MARK: - User Identification

    /// Link RevenueCat to the Supabase user on sign-in.
    func identifyUser(userId: String) {
        Purchases.shared.logIn(userId) { [weak self] customerInfo, _, _ in
            if let info = customerInfo {
                self?.updateEntitlements(from: info)
            }
        }
    }

    /// Revert to anonymous RevenueCat user on sign-out.
    func logOutUser() {
        Purchases.shared.logOut { [weak self] customerInfo, _ in
            if let info = customerInfo {
                self?.updateEntitlements(from: info)
            }
        }
    }

    // MARK: - Purchases

    /// Purchase a Pro subscription or lifetime.
    @MainActor
    func purchasePro(package: Package) async throws {
        let result = try await Purchases.shared.purchase(package: package)
        updateEntitlements(from: result.customerInfo)
    }

    /// Restore previous purchases.
    @MainActor
    func restorePurchases() async throws {
        let info = try await Purchases.shared.restorePurchases()
        updateEntitlements(from: info)
    }

    // MARK: - Entitlement Checks (for future gating)
    //
    // These all return true right now because hasFullAccess is true
    // for everyone (earlyAdopterCutoff = .distantFuture).
    // When monetizing, change the cutoff date and these will gate properly.

    func canAddCustomQuote(quoteStore: QuoteStore) -> Bool {
        if hasFullAccess { return true }
        let customCount = quoteStore.quotes.filter { quote in
            let category = quoteStore.categories.first { $0.id == quote.categoryId }
            return category?.sourcePackId == nil
        }.count
        return customCount < 20
    }

    func canAddRecording(recordingStore: LocalRecordingStore) -> Bool {
        if hasFullAccess { return true }
        let userRecordingCount = recordingStore.recordings.filter { $0.sourceRecordingId == nil }.count
        return userRecordingCount < 3
    }

    var canUseTTS: Bool { hasFullAccess }

    func canUseSoundTheme(_ theme: SoundTheme) -> Bool {
        hasFullAccess || theme == .default
    }

    /// Pro users get all packs. Free users only see packs marked as free.
    func canAccessPack(_ pack: SuggestionPack) -> Bool {
        hasFullAccess || pack.isFree
    }

    // MARK: - Private Helpers

    private func fetchOfferings() async {
        do {
            let offers = try await Purchases.shared.offerings()
            await MainActor.run { self.offerings = offers }
        } catch {
            print("[PurchaseService] Failed to fetch offerings: \(error)")
        }
    }

    private func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            await MainActor.run { self.updateEntitlements(from: info) }
        } catch {
            print("[PurchaseService] Failed to refresh customer info: \(error)")
        }
    }

    private func updateEntitlements(from info: CustomerInfo) {
        DispatchQueue.main.async {
            self.isPro = info.entitlements[RevenueCatConfig.proEntitlementId]?.isActive == true
        }
    }
}

// MARK: - PurchasesDelegate

extension PurchaseService: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        updateEntitlements(from: customerInfo)
    }
}

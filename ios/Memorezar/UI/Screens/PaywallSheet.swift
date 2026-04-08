import SwiftUI
import RevenueCat

/// Modal sheet presenting Pro subscription options.
struct PaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var purchaseService: PurchaseService
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.yellow)

                        Text("Unlock Memorezar Pro")
                            .font(.title2.bold())

                        Text("Take your memorization to the next level")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Feature list
                    VStack(alignment: .leading, spacing: 14) {
                        FeatureRow(icon: "infinity", text: String(localized: "Unlimited custom quotes"))
                        FeatureRow(icon: "mic.fill", text: String(localized: "Unlimited recordings"))
                        FeatureRow(icon: "speaker.wave.2.fill", text: String(localized: "Text-to-Speech read aloud"))
                        FeatureRow(icon: "music.note.list", text: String(localized: "All sound themes"))
                        FeatureRow(icon: "icloud.fill", text: String(localized: "Cloud sync (coming soon)"))
                    }
                    .padding(.horizontal, 24)

                    // Price buttons
                    if let offering = purchaseService.offerings?.current {
                        VStack(spacing: 12) {
                            // Yearly (best value)
                            if let yearly = offering.annual {
                                Button {
                                    Task { await purchase(package: yearly) }
                                } label: {
                                    VStack(spacing: 4) {
                                        HStack {
                                            Text("Yearly")
                                                .font(.headline)
                                            Spacer()
                                            Text(yearly.storeProduct.localizedPriceString)
                                                .font(.headline)
                                        }
                                        HStack {
                                            Text("Save 44%")
                                                .font(.caption.bold())
                                                .foregroundColor(.green)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.15))
                                                .cornerRadius(4)
                                            Spacer()
                                        }
                                    }
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.indigo, lineWidth: 2)
                                    )
                                }
                                .disabled(isLoading)
                            }

                            // Monthly
                            if let monthly = offering.monthly {
                                Button {
                                    Task { await purchase(package: monthly) }
                                } label: {
                                    HStack {
                                        Text("Monthly")
                                            .font(.headline)
                                        Spacer()
                                        Text(monthly.storeProduct.localizedPriceString)
                                            .font(.headline)
                                    }
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: 0x777777), lineWidth: 1)
                                    )
                                }
                                .disabled(isLoading)
                            }

                            // Lifetime
                            if let lifetime = offering.lifetime {
                                Button {
                                    Task { await purchase(package: lifetime) }
                                } label: {
                                    VStack(spacing: 4) {
                                        HStack {
                                            Text("Lifetime")
                                                .font(.headline)
                                            Spacer()
                                            Text(lifetime.storeProduct.localizedPriceString)
                                                .font(.headline)
                                        }
                                        HStack {
                                            Text("One-time purchase")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                    }
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: 0x777777), lineWidth: 1)
                                    )
                                }
                                .disabled(isLoading)
                            }
                        }
                        .padding(.horizontal, 24)
                    } else {
                        ProgressView(String(localized: "Loading prices..."))
                            .padding()
                    }

                    if isLoading {
                        ProgressView()
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Restore
                    Button {
                        Task { await restore() }
                    } label: {
                        Text("Restore Purchases")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .disabled(isLoading)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: purchaseService.isPro) { _, newValue in
                if newValue { dismiss() }
            }
        }
    }

    private func purchase(package: Package) async {
        isLoading = true
        errorMessage = nil
        do {
            try await purchaseService.purchasePro(package: package)
        } catch {
            if !error.isCancelledPurchase {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func restore() async {
        isLoading = true
        errorMessage = nil
        do {
            try await purchaseService.restorePurchases()
            if !purchaseService.isPro {
                errorMessage = String(localized: "No active purchase found.")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.indigo)
                .frame(width: 28)
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Error Helpers

private extension Error {
    var isCancelledPurchase: Bool {
        let nsError = self as NSError
        return nsError.domain == "RevenueCat.ErrorCode" && nsError.code == 1
    }
}

//
//  Project: StoreKit2IAPExample
//  File: ContentView.swift
//  Created by Noah Carpenter
//  🐱 Follow me on YouTube! 🎥
//  https://www.youtube.com/@NoahDoesCoding97
//  Like and Subscribe for coding tutorials and fun! 💻✨
//  Fun Fact: Cats have five toes on their front paws, but only four on their back paws! 🐾
//  Dream Big, Code Bigger
//
//  Overview
//  --------
//  This screen demonstrates a simple StoreKit 2 flow for a one‑time, non‑consumable
//  in‑app purchase that unlocks a feature section in the UI. It:
//  - Loads a placeholder product by identifier
//  - Initiates a purchase with Product.purchase()
//  - Listens for transaction updates
//  - Determines entitlement state using Transaction.latest(for:)
//
//  Setup
//  -----
//  1) Replace the product identifier below with your real non‑consumable IAP ID.
//  2) For local testing, add a StoreKit Configuration file (.storekit) to the scheme:
//     Product > Scheme > Edit Scheme > Run > Options > StoreKit Configuration.
//  3) Run the app and tap the purchase button to unlock the sample feature.
//

import SwiftUI
import StoreKit
import Foundation
import Combine

// MARK: - ContentView (One‑time purchase demo)
struct ContentView: View {
    // The view model owns StoreKit 2 logic for loading, purchasing, and entitlement checks.
    @StateObject private var store = StoreViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header / description
                    VStack(spacing: 8) {
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.tint)
                        Text("StoreKit 2 Sample Purchase")
                            .font(.title2).bold()
                            .multilineTextAlignment(.center)
                        Text("Tap the button to purchase a placeholder IAP that unlocks the feature below.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    // Feature gating: shows locked content before purchase, unlocked content after.
                    Group {
                        if store.isPurchased {
                            UnlockedFeatureView()
                                .transition(.opacity.combined(with: .scale))
                                .accessibilityLabel("Unlocked feature")
                        } else {
                            LockedFeatureView()
                                .accessibilityLabel("Locked feature")
                        }
                    }
                    .animation(.snappy, value: store.isPurchased)

                    // Purchase section: price row, purchase button, progress + status messages.
                    VStack(spacing: 12) {
                        if let product = store.product {
                            HStack(spacing: 8) {
                                Image(systemName: store.isPurchased ? "checkmark.seal.fill" : "lock.fill")
                                    .foregroundStyle(store.isPurchased ? .green : .secondary)
                                Text(store.isPurchased ? "Purchased" : "Not Purchased")
                                    .font(.subheadline)
                                    .foregroundStyle(store.isPurchased ? .green : .secondary)
                                Spacer()
                                Text(product.displayPrice)
                                    .font(.headline)
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                            }

                            // Initiate the StoreKit 2 purchase flow.
                            Button {
                                Task { await store.purchase() }
                            } label: {
                                HStack {
                                    Image(systemName: store.isPurchased ? "checkmark" : "cart")
                                    Text(store.isPurchased ? "Unlocked" : "Unlock Sample Feature")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(store.isPurchased || store.isPurchasing)
                            .opacity(store.isPurchased || store.isPurchasing ? 0.7 : 1)

                            // Show a spinner while the purchase is in progress.
                            if store.isPurchasing {
                                ProgressView("Processing purchase…")
                                    .progressViewStyle(.circular)
                            }
                        } else {
                            // Product failed to load or not configured yet (e.g., missing .storekit file).
                            ContentUnavailableView(
                                "Product Unavailable",
                                systemImage: "exclamationmark.triangle",
                                description: Text("Add a StoreKit Configuration file and replace the product ID in this file.")
                            )
                        }

                        // Status / error messages from the view model.
                        if let message = store.message {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Store")
            // Manual refresh to reload product and entitlement state.
            .toolbar { ToolbarItem(placement: .topBarTrailing) { refreshButton } }
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await store.refresh() }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .help("Refresh product and entitlement state")
    }
}

// MARK: - ViewModel (StoreKit 2 logic)
/// A lightweight StoreKit 2 view model for a single non‑consumable product.
/// Responsibilities:
/// - Load the Product for a known identifier
/// - Start a purchase and handle the result
/// - Observe Transaction.updates to react to changes
/// - Compute entitlement state using Transaction.latest(for:)
@MainActor
final class StoreViewModel: ObservableObject {
    // Replace with your real product identifier from App Store Connect.
    // This sample expects a non‑consumable product.
    private let productIdentifier = "com.example.app.samplefeature" // TODO: Replace with your IAP ID

    // UI-facing state
    @Published var product: Product?
    @Published var isPurchased: Bool = false
    @Published var isPurchasing: Bool = false
    @Published var message: String?

    private var transactionListenerTask: Task<Void, Never>?

    init() {
        // Kick off initial load and start listening for transactions as the app runs.
        Task { await refresh() }
        listenForTransactions()
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    /// Refreshes both the product metadata and the entitlement state.
    func refresh() async {
        await loadProduct()
        await refreshPurchasedStatus()
    }

    /// Loads the Product from the App Store given the known identifier.
    func loadProduct() async {
        message = nil
        do {
            let products = try await Product.products(for: [productIdentifier])
            self.product = products.first
            if products.first == nil {
                self.message = "No product found for ID: \(productIdentifier)"
            }
        } catch {
            self.product = nil
            self.message = "Failed to load product: \(error.localizedDescription)"
        }
    }

    /// Initiates a purchase and handles all StoreKit 2 outcomes.
    /// On a verified success, finishes the transaction and refreshes entitlements.
    func purchase() async {
        guard let product else { return }
        isPurchasing = true
        message = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Finish the transaction and update entitlement state
                    await transaction.finish()
                    await refreshPurchasedStatus()
                    message = "Purchase successful!"
                case .unverified(_, let error):
                    message = "Unverified transaction: \(error.localizedDescription)"
                }
            case .userCancelled:
                message = "Purchase cancelled."
            case .pending:
                message = "Purchase pending…"
            @unknown default:
                message = "Unknown purchase result."
            }
        } catch {
            message = "Purchase failed: \(error.localizedDescription)"
        }
        isPurchasing = false
    }

    /// Computes entitlement state for a non‑consumable using the latest transaction.
    /// A purchase is considered owned when it is verified, not revoked, and not upgraded.
    func refreshPurchasedStatus() async {
        // For a non-consumable, latest(for:) is an easy way to check entitlement
        if let result = await Transaction.latest(for: productIdentifier) {
            switch result {
            case .verified(let transaction):
                // Consider revoked or upgraded transactions as not currently owned
                self.isPurchased = (transaction.revocationDate == nil) && !transaction.isUpgraded
            case .unverified:
                self.isPurchased = false
            }
        } else {
            self.isPurchased = false
        }
    }

    /// Starts a detached task to continuously observe Transaction.updates.
    /// When a relevant update arrives, we finish it and refresh entitlements.
    private func listenForTransactions() {
        transactionListenerTask?.cancel()
        transactionListenerTask = Task.detached { [productIdentifier] in
            for await update in Transaction.updates {
                switch update {
                case .verified(let transaction) where transaction.productID == productIdentifier:
                    await transaction.finish()
                    await self.refreshPurchasedStatus()
                default:
                    // Ignore other products or unverified transactions
                    break
                }
            }
        }
    }
}

// MARK: - Locked / Unlocked Feature Views (pure UI)
/// A simple placeholder view representing the locked state of the feature.
private struct LockedFeatureView: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .frame(height: 180)
                    .overlay(
                        LinearGradient(colors: [.gray.opacity(0.2), .gray.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    )
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "lock.fill").font(.title)
                            Text("Sample Feature Locked")
                                .font(.headline)
                            Text("Purchase to unlock this section.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    )
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sample feature is locked")
    }
}

/// A colorful placeholder view representing the unlocked state of the feature.
private struct UnlockedFeatureView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Gradient(colors: [.blue, .purple, .pink]))
                .hueRotation(.degrees(animate ? 45 : 0))
                .frame(height: 220)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                        Text("Feature Unlocked!")
                            .font(.title3).bold()
                            .foregroundStyle(.white)
                        Text("Enjoy your exclusive content ✨")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sample feature is unlocked")
    }
}

#Preview {
    ContentView()
}

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
//  Purpose
//  -------
//  Demonstrates an auto‑renewable subscription using StoreKit 2.
//  This screen:
//   - Loads a placeholder subscription product by identifier
//   - Initiates a subscription purchase with Product.purchase()
//   - Restores purchases via AppStore.sync()
//   - Listens for Transaction.updates to react to changes
//   - Determines active entitlement using Transaction.latest(for:)
//
//  Setup
//  -----
//  1) Replace the subscription product identifier with your real ID.
//  2) For local testing, select a StoreKit Configuration (.storekit) in the scheme.
//  3) Tap Subscribe, Restore Purchases, or Manage Subscription (iOS 16+).
//

import SwiftUI
import StoreKit
import Combine

struct SubscriptionView: View {
    // View model encapsulates StoreKit 2 logic for subscriptions.
    @StateObject private var model = SubscriptionViewModel()
    // Controls presentation of the system manage subscriptions sheet (iOS 16+)
    @State private var showManageSubscriptions = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header and short description.
                    VStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.tint)
                        Text("Premium Subscription")
                            .font(.title2).bold()
                            .multilineTextAlignment(.center)
                        Text("Subscribe to unlock the advanced feature below.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    // Feature gating: sample feature when not subscribed; advanced when active.
                    Group {
                        if model.isSubscribed {
                            AdvancedFeatureView()
                                .transition(.opacity.combined(with: .scale))
                                .accessibilityLabel("Advanced feature (subscribed)")
                        } else {
                            SampleFeatureView()
                                .accessibilityLabel("Sample feature (not subscribed)")
                        }
                    }
                    .animation(.snappy, value: model.isSubscribed)

                    // Product row, subscribe button, restore/manage actions, and status output.
                    VStack(spacing: 12) {
                        if let product = model.product {
                            // Status row with price.
                            HStack(spacing: 8) {
                                Image(systemName: model.isSubscribed ? "checkmark.seal.fill" : "crown")
                                    .foregroundStyle(model.isSubscribed ? .green : .secondary)
                                Text(model.isSubscribed ? "Active Subscription" : "Not Subscribed")
                                    .font(.subheadline)
                                    .foregroundStyle(model.isSubscribed ? .green : .secondary)
                                Spacer()
                                Text(product.displayPrice)
                                    .font(.headline)
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                            }

                            // Start the StoreKit 2 subscription purchase flow.
                            Button {
                                Task { await model.purchase() }
                            } label: {
                                HStack {
                                    Image(systemName: model.isSubscribed ? "checkmark" : "crown.fill")
                                    Text(model.isSubscribed ? "Subscribed" : "Subscribe to Premium")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isSubscribed || model.isPurchasing)
                            .opacity(model.isSubscribed || model.isPurchasing ? 0.7 : 1)

                            // Spinner while purchase is processing.
                            if model.isPurchasing {
                                ProgressView("Processing…")
                                    .progressViewStyle(.circular)
                            }

                            // Restore and Manage actions.
                            HStack(spacing: 12) {
                                Button("Restore Purchases") {
                                    Task { await model.restore() }
                                }
                                .buttonStyle(.bordered)

                                // iOS 16+: Present system sheet to manage subscription for this app.
                                if #available(iOS 16.0, *) {
                                    Button("Manage Subscription") { showManageSubscriptions = true }
                                        .buttonStyle(.bordered)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            // Product not yet loaded or misconfigured.
                            ContentUnavailableView(
                                "Subscription Unavailable",
                                systemImage: "exclamationmark.triangle",
                                description: Text("Add a StoreKit Configuration file and replace the subscription product ID in SubscriptionViewModel.")
                            )
                        }

                        // Status messages from the model (errors, results, etc.).
                        if let message = model.message {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Subscription")
            // Manual refresh to reload product metadata and entitlement state.
            .toolbar { ToolbarItem(placement: .topBarTrailing) { refreshButton } }
            // Present the system manage subscriptions UI if available.
            .ifAvailableManageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        }
    }

    // Simple refresh button to re-fetch product and subscription status.
    private var refreshButton: some View {
        Button {
            Task { await model.refresh() }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .help("Refresh product and entitlement state")
    }
}

// MARK: - ViewModel
/// A lightweight StoreKit 2 view model for a single auto‑renewable subscription.
/// Responsibilities:
/// - Load the subscription Product
/// - Initiate purchase and handle outcomes
/// - Restore purchases via AppStore.sync()
/// - Listen to Transaction.updates for changes
/// - Compute active entitlement via Transaction.latest(for:)
@MainActor
final class SubscriptionViewModel: ObservableObject {
    // Replace with your real subscription product identifier from App Store Connect
    // and your StoreKit Configuration file (.storekit) for local testing.
    private let subscriptionProductIdentifier = "com.example.app.premium.monthly" // TODO: Replace with your subscription ID

    // UI-facing state
    @Published var product: Product?
    @Published var isSubscribed: Bool = false
    @Published var isPurchasing: Bool = false
    @Published var message: String?

    private var transactionListenerTask: Task<Void, Never>?

    init() {
        // Begin by loading product info and current entitlement status.
        Task { await refresh() }
        // Start observing transactions to stay in sync with App Store changes.
        listenForTransactions()
    }

    deinit { transactionListenerTask?.cancel() }

    /// Refreshes product metadata and current subscription status.
    func refresh() async {
        await loadProduct()
        await refreshSubscriptionStatus()
    }

    /// Loads the subscription Product from the App Store for the known identifier.
    func loadProduct() async {
        message = nil
        do {
            let products = try await Product.products(for: [subscriptionProductIdentifier])
            self.product = products.first
            if products.first == nil {
                self.message = "No subscription found for ID: \(subscriptionProductIdentifier)"
            }
        } catch {
            self.product = nil
            self.message = "Failed to load subscription: \(error.localizedDescription)"
        }
    }

    /// Initiates a subscription purchase. On verified success, finish and refresh status.
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
                    await transaction.finish()
                    await refreshSubscriptionStatus()
                    message = "Subscription successful!"
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

    /// Triggers an App Store sync to restore purchases and then refreshes status.
    func restore() async {
        message = nil
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
            message = "Restored purchases."
        } catch {
            message = "Restore failed: \(error.localizedDescription)"
        }
    }

    /// Computes whether the subscription is currently active.
    /// Active = verified, not revoked, and not expired (expirationDate in the future or nil).
    func refreshSubscriptionStatus() async {
        // For subscriptions, latest(for:) returns the most recent transaction for this product.
        // Consider the entitlement active when there's no revocation and the expiration is in the future (or nil).
        if let result = await Transaction.latest(for: subscriptionProductIdentifier) {
            switch result {
            case .verified(let transaction):
                let notRevoked = (transaction.revocationDate == nil)
                let notExpired = transaction.expirationDate.map { $0 > Date() } ?? true
                self.isSubscribed = notRevoked && notExpired
            case .unverified:
                self.isSubscribed = false
            }
        } else {
            self.isSubscribed = false
        }
    }

    /// Observes Transaction.updates and reacts to changes for this subscription product.
    private func listenForTransactions() {
        transactionListenerTask?.cancel()
        transactionListenerTask = Task.detached { [subscriptionProductIdentifier] in
            for await update in Transaction.updates {
                switch update {
                case .verified(let transaction) where transaction.productID == subscriptionProductIdentifier:
                    await transaction.finish()
                    await self.refreshSubscriptionStatus()
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Feature Views (pure UI)
/// Visible when not subscribed. Encourages upgrading to see advanced content.
private struct SampleFeatureView: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .frame(height: 180)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.title)
                            Text("Sample Feature")
                                .font(.headline)
                            Text("Subscribe to access advanced capabilities.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    )
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sample feature")
    }
}

/// Visible when the subscription is active. A simple animated card.
private struct AdvancedFeatureView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Gradient(colors: [.indigo, .blue, .teal]))
                .hueRotation(.degrees(animate ? 60 : 0))
                .frame(height: 220)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                        Text("Advanced Feature")
                            .font(.title3).bold()
                            .foregroundStyle(.white)
                        Text("Thanks for subscribing! ✨")
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
        .accessibilityLabel("Advanced feature unlocked")
    }
}

// MARK: - Helpers
private extension View {
    // Conditionally attach manageSubscriptionsSheet for iOS 16+
    @ViewBuilder
    func ifAvailableManageSubscriptionsSheet(isPresented: Binding<Bool>) -> some View {
        if #available(iOS 16.0, *) {
            self.manageSubscriptionsSheet(isPresented: isPresented)
        } else {
            self
        }
    }
}

#Preview {
    SubscriptionView()
}

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
//  A simple home screen that acts as a navigation hub for the demo.
//  It links to:
//   - ContentView: One‑time non‑consumable purchase that unlocks a feature
//   - SubscriptionView: Auto‑renewable subscription that unlocks an advanced feature
//
//  It also shows small status badges indicating current entitlement state for
//  each path, using Transaction.latest(for:) checks.
//

import SwiftUI
import StoreKit

struct HomeView: View {
    // Keep these IDs in sync with ContentView and SubscriptionView.
    // Replace with your real product identifiers (or your .storekit config IDs) when testing.
    private let iapProductID = "com.example.app.samplefeature" // non-consumable
    private let subscriptionProductID = "com.example.app.premium.monthly" // auto-renewable

    // Simple UI state reflecting entitlement checks.
    @State private var isIAPPurchased: Bool = false
    @State private var isSubscribed: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section("StoreKit 2 Demos") {
                    // Navigate to the one‑time purchase demo.
                    NavigationLink {
                        ContentView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.open")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("One‑time Purchase")
                                    .font(.headline)
                                Text("Unlock Sample Feature")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            // Shows current entitlement for the IAP.
                            StatusTag(text: isIAPPurchased ? "Unlocked" : "Locked", active: isIAPPurchased)
                        }
                    }

                    // Navigate to the subscription demo.
                    NavigationLink {
                        SubscriptionView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "crown")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Subscription")
                                    .font(.headline)
                                Text("Advanced Feature")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            // Shows current subscription status.
                            StatusTag(text: isSubscribed ? "Active" : "Inactive", active: isSubscribed)
                        }
                    }
                }
            }
            .navigationTitle("Demo Home")
            // Manual refresh button in the nav bar.
            .toolbar { ToolbarItem(placement: .topBarTrailing) { refreshButton } }
            // Kick off entitlement checks on first appearance and when the task modifier runs.
            .task { await refreshEntitlements() }
            .onAppear { Task { await refreshEntitlements() } }
        }
    }

    // Simple toolbar button to re-check entitlements.
    private var refreshButton: some View {
        Button {
            Task { await refreshEntitlements() }
        } label: {
            Image(systemName: "arrow.clockwise")
        }
        .help("Refresh entitlement status")
    }

    // MARK: - Entitlement Checks
    // Runs both checks concurrently and updates the UI on the main actor.
    @MainActor
    private func refreshEntitlements() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await checkIAPPurchase() }
            group.addTask { await checkSubscription() }
        }
    }

    /// Checks ownership of the non‑consumable IAP using the latest transaction.
    private func checkIAPPurchase() async {
        if let result = await Transaction.latest(for: iapProductID) {
            switch result {
            case .verified(let transaction):
                // Consider revoked or upgraded transactions as not currently owned.
                let owned = (transaction.revocationDate == nil) && !transaction.isUpgraded
                await MainActor.run { self.isIAPPurchased = owned }
            case .unverified:
                await MainActor.run { self.isIAPPurchased = false }
            }
        } else {
            await MainActor.run { self.isIAPPurchased = false }
        }
    }

    /// Checks active subscription status using expiration and revocation.
    private func checkSubscription() async {
        if let result = await Transaction.latest(for: subscriptionProductID) {
            switch result {
            case .verified(let transaction):
                let notRevoked = (transaction.revocationDate == nil)
                let notExpired = transaction.expirationDate.map { $0 > Date() } ?? true
                await MainActor.run { self.isSubscribed = notRevoked && notExpired }
            case .unverified:
                await MainActor.run { self.isSubscribed = false }
            }
        } else {
            await MainActor.run { self.isSubscribed = false }
        }
    }
}

// MARK: - Small UI helper for status badges
private struct StatusTag: View {
    let text: String
    let active: Bool

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(active ? Color.green.opacity(0.15) : Color.secondary.opacity(0.15))
            )
            .foregroundStyle(active ? Color.green : Color.secondary)
    }
}

#Preview {
    HomeView()
}

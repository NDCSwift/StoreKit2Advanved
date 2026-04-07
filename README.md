# 💳 StoreKit 2 Advanced
Advanced in-app purchase patterns with StoreKit 2 — subscriptions, entitlements, and transaction management.

---

## 🤔 What this is
This project goes beyond a basic StoreKit 2 setup to cover advanced IAP scenarios: restoring purchases, handling subscription renewals, verifying transactions, and managing entitlement logic in SwiftUI. It builds on the fundamentals to show how a production-ready IAP system works.

## ✅ Why you'd use it
- **Transaction verification** — Shows how to use `Transaction.currentEntitlements` and verify receipts with StoreKit 2's async API
- **Subscription management** — Covers renewal status, grace periods, and subscription group handling
- **Entitlement logic** — Demonstrates how to gate features based on active purchases across the app

## 📺 Watch on YouTube
[![Watch on YouTube](https://img.shields.io/badge/YouTube-Watch%20the%20Tutorial-red?style=for-the-badge&logo=youtube)](https://youtu.be/BI-ohzQ7GuI)

> This project was built for the [NoahDoesCoding YouTube channel](https://www.youtube.com/@NoahDoesCoding97).

---

## 🚀 Getting Started

### 1. Clone the Repo
```bash
git clone https://github.com/NDCSwift/StoreKit2Advanved.git
cd StoreKit2Advanved
```

### 2. Open in Xcode
Double-click `StoreKit2IAPExample.xcodeproj`.

### 3. Set Your Development Team
In Xcode: **TARGET → Signing & Capabilities → Team** — select your team.

### 4. Update the Bundle Identifier
Change `com.example.MyApp` to a unique reverse-domain ID matching your App Store Connect app.

## 🛠️ Notes
- In-app products must be configured in App Store Connect before they'll load.
- Use the StoreKit configuration file (`.storekit`) for Simulator testing.
- If code signing fails, verify your Team and Bundle ID match App Store Connect.

## 📦 Requirements
- Xcode 15+
- iOS 16+
- App Store Connect account with configured in-app purchases

📺 [Watch the guide on YouTube](https://youtube.com/watch?v=PLACEHOLDER)

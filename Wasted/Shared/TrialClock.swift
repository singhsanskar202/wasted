import Foundation

// FREEMIUM, NOT TRIAL-THEN-DARK. The daily mirror — the number, the receipt,
// the nudges, the island, the widget — is free, forever. A mirror that goes
// dark unless you pay is a threat, not a product. Pro buys the one thing worth
// paying for: MEMORY. The long receipt — weeks, months, the all-time bill —
// unlocks with a one-time lifetime purchase.
//
// (This file keeps the name TrialClock.swift: two extension targets reference
// it by path in the project's membershipExceptions.)
enum ProGate {
    // SHIP MODE (2026-07-25): paywall ON. The lifetime IAP exists in App Store
    // Connect, so the paywall shows the real price and Pro gates the long
    // receipt. Flipping this also removed the beta diagnostics button (gated on
    // the same flag). Set back to false only to hand a fully-unlocked build to
    // a tester whose IAP isn't live.
    static let paywallEnabled = true

    /// What the app acts on. Respects the beta override.
    static func isPro(unlocked: Bool) -> Bool {
        paywallEnabled ? unlocked : true
    }
}

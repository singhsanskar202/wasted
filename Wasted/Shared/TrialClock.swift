import Foundation

// FREEMIUM, NOT TRIAL-THEN-DARK. The daily mirror — the number, the receipt,
// the nudges, the island, the widget — is free, forever. A mirror that goes
// dark unless you pay is a threat, not a product. Pro buys the one thing worth
// paying for: MEMORY. The long receipt — weeks, months, the all-time bill —
// unlocks by monthly or yearly subscription, or a one-time lifetime purchase.
//
// The old local 7-day trial clock is gone. The App Store introductory offer on
// the yearly plan is the trial now, and StoreKit runs that clock — the app
// never has to blur a number a user is trying to read.
//
// (This file keeps the name TrialClock.swift: two extension targets reference
// it by path in the project's membershipExceptions.)
enum ProGate {
    // ═══════════════════════════════════════════════════════════════════
    //  BETA: EVERYTHING IS UNLOCKED.  Set this to `true` before shipping.
    // ═══════════════════════════════════════════════════════════════════
    //
    // The purchase flow, the gate and the paywall all stay intact and tested
    // underneath — this only stops beta testers from hitting a paywall whose
    // products don't exist in App Store Connect yet. The app logs "PAYWALL
    // DISABLED" at every launch so a build that shipped with this off is
    // obvious in the first lines of its own log.
    static let paywallEnabled = false

    /// What the app acts on. Respects the beta override.
    static func isPro(unlocked: Bool) -> Bool {
        paywallEnabled ? unlocked : true
    }
}

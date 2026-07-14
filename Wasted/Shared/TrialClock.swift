import Foundation

enum TrialState: Equatable {
    case trial(daysLeft: Int)
    case expired
    case unlocked
}

// The trial is measured locally from first launch, not via StoreKit — a
// non-consumable has no built-in trial mechanism. Recording never stops;
// only what the trial state gates is what's *shown*.
enum TrialClock {
    static let trialDays = 7

    // ═══════════════════════════════════════════════════════════════════
    //  BETA: THE PAYWALL IS OFF.  Set this back to `true` before shipping.
    // ═══════════════════════════════════════════════════════════════════
    //
    // Nothing is deleted — the trial clock, the expired state, the blur, the
    // paywall and the StoreKit purchase flow are all intact and still fully
    // covered by tests, which exercise `trialState(...)` directly. This switch
    // only stops the trial from expiring underneath a tester mid-session, which
    // would silently blur the number they're trying to look at and make every
    // other bug impossible to see.
    //
    // The app logs "PAYWALL DISABLED" at every launch so a build that shipped
    // with this flag off is obvious in the very first line of its log.
    static let paywallEnabled = false

    /// What the app actually acts on. Respects the beta override.
    static func state(firstLaunch: Date?, unlocked: Bool, now: Date = Date()) -> TrialState {
        guard paywallEnabled else { return .unlocked }
        return trialState(firstLaunch: firstLaunch, unlocked: unlocked, now: now)
    }

    /// The real trial logic, independent of the override — this is what the
    /// tests exercise, so turning the paywall off for a beta can never quietly
    /// stop the paywall itself from being verified.
    static func trialState(firstLaunch: Date?, unlocked: Bool, now: Date = Date()) -> TrialState {
        if unlocked { return .unlocked }
        guard let firstLaunch else { return .trial(daysLeft: trialDays) }

        let elapsedSeconds = max(0, now.timeIntervalSince(firstLaunch))
        let wholeDaysSince = Int(elapsedSeconds / 86400)
        let daysLeft = max(0, trialDays - wholeDaysSince)
        return daysLeft > 0 ? .trial(daysLeft: daysLeft) : .expired
    }
}

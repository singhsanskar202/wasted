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

    static func state(firstLaunch: Date?, unlocked: Bool, now: Date = Date()) -> TrialState {
        if unlocked { return .unlocked }
        guard let firstLaunch else { return .trial(daysLeft: trialDays) }

        let elapsedSeconds = max(0, now.timeIntervalSince(firstLaunch))
        let wholeDaysSince = Int(elapsedSeconds / 86400)
        let daysLeft = max(0, trialDays - wholeDaysSince)
        return daysLeft > 0 ? .trial(daysLeft: daysLeft) : .expired
    }
}

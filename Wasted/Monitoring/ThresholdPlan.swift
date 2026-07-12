import Foundation

// iOS never reports "Instagram is at 47 minutes". It only calls back when a
// threshold you registered in advance is crossed. So the spacing of these
// thresholds IS the freshness of every surface in the app — the widget, the
// island, the home number, the nudges. Nothing can be fresher than the grid.
//
// Measured on device: the widget updated every 5-8 minutes at ~2h50m of usage.
// That band was on 2-minute steps, and DeviceActivity adds its own delivery lag
// on top. Tightening the grid is the only lever we have.
//
// The catch: DeviceActivityCenter.startMonitoring registers every event in one
// call and throws as a WHOLE if the set exceeds an undocumented cap — and a
// throw means the day records nothing at all. The cap isn't published and moves
// with the number of tracked apps, so guessing a single grid is a gamble with
// the user's whole day. Instead we describe several grids, finest first, and let
// ActivityScheduler try each until one registers.
struct ThresholdPlan {
    let name: String
    // "total:N" — usage across ALL tracked apps. Drives the island, the widget,
    // and the home number, so this is the one worth spending events on.
    let combined: [Int]
    // "index:N" — one app's usage. Drives nudges and the receipt breakdown.
    // Multiplied by the number of tracked apps, so it's the expensive one.
    let perApp: [Int]

    func eventCount(appCount: Int) -> Int {
        combined.count + perApp.count * appCount
    }

    // Every plan must land on every 15-minute multiple, or the nudge at that
    // mark simply never fires — the gate only sees thresholds that exist.
    var coversNudgeSteps: Bool {
        guard let last = perApp.last else { return false }
        let steps = stride(from: NudgeGate.stepMinutes, through: last, by: NudgeGate.stepMinutes)
        return steps.allSatisfy(perApp.contains)
    }
}

extension ThresholdPlan {
    // All plans now run to 12h, not 8h. The old grids stopped at 480 minutes,
    // so a heavier day than that silently froze the number at 8h forever — the
    // worst possible failure for an app whose whole promise is that the number
    // keeps going up.
    static let ladder: [ThresholdPlan] = [fine, medium, coarse]

    // Every minute, all the way to 8h. What we want if the cap allows it.
    static let fine = ThresholdPlan(
        name: "fine",
        combined: Array(1...480) + Array(stride(from: 485, through: 720, by: 5)),
        perApp: Array(1...5)
            + Array(stride(from: 10, through: 240, by: 5))
            + Array(stride(from: 255, through: 720, by: 15))
    )

    // Every minute to 4h — past that, a minute of drift on a 4-hour number is
    // noise. Per-app coarsens first, since it's the count multiplied by apps.
    static let medium = ThresholdPlan(
        name: "medium",
        combined: Array(1...240) + Array(stride(from: 245, through: 720, by: 5)),
        perApp: Array(1...5)
            + Array(stride(from: 10, through: 120, by: 5))
            + Array(stride(from: 135, through: 720, by: 15))
    )

    // The floor: what shipped before, extended to 12h. Still fires every minute
    // for the first 2h, which covers most single sessions.
    static let coarse = ThresholdPlan(
        name: "coarse",
        combined: Array(1...120)
            + Array(stride(from: 122, through: 240, by: 2))
            + Array(stride(from: 245, through: 720, by: 5)),
        perApp: Array(1...5) + Array(stride(from: 15, through: 720, by: 15))
    )
}

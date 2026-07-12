# Wasted — security & bug audit (2026-07-12)

> **Status:** P0 and both P1s are **FIXED** (see the notes under each). The two
> P2s are left open on purpose — one is a documented tradeoff, the other only
> matters once monetization ships.

Audit of `main` (GitHub: https://github.com/singhsanskar202/wasted) across all
four targets (Wasted, DeviceActivityMonitorExt, LiveActivityExt, WastedTests).
Priority follows this repo's existing P-scale (see `open-problems.md`): **P0**
= will crash or lose data for a real user, fix before shipping further;
**P1** = real defect, degrades a feature but doesn't crash/lose core data;
**P2** = low impact or a documented design tradeoff, fix opportunistically.

---

## P0

### Crash risk — force-unwrapped App Group access
**File:** `Wasted/Shared/Storage/UsageStore.swift:6`
`UserDefaults(suiteName: AppGroupKeys.appGroupID)!` force-unwraps the shared
suite. If the App Group entitlement isn't provisioned correctly on device —
which is exactly the situation the free dev account is in today (see
`project-wasted` memory: App Groups blocked until paid account) — this
crashes on `UsageStore()` init. `UsageStore` is instantiated from the main
app, the `DeviceActivityMonitor` extension, and background tasks, so the
crash surfaces in whichever process inits it first.
**Fix direction:** fail soft (return a non-persisting in-memory defaults, or
log + no-op) instead of force-unwrapping, so a provisioning hiccup degrades
functionality instead of taking down the process.

**FIXED.** The suite now resolves through `UserDefaults.wastedShared`, which
falls back to `.standard` and writes a loud `EventLog.error` naming the
entitlement. A provisioning problem now degrades the app (nothing is shared
between processes) instead of executing it. The log says which one it is.

---

## P1

### Hourly heatmap misattributes usage to the wrong hour
**File:** `DeviceActivityMonitorExtension.swift:132` → `UsageStore.addHourlySeconds`
(`DailyUsage.swift:71`)
Stamps elapsed seconds using `Calendar.current.component(.hour, from: Date())`
at *delivery* time, not when the usage actually happened. Given the
extension's own documented 5–8 min delivery lag, plus replay bursts from
`includesPastActivity` re-registration, usage from e.g. 11:55–12:07 delivered
late at 12:09 lands entirely in hour 12, none in hour 11.
**Impact:** cosmetic — corrupts the danger-zones heatmap, not
`combinedSecondsToday` (the real total stays correct).

**FIXED.** `addHourlySeconds(_:endingAt:)` now walks the seconds *backwards*
from the event and splits them across the hours they actually spanned
(`UsageStore.hourlySplit`, pure + calendar-injectable). 12 minutes delivered at
12:09 now puts 3 minutes in hour 11 and 9 in hour 12. Clipped at midnight so it
never writes into an archived day, with the remainder pinned to hour 0 so the
heatmap still sums to the day's true total. Boundary cases are pinned by
`HourlyAttributionTests`.

### Silent data loss if the threshold ladder is rejected
**File:** `ActivityScheduler.swift:105`
If DeviceActivity's undocumented per-app event cap rejects every
`ThresholdPlan` in the ladder, the day silently records nothing — no retry,
no user-facing signal, just a log line. A user tracking enough apps could
lose an entire day of data with zero indication in the UI.
**Fix direction:** at minimum, detect the all-rejected case and surface it
(log is not enough — consider a degraded-tracking banner or a coarser
fallback plan).

**FIXED, both halves.**

*Coarser fallback:* the ladder now ends in `ThresholdPlan.totalOnly`, which
drops the per-app series entirely and keeps the combined one. Per-app events are
the expensive ones — their count is multiplied by the number of tracked apps —
so a user tracking many apps could blow the cap on that series alone. The floor
plan's cost is **fixed** regardless of app count (asserted at 50 apps), so the
headline number, island, widget and heatmap survive even in the worst case. The
cost is nudges and the receipt breakdown.

*Surfaced:* `trackingFailedKey` / `trackingDegradedKey` in the App Group drive a
red banner at the top of HomeView. This mattered more than it looks: the failure
mode is that the number simply **never moves**, so the user doesn't see an error
— they see a low number, and they might *believe* it. An app whose whole promise
is "you can't unsee the number" cannot quietly show a false one. The banner says
*"tracking is off. this number is not real."* with a retry.

---

## P2

### Trial resets by clearing app data
**File:** `TrialClock.swift` (reads `UsageStore.firstLaunchDate`)
Trial state is derived purely from a UserDefaults timestamp in the shared App
Group container. Deleting the app (or just the group container) and
reinstalling resets the 7-day trial indefinitely. Low real-world impact for
a personal/indie app; only matters once monetization ships.

### Notification identifier collision across days
**File:** `NotificationScheduler.swift:20`
`"wasted.nudge.\(appName).\(minutes)"` has no date component. This is
intentional — it collapses replay-burst duplicates — but it also means that
if the same threshold is reached on two different days before the first
notification is read/cleared, the second silently replaces the first instead
of delivering separately. Documenting as a known tradeoff, not a bug to fix.

---

## Clean / no issues found
No hardcoded secrets, API keys, or tokens. Entitlements
(`application-groups`, `family-controls`) are consistent and not over-broad
across all four targets. StoreKit 2 verification in `LifetimeStore` is
handled correctly, including revocation via `refreshEntitlement`. `EventLog`'s
cross-process file writes use `O_APPEND` correctly — no race condition.
`InsightEngine` and `DailyReceipt` array/division logic have adequate bounds
and zero-division guards despite heavy array indexing.

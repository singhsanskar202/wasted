---
name: project-wasted
description: Wasted — iOS screen time awareness app. Builds on Xcode 26.6 / iOS 26.5 sim, 61 tests pass. Mirror-polish pass shipped 2026-07-06 (differentiation onboarding, haptics, 30-min nudges, daily receipt, peak-hour insight, §2 palette).
metadata: 
  node_type: memory
  type: project
  originSessionId: 329444d4-ba54-4700-8297-c235c24e4d9a
---

**Wasted** is an iOS app (iPhone 14 Pro+, iOS 17+) that tracks per-app screen time, shows a live ticking counter in the Dynamic Island, and confronts the user with blunt usage data. It is a **mirror, not a blocker** — never blocks/locks, no streak guilt, no ads. Monetization deferred (fully free for personal testing; paywall seam noted in `ActivityScheduler.startMonitoring`).

**GitHub:** https://github.com/singhsanskar202/wasted  
**Local project:** `/Users/sanskarsingh/Documents/wasted/Wasted/`

---

## Current state (2026-07-06)

**Builds clean** on Xcode 26.6, iOS 26.5 simulator (iPhone 17 Pro). **Tests: 61/61 pass** (`xcodebuild -scheme Wasted test`).

> If `xcodebuild` reports "CoreSimulator is out of date", any `xcrun simctl` command reloads the stale service; a Mac restart also fixes it.

**Architecture — 3 Xcode targets + tests:** `Wasted` (app), `DeviceActivityMonitorExt`, `LiveActivityExtExtension`, `WastedTests`.
**Key identifiers:** Bundle `com.sanskar.Wasted`, App Group `group.com.sanskar.Wasted`, Team `ZZZ87SSQ8S` (free account), target iOS 26.5.

---

## What shipped 2026-07-06 ("mirror polish" pass)

Spec/plan: `docs/superpowers/{specs,plans}/2026-07-06-mirror-polish.md` (includes full audit table).

- **Theme (`Wasted/Theme.swift`, app target only):** `Color.canvas` #0A0A0A, `.ink` #F5F3EE, `.inkFaint`, `.alarm` (red, reserved for bad numbers only) + `Haptics` enum. Orange accents removed everywhere; heatmap peak goes red only when the peak hour ≥1h; receipt total red only ≥1h (matches Dynamic Island rule).
- **Onboarding re-sequenced:** Hook → **DifferentiationView (new, "this won't block anything.")** → Screen Time permission → AppPicker → Notification permission → Done. *Picker must come after permission — `familyActivityPicker` can't list apps without FamilyControls auth (platform constraint; brief wanted picker first).* Haptics wired exactly per the brief's table (one heavy: DoneView entrance). Reduced motion respected in all staggered/entrance animations. NotificationPermissionView copy now says "a nudge every 30 minutes you keep scrolling. one receipt at night."
- **30-min nudges:** `Wasted/Shared/Nudges.swift` (both targets) — `NudgeGate.shouldNudge` (30-min multiples, monotonic per app per day, 10-min wall-clock gap against threshold bursts), `NudgeCopy` (6 lowercase bodies, no exclamations/guilt). `UsageStore.lastNudge/recordNudge` under `nudge_records` key. Extension now gates on `NudgeGate` instead of `minutes % 60`.
- **Daily receipt:** `Wasted/Shared/DailyReceipt.swift` (both targets) — itemized per-app, total, `percentOfAwakeDay` against `AppGroupKeys.awakeDayHours = 16`. `ReceiptScheduler` (ext) re-schedules a replaceable local notification (id `wasted.receipt`, 21:00 = `AppGroupKeys.receiptHour`) on every threshold event so the 9 PM body has the latest totals; skipped after 21:00. In-app: `Wasted/Receipt/ReceiptView.swift` sheet from a "today's receipt" button on HomeView (light haptic).
- **Peak-hour history insight:** `InsightEngine.historicalPeak(history:)` — costliest contiguous 2-hour window summed across 7-day history + days-active count; needs ≥3 history days. Rendered as serif line on HomeView ("you lose the most time between 9pm–11pm. / 5 of the last 7 days").
- **HomeView:** big number now serif (was `.rounded`), equivalent line serif + emoji dropped, palette swept to canvas/ink.
- **Cleanup:** deleted dead `ContentView.swift`, `AppGridView.swift`, `hourlyUsageKey` helpers. `AppGroupKeys.formattedTime` refactored onto new `formattedDuration(_ seconds:)`.
- **New tests:** NudgeTests, DailyReceiptTests, HistoricalPeakTests, formattedDuration cases (37 → 61).

## Key gotchas (still true)

- `ApplicationToken.bundleIdentifier` is private — event names are `"appIndex:minutes"`; icons keyed by display name.
- `accumulatedStart = Date() - totalSeconds` makes the Live Activity resume from the day's total.
- **Synchronized-group target membership:** shared files used by the extension must be listed in the ext's `membershipExceptions` in `project.pbxproj` (now includes `Shared/Nudges.swift` and `Shared/DailyReceipt.swift`). A missed entry fails with "cannot find type …".
- Big chained functional expressions can hit "unable to type-check in reasonable time" in the ext target — write loops (bit DailyReceipt once).
- `UsageStore.defaults` must stay `internal`; `CODE_SIGNING_REQUIRED = NO` on the ext for the free account; `#if targetEnvironment(simulator)` bypasses onboarding in `WastedApp.swift`.

## Blocked until paid Apple Developer account ($99)
Family Controls entitlement on device, App Groups on device, real Dynamic Island testing, widget targets.

## What's next (to discuss)
1. **On-device validation** of the whole loop (needs paid account): nudge cadence feel, receipt notification timing, Live Activity jumps.
2. Receipt polish: consider firing the receipt on first app open after 9 PM when the notification was missed (currently notification-only + on-demand).
3. TestFlight prep once the loop proves itself; then revisit paid-app plan (paywall seam is in `ActivityScheduler.startMonitoring`).

**How to apply:** Next session, ask whether to start with on-device validation or continue UI polish; don't rebuild what the 2026-07-06 spec already covers.

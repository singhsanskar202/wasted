---
name: project-wasted
description: Wasted — iOS screen time awareness app. Builds on Xcode 26.6 / iOS 26.5 sim, 37 tests pass. Pushed to github.com/singhsanskar202/wasted. Hourly-storage consolidated into DailyUsage.hourly[]; build + test-scheme fixed 2026-06-30.
metadata: 
  node_type: memory
  type: project
  originSessionId: 329444d4-ba54-4700-8297-c235c24e4d9a
---

**Wasted** is an iOS app (iPhone 14 Pro+, iOS 17+) that tracks per-app screen time, shows a live ticking counter in the Dynamic Island, and confronts the user with blunt usage data and actionable insights.

**Why:** Personal digital wellbeing tool → TestFlight friends → App Store.

**GitHub:** https://github.com/singhsanskar202/wasted  
**Local project:** `/Users/sanskarsingh/Documents/wasted/Wasted/`

---

## Current state (2026-06-30)

**Builds clean** on Xcode 26.6, iOS 26.5 simulator (iPhone 17 Pro). **Tests: 37/37 pass.**

> Note: if `xcodebuild` reports "CoreSimulator is out of date" (version mismatch), running any `xcrun simctl` command reloads the stale service and clears it; a Mac restart also fixes it.

**Architecture — 4 Xcode targets:**
- `Wasted` (main app): Onboarding (5 screens), HomeView, InsightEngine, ActivityScheduler
- `DeviceActivityMonitorExt`: DeviceActivityMonitorExtension, LiveActivityManager, NotificationScheduler
- `LiveActivityExt`: Widget extension for Dynamic Island
- `WastedTests`: 37 unit tests (wired into the `Wasted` scheme's TestAction — run via `xcodebuild -scheme Wasted test`)

**Key identifiers:**
- Bundle ID: `com.sanskar.Wasted`
- App Group: `group.com.sanskar.Wasted`
- Team ID: `ZZZ87SSQ8S` (free personal account)
- Dev deployment target: iOS 26.5

---

## What was built this session

### Onboarding (5 screens — remote Xcode project had already done this before session)
Remote repo had a gen-z redesign:
- `HookView` — staggered stat animation ("60 days a year. gone.")
- `PermissionView` — Screen Time auth
- `NotificationPermissionView` — "prove me wrong" notification ask
- `AppPickerView` — raw-tone app picker
- `DoneView` — "no hiding now." with entrance animation
- `OnboardingContainerView` — fade transitions between 5 screens

### HomeView (`Wasted/Home/HomeView.swift`)
Keeps remote's minimalist style:
- Daily quote (date-seeded, same quote all day)
- "you wasted Xh Ym on your phone today" big centered text with spring animation
- EquivalentTaskMapper — maps total seconds to motivational activities ("that's a full workout 💪")
- HeatmapView (after 7 days) or PatternLockedView (countdown + ghost bars)
- **DangerZonesCard + WeeklyCard inserted below heatmap section** (new this session)

### InsightEngine (`Wasted/Insights/InsightEngine.swift`)
Pure rule engine — 11 priority-ordered rules:
1. Nothing today → "Clean so far. Come back tonight." (positive)
2. >30% drop vs yesterday → "X% less than yesterday." (positive)
3. Yesterday's peak hour is clean today → "You skipped the Xpm habit." (positive)
4. Under 1 hour total → "Under an hour total. That's rare." (positive)
5. Single zone eats >50% → "Kill the X–Xpm zone and you cut today's waste in half." (warning)
6. 3+ danger zones → "N danger zones." (warning)
7. >15% worse than yesterday → "X% more than yesterday." (warning)
8. 4h+ clean streak, no warnings fired → "Xh clean streak. Don't break it." (neutral)
9. Scattered across >4 zones → "No single zone to cut." (neutral)
10. Default: biggest zone named (neutral)
11. Fallback → positive

Thresholds: low=5min, moderate=30min, danger=60min per hour slot.

### DangerZonesCard (`Wasted/Home/DangerZonesCard.swift`)
- 24h color timeline strip: clean/low/moderate/danger (option C from mockup)
- Legend row
- Zone cards: DANGER/MOD/LOW pill + time range + apps + seconds
- Verdict banner: green (positive), neutral gray, red-tinted (warning)
- Card title flips: "CLEAN ZONES" / "USAGE PATTERN" / "DANGER ZONES"

### WeeklyCard (`Wasted/Home/WeeklyCard.swift`)
- Unlocks after 7 days of history
- Bar chart of last 7 days, bars brighten toward most recent
- ↓ IMPROVING / → FLAT / ↑ WORSENING trend badge
- Verdict banner with matching tone

### Data layer additions
- `DailyUsage.hourly[24]` — backward-compat decode (missing field defaults to all-zeros)
- `DailyUsage.dateString(from:)` static helper
- `UsageStore.addHourlySeconds(_:)` — buckets into current hour in DailyUsage.hourly
- `UsageStore.archiveToHistory(_:)` — rolling 7-day history
- `UsageStore.loadHistory() -> [DailyUsage]`
- `UsageStore.loadYesterday() -> DailyUsage?`
- `AppGroupKeys.historyKey` + `daysTrackedKey`
- `DeviceActivityMonitorExtension` archives today on `intervalDidEnd`, increments `daysTrackedKey` on `intervalDidStart`

---

## Key technical decisions / gotchas

- `ApplicationToken.bundleIdentifier` is private — event names use `"appIndex:minutes"` format
- `Application.token` is `ApplicationToken?` — always guard-unwrap
- `accumulatedStart = Date() - totalSeconds` makes SwiftUI `.timer` style tick live
- **Hourly storage (refactored 2026-06-30):** `UsageStore+Hourly.swift` and the old `hourly_usage_<date>` App Group keys are GONE. `HourlyUsage` now lives in `Wasted/Shared/Models/HourlyUsage.swift`; `UsageStore.loadTodayHourly()` derives a `HourlyUsage` from the `DailyUsage.hourly[24]` array (single source of truth). `HomeView.heatmapDaysLeft` now uses `store.loadHistory().count`.
- **Target membership matters with synchronized groups:** `UsageStore.swift` is compiled into `DeviceActivityMonitorExt`, so any type it references must also be in that target. `HourlyUsage.swift` had to be added to the ext's `membershipExceptions` in `project.pbxproj` or the ext fails with "cannot find type 'HourlyUsage'". (The dead `hourlyUsageKey`/`hourlyUsageKeyPrefix` helpers still linger in `AppGroupKeys.swift` — harmless, safe to delete later.)
- `EquivalentTaskMapper` is **main app target only** — removed from `NotificationScheduler` (extension target)
- `UsageStore.defaults` must be `internal` (not `private`) so shared extension files can access it
- `CODE_SIGNING_REQUIRED = NO` on DeviceActivityMonitorExt for free developer account
- `#if targetEnvironment(simulator)` in `WastedApp.swift` bypasses onboarding on simulator

---

## What's blocked until paid Apple Developer account ($99)
- Family Controls entitlement → DeviceActivity tracking on device
- App Groups on device → inter-extension data sharing
- Real Dynamic Island testing

---

## What's next (to discuss)
1. **Dynamic Island redesign** — current has blank placeholder icon, basic timer format, no ragebait copy on lock screen. Agreed it needs: real icon, `Xh Ym` format (red only above 1h), "still here?" nudge line on lock screen.
2. **Widget target** — needs paid developer account (new Xcode target). Discussed: accessoryCircular + accessoryRectangular lock screen widgets.
3. **Receipt section in HomeView** — per-app seconds breakdown (designed in mockup, not yet in code — remote's minimalist HomeView doesn't have it).

**How to apply:** When user opens next session on this project, pick up from Dynamic Island redesign or receipt section — confirm which they want to tackle first.

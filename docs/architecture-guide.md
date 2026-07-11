# Wasted Architecture Guide

## System overview

Wasted is a screen time tracking app built on iOS 17+ native frameworks. It uses the Family Controls framework to monitor app usage, ActivityKit for the Dynamic Island, and StoreKit 2 for the one-time purchase. The architecture spans four Xcode targets: the main app, a device activity monitor extension, a live activity extension, and a widget extension.

**Core principle:** the app is stateless. It queries current usage on every foreground and pushes updates to the Dynamic Island. The extension tracks in the background and records thresholds to shared storage. The Live Activity ticks from a calculated anchor point, avoiding the need for frequent updates from the background.

---

## Targets & responsibilities

### Wasted (main app)

**Purpose:** user-facing home screen, onboarding, settings, receipt view, and trial/paywall logic.

**Key classes:**
- `WastedApp` – app lifecycle, background refresh scheduling, live activity initialization
- `HomeView` – home screen rendering, refresh loop, receipt/paywall sheet presentation
- `OnboardingContainerView` – onboarding sequence (Hook → Differentiation → Permission → AppPicker → Notifications → Done)
- `UsageStore` – read/write usage data from App Group defaults
- `LifetimeStore` – StoreKit 2 purchase flow, entitlement caching
- `ActivityScheduler` – Family Controls authorization, app picker, threshold configuration
- `LiveActivityManager` – ActivityKit request and update calls
- `InsightEngine` – compute daily insights (peak hours, danger zones, reality checks)

**Shared code in this target only:**
- Theme system (`Theme.swift`)
- Monetization views (`PaywallView`, `ReceiptView`)
- Onboarding screens (all of `Wasted/Onboarding/`)

### DeviceActivityMonitorExt (extension target)

**Purpose:** background monitoring of app usage, threshold detection, notification scheduling, and widget refresh.

**Key classes:**
- `DeviceActivityMonitorExtension` – entry point, `eventDidReachThreshold` and `intervalDidStart/End` handlers
- `NotificationScheduler` – nudge notification logic, 30-minute gate, copy selection
- `ReceiptScheduler` – nightly receipt notification at 21:00 (9 PM)
- `LiveActivityManager` – push updates to the Live Activity (stale-date management)

**Shared code:** uses `Shared/` files (models, nudge logic, receipt building) that are membershipExceptions in the pbxproj.

### LiveActivityExt (widget extension target for ActivityKit)

**Purpose:** Dynamic Island rendering.

**Key classes:**
- `TimeTrackerLiveActivityView` – renders all four surfaces (compact, minimal, expanded, lock screen)
- `TimeTrackerAttributes` – ActivityKit attributes and state schema

**Constraints:** no access to Family Controls, app tokens, or display names. Renders only from the shared `TimeTrackerAttributes`, which carry the anchor date and last-confirmed total.

### WastedWidget (widget extension target, iOS 17+)

**Purpose:** home screen widget showing today's usage.

**Key classes:**
- `WastedWidget` – TimelineProvider for widget refresh
- Support files (copied from `Wasted/Shared/`)

**Constraints:** widget is gated by trial/purchase state; shows `??m` with an unlock prompt if expired.

---

## Data flow

### Usage tracking flow

```
User opens app A
    ↓
[OS] Usage time increments
    ↓
[OS] at 1m threshold: DeviceActivityMonitorExt.eventDidReachThreshold fires
    ↓
Extension records in App Group UserDefaults:
    - daily_usage (JSON: app index → seconds)
    - nudge_records (JSON: app index → last nudged time)
    - nudge_gate evaluates: 30-min steps, 10-min gap minimum
    ↓
If nudge eligible: NotificationScheduler fires local notification
    ↓
Always: ReceiptScheduler updates the 21:00 receipt notification
    ↓
Always: LiveActivityManager updates ContentState with new total
    ↓
WidgetCenter.reloadAllTimelines() → widget refreshes
    ↓
User foregrounds Wasted app
    ↓
HomeView polls UsageStore.totalSecondsAllApps() every 5 seconds
    ↓
Display updates (number ticks up, heatmap redraws)
```

### State storage

All state lives in **App Group UserDefaults** (`group.com.sanskar.Wasted`), not the main app's defaults. This allows the extension to read and update usage without launching the main app.

| Key | Type | Owner | Purpose |
|---|---|---|---|
| `daily_usage` | JSON dict | extension | app index → seconds today |
| `usage_history` | JSON array | main app | [DailyUsage] for last 28 days |
| `display_names` | JSON dict | extension | app index → localized name |
| `app_tokens` | JSON dict | extension | app index → ApplicationToken (for home screen) |
| `tracked_selection` | binary | extension | FamilyActivitySelection archive |
| `nudge_records` | JSON dict | extension | app index → {minutes, firedAt} |
| `nudge_records_new` | JSON dict | extension | (post-migration, drop `nudge_records`) |
| `active_app_bundle_id` | string | extension | current foreground app (temp) |
| `active_session_start` | date | extension | session start (temp) |
| `daily_guess_seconds` | int | main app | user's initial guess (onboarding) |
| `reality_check_shown` | bool | main app | one-time card flag |
| `first_launch_at` | date | main app | trial clock anchor |
| `lifetime_unlocked` | bool | main app | purchase state cache (+ StoreKit) |
| `last_receipt_auto_show` | string (yyyy-MM-dd) | main app | last auto-shown receipt date |

### Live Activity lifecycle

```
App foreground
    ↓
WastedApp.refreshLiveActivity()
    ↓
if Activity exists: update ContentState (new total, new accumulatedStart)
if Activity doesn't exist: request new Activity
    ↓
LiveActivityManager computes:
    accumulatedStart = Date() - totalSeconds
    lastUpdatedTotalSeconds = confirmed total
    isLive = (totalSeconds > 0)
    capSeconds = current threshold band gap
    ↓
Activity updates or is created
    ↓
TimeTrackerLiveActivityView renders from ContentState
    ↓
Timer ticks up from accumulatedStart until capSeconds overshoot
    ↓
(Extension cannot update from background—Activity goes stale after ~8 hours)
```

### Extension threshold architecture

The extension registers a threshold for every combination of (app, minute threshold). Thresholds taper as the day progresses:

```swift
1m–5m: every minute (reaction speed)
10m–120m: every 5 minutes (early fidelity)
130m–240m: every 10 minutes (mid-day)
255m–480m: every 15 minutes (tail, fewer wakes)
```

This yields ~52 events per app instead of 480 per app, reducing background task overhead while keeping early-day reaction time <1 minute.

When a threshold fires:

1. `eventDidReachThreshold(name: "index:minutes")` → parse index + minutes
2. Record the delta (new total − last recorded total) to `daily_usage[index]`
3. Evaluate nudge gate: `NudgeGate.shouldNudge(minutes, last, today, now)`
4. If eligible: `NotificationScheduler.scheduleNudge(appName, minutes)`
5. Always: `ReceiptScheduler.refresh(usage, displayNames)` (re-schedules 21:00 receipt)
6. Always: `LiveActivityManager.startOrUpdate(total, isLive: true)` (push Live Activity)
7. Always: `WidgetCenter.reloadAllTimelines()` (widget refresh)

---

## Key algorithms

### Nudge gate

```swift
enum NudgeGate {
    static let stepMinutes = 30      // 30, 60, 90, 120, ...
    static let minGap: TimeInterval = 600  // 10 minutes
    
    static func shouldNudge(
        minutes: Int,
        last: NudgeRecord?,
        today: String,
        now: Date
    ) -> Bool {
        // true if:
        // - minutes is a 30-minute multiple (30, 60, 90, ...)
        // - no nudge fired yet today, OR last nudge was for fewer minutes
        // - at least 10 minutes of wall-clock time since the last nudge
        guard minutes % stepMinutes == 0 else { return false }
        guard let lastNudge = last else { return true }
        guard lastNudge.date == today else { return true }
        guard minutes > lastNudge.minutes else { return false }
        return now.timeIntervalSince(lastNudge.firedAt) >= minGap
    }
}
```

This ensures nudges fire exactly at 30, 60, 90, ... minute marks, at most once per 30-minute step, and with a 10-minute gap between firing (prevents spam if thresholds are dense).

### Live Activity anchor (optimistic ticking)

```swift
// In LiveActivityManager, ContentState initialization:
let accumulatedStart = Date() - TimeInterval(totalSeconds)

// In TimeTrackerLiveActivityView (extension), render:
Text(timerInterval: accumulatedStart..., paused: !isLive)
    .font(.system(size: 68, weight: .bold, design: .serif))
```

By setting `accumulatedStart = now - totalSeconds`, the timer ticks up from zero to the current total *and then continues ticking* from the last confirmed total until it overshoots by `capSeconds`. This creates the illusion of a live, continuously ticking counter without needing frequent background updates.

### Trial clock

```swift
enum TrialState: Equatable {
    case trial(daysLeft: Int)
    case expired
    case unlocked
}

static func state(firstLaunch: Date?, unlocked: Bool) -> TrialState {
    if unlocked { return .unlocked }
    guard let first = firstLaunch else { return .trial(daysLeft: 7) }
    let days = Calendar.current.dateComponents([.day], from: first, to: Date()).day ?? 0
    let left = max(0, 7 - days)
    return left > 0 ? .trial(daysLeft: left) : .expired
}
```

The trial is 7 days from first launch. On day 7.0+, the user sees the paywall. Once purchased, `lifetimeUnlockedKey` is set in App Group defaults and cached from StoreKit.

### Historical peak insight

```swift
struct HistoricalPeak: Equatable {
    let startHour: Int  // 0–22 (e.g., 21 = 9 PM)
    let endHour: Int    // startHour + 2
    let daysActive: Int // days in history with usage in this window
    let daysTotal: Int  // total history days
}

static func historicalPeak(history: [DailyUsage]) -> HistoricalPeak? {
    guard history.count >= 3 else { return nil }
    
    // Sum hourly usage across all history days
    var hourlyTotal = [Int: Int]()  // hour → seconds
    for day in history {
        for (hour, usage) in day.hourly.enumerated() {
            hourlyTotal[hour, default: 0] += usage
        }
    }
    
    // Find the 2-hour window with the largest sum
    var peak = (window: 0...1, sum: 0)
    for hour in 0...22 {
        let sum = (hourlyTotal[hour] ?? 0) + (hourlyTotal[hour + 1] ?? 0)
        if sum > peak.sum {
            peak = (hour...(hour+1), sum)
        }
    }
    
    // Count days with usage in the peak window
    let daysActive = history.filter { day in
        peak.window.contains(where: { hour in (day.hourly[hour] ?? 0) > 0 })
    }.count
    
    return HistoricalPeak(
        startHour: peak.window.lowerBound,
        endHour: peak.window.upperBound,
        daysActive: daysActive,
        daysTotal: history.count
    )
}
```

This runs on the home screen (not the extension) and powers the "you lose the most time between 9pm–11pm" insight.

### Reality check

```swift
struct RealityCheck: Equatable {
    let guessLine: String    // "you guessed 2h."
    let realityLine: String  // "reality: 4h 12m."
    let deltaLine: String    // "off by 110%." or "you actually knew."
    
    static func make(
        guessSeconds: Int,
        firstFullDaySeconds: Int
    ) -> RealityCheck? {
        guard guessSeconds > 0, firstFullDaySeconds > 0 else { return nil }
        
        let guessLine = "you guessed \(AppGroupKeys.formattedDuration(guessSeconds))."
        let realityLine = "reality: \(AppGroupKeys.formattedDuration(firstFullDaySeconds))."
        
        let deltaPercent = (firstFullDaySeconds - guessSeconds) * 100 / guessSeconds
        let deltaLine: String
        if deltaPercent <= 0 {
            deltaLine = "you actually knew."
        } else {
            deltaLine = "off by \(abs(deltaPercent))%."
        }
        
        return RealityCheck(guessLine, realityLine, deltaLine)
    }
}
```

This shows the user the delta between their initial guess (onboarding) and the first full day's actual usage. It appears as a card above the quote, serif voice, and once dismissed it never shows again.

---

## Extension communication patterns

The extension and main app never communicate directly—no XPC, no background tasks. They share state via App Group UserDefaults only.

**From extension to main app:**
- Write new `daily_usage` → main app polls every 5 seconds
- Trigger widget refresh via `WidgetCenter.reloadAllTimelines()`
- Fire local notification (user opens app, sees new data)

**From main app to extension:**
- Write `tracked_selection` (FamilyActivitySelection) → extension reads and configures monitoring
- Write `display_names` → extension reads for notification rendering
- Delete `daily_usage` at midnight (main app only, via a date-change observer)

**Live Activity updates:**
- Only the main app can call `Activity.request()` (system constraint)
- Main app updates the activity on every foreground + periodic background refresh
- Extension cannot update the activity—Activity goes stale and the timer freezes

---

## Error handling & resilience

### Missing or corrupted data

- If `daily_usage` is missing, assume 0 seconds for all apps.
- If `display_names` is missing, show "App 0", "App 1", etc.
- If `tracked_selection` is missing or undecodable, monitoring stops until the user re-picks apps.
- If `usage_history` is corrupted, load what exists and skip corrupted days.

### Extension crashes

The extension is isolated and its crash does not crash the main app. If the extension fails:
- Thresholds stop firing → live activity goes stale after ~8 hours
- Nudges stop → but the user can still see usage on the home screen
- Widget stops updating → but data is fresh on app foreground

This is acceptable—the app degrades gracefully.

### Stale Live Activity

The Live Activity is designed to tolerate staleness:
- If no thresholds fire, the timer ticks up to `lastUpdatedTotalSeconds + capSeconds`, then freezes.
- When the app foregrounds, the activity is immediately re-anchored and ticks resume.
- If 8+ hours pass without any update, iOS ends the activity. The next foreground re-creates it.

### Trial expiry

If the trial expires mid-session:
- Home screen blurs the number and shows the paywall.
- Extension stops pushing Live Activity updates.
- Widget shows `??m unlock to see`.
- Receipt auto-show (Task 1.2) is suppressed.

All features resume immediately on purchase (StoreKit calls `refreshEntitlement()` and caches the result).

---

## Testing strategy

### Unit tests (WastedTests target)

Every pure function gets XCTest coverage:

- `UsageStoreTests` – read/write to injected `UserDefaults(suiteName:)`
- `DailyUsageTests` – data model serialization
- `InsightEngineTests` – peak-hour calculation, danger-zone detection
- `RealityCheckTests` – guess vs. actual delta formatting
- `TrialClockTests` – trial state machine transitions
- `NudgeGateTests` – threshold evaluation, 30-min step logic
- `QuoteBankTests` – daily quote rotation
- `TimeTrackerAttributesTests` – ActivityKit state round-trip
- `AppGroupKeysTests` – time formatting, key generation

### Manual testing (device)

Critical flows are tested on device (simulator cannot test Family Controls or Live Activity):

- Onboarding end-to-end (all prompts, picker, permissions)
- Tracking loop (open app A, scroll 5m, threshold fires, island appears, number updates)
- 30-minute nudges (confirm notifications fire at exactly 30, 60, 90 minute marks)
- Receipt notification at 21:00 (set device time, verify notification)
- Live Activity staleness (wait 45+ minutes without app foreground, island dims, then re-anchors on foreground)
- Trial→expired transition (back-date first_launch_at, paywall appears)
- Purchase flow (StoreKit config, purchase, entitlements cache, unfrost)

### CI/CD

```bash
xcodebuild -scheme Wasted -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Runs 61+ XCTest tests. All must pass before any PR merge.

---

## Performance notes

### Extension wakes

Each threshold fires a background task. With ~52 events/app, the extension wakes ~52× per hour of heavy use. This is acceptable—Family Controls is designed for this granularity.

### Live Activity updates

Live Activity updates (from the main app) are expensive. They're done on every foreground + a periodic background refresh every 30 minutes. Do not update more frequently—iOS will throttle.

### Home screen polling

HomeView polls `UsageStore` every 5 seconds via a Timer. This keeps the display within ~5 seconds of the true total. If latency is an issue, the interval can be increased to 10–15 seconds without perceptible staleness.

### Widget refresh

The widget refreshes on every extension threshold fire + once per hour (policy backstop). Do not request more frequent updates—the OS will ignore them.

---

## File structure

```
Wasted/
├── WastedApp.swift                      # app lifecycle, bg refresh
├── Theme.swift                          # color + haptics system
├── Home/
│   ├── HomeView.swift                   # home screen
│   ├── HeatmapView.swift                # 7-day hourly chart
│   ├── WeeklyCard.swift                 # 7-day totals
│   ├── DangerZonesCard.swift            # imbalance detection
│   ├── TrackedAppLabel.swift            # per-app summary
│   └── DailyReceiptCard.swift           # tap to open receipt
├── Onboarding/
│   ├── OnboardingContainerView.swift     # sequencer
│   ├── HookView.swift                   # intro
│   ├── DifferentiationView.swift        # "not a blocker"
│   ├── GuessView.swift                  # initial time guess
│   ├── PermissionView.swift             # FamilyControls auth
│   ├── AppPickerView.swift              # app selection
│   ├── NotificationPermissionView.swift # notification auth
│   └── DoneView.swift                   # congratulations
├── Receipt/
│   └── ReceiptView.swift                # daily summary sheet
├── Shared/
│   ├── Models/
│   │   ├── DailyUsage.swift
│   │   ├── HourlyUsage.swift
│   │   └── AppGroupKeys.swift
│   ├── LiveActivity/
│   │   ├── TimeTrackerAttributes.swift
│   │   └── TimeTrackerLiveActivityView.swift (extension target)
│   ├── Storage/
│   │   └── UsageStore.swift
│   ├── LiveActivityManager.swift
│   ├── ReceiptScheduler.swift
│   ├── Nudges.swift
│   ├── DailyReceipt.swift
│   └── TrialClock.swift
├── Insights/
│   ├── InsightEngine.swift
│   ├── RealityCheck.swift
│   └── HistoricalPeak.swift
├── Monitoring/
│   └── ActivityScheduler.swift
├── Data/
│   └── QuoteBank.swift
└── Monetization/
    ├── LifetimeStore.swift
    └── PaywallView.swift

DeviceActivityMonitorExt/
├── DeviceActivityMonitorExtension.swift # entry point, threshold handler
├── NotificationScheduler.swift          # nudge notifications
└── ReceiptScheduler.swift               # (linked from Shared/)

LiveActivityExt/
├── LiveActivityExtBundle.swift
└── TimeTrackerLiveActivityView.swift    # island rendering

WastedWidget/
├── WastedWidgetBundle.swift
└── WastedWidget.swift
```

---

## Provisioning & code signing

The project uses free personal team provisioning (`ZZZ87SSQ8S`). Family Controls requires a developer account, but provisioning can be automated:

```bash
xcodebuild -scheme Wasted -destination 'id={device-id}' -allowProvisioningUpdates build
```

The DeviceActivityMonitorExt target has `CODE_SIGNING_REQUIRED = NO` to allow free-team development profiles (needed due to Apple's delay in issuing Family Controls dev profiles to free accounts).

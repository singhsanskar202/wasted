# Mirror Polish — Design Spec
**Date:** 2026-07-06
**Status:** Approved

Wasted is a mirror, not a blocker. This pass makes the number harder to ignore: a sharper onboarding, haptics that make it feel deliberate, nudges every 30 minutes instead of every hour, an end-of-day receipt, and one new insight — the hour of the day you consistently lose.

No monetization in this pass. Fully free/unlocked.

---

## Audit of existing code (vs. sections 2–7 of the brief)

### §2 Design language
| Item | Status |
|---|---|
| Canvas | ❌ pure `Color.black` everywhere → change to `#0A0A0A` |
| Primary text | ❌ pure `.white` → warm off-white `#F5F3EE` |
| Accent discipline | ❌ orange used decoratively on HomeView (equivalent line, heatmap peak); reds defined ad-hoc in DangerZonesCard + WeeklyCard → one `Color.alarm`, red only when the number is bad |
| Serif = mirror voice | Partial. HookView stats and daily quote are serif ✅; HomeView big number is `.rounded` sans ❌ |
| Motion | ✅ spring on daily total, fade transitions. ❌ reduced motion not respected anywhere |
| Haptics | ❌ none exist |

### §4 Onboarding
Current order: Hook → ScreenTime → Notifications → AppPicker → Done.
- ❌ No differentiation screen.
- ❌ Order. Target: Hook → Differentiation → **ScreenTime → AppPicker** → Notifications → Done. The brief puts the picker before the Screen Time prompt, but `familyActivityPicker` cannot list apps until FamilyControls authorization is granted — platform constraint, so permission sits directly before the picker.
- ✅ PermissionView already explains why in one breath ("your data. your device. nobody else sees it.").
- ❌ NotificationPermissionView says "twice a day. nothing else." — wrong once 30-min nudges ship; rant is longer than the one-sentence-why rule.

### §5 Dynamic Island
✅ Compliant, no changes:
- `accumulatedStart = Date() - totalSeconds` resumes the count from the day's total.
- `intervalDidEnd` archives the day; `intervalDidStart` starts fresh.
- All four surfaces (compact, minimal, expanded, lock screen) read `AppGroupKeys.formattedTime`.

### §6 Notifications
- ❌ Nudges fire only at hourly marks (`minutes % 60 == 0`), copy bank lives inline in `NotificationScheduler`, some lines are guilt-flavored ("Your future self is watching. Disappointed." style).
- ❌ No daily receipt of any kind.

### §7 Home screen
- ✅ InsightEngine / DangerZonesCard / HeatmapView / WeeklyCard cover today + 7-day trend.
- ❌ No cross-day peak-hour insight. ❌ No receipt view.

### Dead code found
`ContentView.swift` (Xcode template), `AppGridView.swift` (superseded by AppPickerView), `AppGroupKeys.hourlyUsageKey`/`hourlyUsageKeyPrefix` (storage refactored 2026-06-30). All unreferenced — delete.

---

## 1. Theme

`Wasted/Theme.swift` (main app target only):

```swift
extension Color {
    static let canvas   = Color(red: 0.039, green: 0.039, blue: 0.039)  // #0A0A0A
    static let ink      = Color(red: 0.961, green: 0.953, blue: 0.933)  // #F5F3EE
    static let inkFaint = ink.opacity(0.5)
    static let alarm    = Color(red: 1.0, green: 0.23, blue: 0.19)      // bad numbers only
}
```

Applied to HomeView, all onboarding screens, ReceiptView. DangerZonesCard/WeeklyCard swap their private `red` for `.alarm`; internal grays stay. Heatmap peak bar: `.alarm` only when the peak hour is ≥1h (a genuinely bad number), otherwise ink. The equivalent line loses its orange and its emoji — it's the mirror voice, so serif, faint ink.

`Haptics` enum in the same file — thin wrappers over `UIImpactFeedbackGenerator` / `UISelectionFeedbackGenerator` / `UINotificationFeedbackGenerator`. Wired exactly per the brief's table, nowhere else.

Reduced motion: every view with an entrance animation (`HookView`, `DifferentiationView`, `NotificationPermissionView`, `DoneView`, `HomeView`) checks `@Environment(\.accessibilityReduceMotion)` and shows content immediately when set.

---

## 2. Onboarding

New order in `OnboardingContainerView` (fades kept):
1. HookView — unchanged
2. **DifferentiationView (new)** — same layout grammar as PermissionView:
   - headline: `this won't\nblock anything.`
   - body: `blockers get deleted.\nstreaks get abandoned.\nwasted just keeps count —\na number you can't unsee.`
   - button: `understood` (light haptic)
3. PermissionView — copy unchanged; success haptic + advance on grant, warning haptic on deny; after a denial the subtitle switches to `wasted can't see anything without this.` and the button stays
4. AppPickerView — selection haptic on picker change, medium haptic on "i'm ready"
5. NotificationPermissionView — keep blocks 1–2 of the rant, replace the rest with the one-sentence why: `a nudge every 30 minutes\nyou keep scrolling.\none receipt at night.\nnothing else.` Success/warning haptic on grant/deny, then advance either way
6. DoneView — heavy haptic on entrance (the only `.heavy` in the app)

---

## 3. 30-minute nudges

`Wasted/Shared/Nudges.swift` (Wasted + DeviceActivityMonitorExt targets):

```swift
struct NudgeRecord: Codable, Equatable {
    let date: String      // yyyy-MM-dd
    let minutes: Int      // threshold minutes already nudged
    let firedAt: Date
}

enum NudgeGate {
    static let stepMinutes = 30
    static let minGap: TimeInterval = 600
    // true when minutes is a 30-multiple, greater than the last nudged
    // threshold today, and ≥10 min of wall clock since the last nudge
    static func shouldNudge(minutes: Int, last: NudgeRecord?, today: String, now: Date) -> Bool
}

enum NudgeCopy {
    static func title(appName: String, minutes: Int) -> String  // "30m on Instagram"
    static let bodies: [String]                                  // flat facts + redirects
    static func body(at index: Int) -> String                    // index wraps
}
```

Bodies (lowercase, no exclamation points, no guilt):
- `that's enough for now — back to it?`
- `just so you know.`
- `the count doesn't pause. you can.`
- `still worth it?`
- `you opened it for a reason. was this it?`
- `the number only goes up from here.`

`UsageStore` gains `lastNudge(for:)` / `recordNudge(minutes:for:)` — a `[appIndex: NudgeRecord]` dict under App Group key `nudge_records`; stale-day records are ignored by the gate.

`DeviceActivityMonitorExtension.eventDidReachThreshold` replaces the `minutes % 60` branch with the gate; `NotificationScheduler.scheduleNudge(appName:minutes:)` renders NudgeCopy with a random variant.

---

## 4. Daily receipt

Constants in `AppGroupKeys`: `awakeDayHours = 16`, `receiptHour = 21`. `formattedTime` refactors onto a new `formattedDuration(_ seconds: Int) -> String`.

`Wasted/Shared/DailyReceipt.swift` (both targets):

```swift
struct DailyReceipt: Equatable {
    struct Item: Equatable { let name: String; let seconds: Int }
    let dateString: String
    let items: [Item]              // sorted desc by seconds, names resolved via displayNames
    let totalSeconds: Int
    let percentOfAwakeDay: Int     // round(total / (16 * 3600) * 100)
    var summaryLine: String        // "3h 12m today — 20% of your waking hours."
    static func build(usage: DailyUsage, displayNames: [String: String]) -> DailyReceipt
}
```

**Notification:** `ReceiptScheduler` (extension target). Every threshold event re-schedules a single local notification (identifier `wasted.receipt`, calendar trigger today 21:00, non-repeating) whose body is the receipt summary as of that moment. Re-adding with the same identifier replaces the pending one, so at 9 PM the latest numbers fire. After 21:00, or with zero usage, nothing is scheduled — the in-app receipt still works.

**In-app:** `ReceiptView` sheet, opened from a `today's receipt` row on HomeView (light haptic). Receipt-printer layout on canvas: sans header (WASTED + date), dashed rules, sans item rows (name left, time right), serif total, serif percentage line. Zero-usage state: one serif line, `nothing yet.`

---

## 5. Peak-hour history insight

`InsightEngine`:

```swift
struct HistoricalPeak: Equatable {
    let startHour: Int   // best contiguous 2-hour window
    let endHour: Int     // startHour + 2
    let daysActive: Int  // days in history with usage inside the window
    let daysTotal: Int
}
static func historicalPeak(history: [DailyUsage]) -> HistoricalPeak?
// nil when history < 3 days or no usage at all
```

Sum `hourly` across all history days, pick the 2-hour window with the largest sum. Displayed on HomeView below the weekly section once ≥3 days of history exist, in the mirror voice (serif):

> you lose the most time between 9pm–11pm.
> 5 of the last 7 days.

("most days" phrasing comes free from the day count — no extra copy logic.)

---

## Files changed

| File | Change |
|---|---|
| `Wasted/Theme.swift` | new — palette + Haptics |
| `Wasted/Onboarding/DifferentiationView.swift` | new |
| `Wasted/Onboarding/OnboardingContainerView.swift` | re-sequence |
| `Wasted/Onboarding/{Hook,Permission,AppPicker,NotificationPermission,Done}View.swift` | haptics, palette, reduced motion, copy fix |
| `Wasted/Shared/Nudges.swift` | new — gate + copy (both targets) |
| `Wasted/Shared/DailyReceipt.swift` | new — receipt builder (both targets) |
| `Wasted/Shared/Models/AppGroupKeys.swift` | constants, `formattedDuration`, `nudgeRecordsKey`, drop dead helpers |
| `Wasted/Shared/Storage/UsageStore.swift` | nudge-record storage |
| `Wasted/Receipt/ReceiptView.swift` | new |
| `Wasted/Home/HomeView.swift` | serif number, palette, receipt row, peak insight |
| `Wasted/Home/{Heatmap,DangerZones,Weekly}*.swift` | palette alignment |
| `Wasted/Insights/InsightEngine.swift` | `historicalPeak` |
| `DeviceActivityMonitorExt/DeviceActivityMonitorExtension.swift` | 30-min gate, receipt refresh |
| `DeviceActivityMonitorExt/NotificationScheduler.swift` | rewrite on NudgeCopy |
| `DeviceActivityMonitorExt/ReceiptScheduler.swift` | new |
| `Wasted.xcodeproj/project.pbxproj` | ext membershipExceptions for the two new shared files |
| `Wasted/ContentView.swift`, `Wasted/Onboarding/AppGridView.swift` | delete (dead) |

## Out of scope
- StoreKit / paywalls (deferred; the tracked-app count is already unbounded — a future paywall can gate `FamilyActivitySelection` size in `ActivityScheduler.startMonitoring`, noted there)
- Widgets, push-based Live Activity updates (paid account)
- Any change to Live Activity behavior (§5 audit: compliant)

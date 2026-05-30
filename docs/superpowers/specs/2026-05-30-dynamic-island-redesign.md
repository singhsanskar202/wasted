# Dynamic Island Redesign — Design Spec
**Date:** 2026-05-30
**Status:** Approved

---

## Overview

Redesign the Live Activity / Dynamic Island presentation in Wasted. Current state has a white placeholder rectangle instead of an app icon, uses SwiftUI's `.timer` style (shows `0:00` counting up, always red), and has no nudge copy on the lock screen banner. This spec replaces all three.

---

## Changes Summary

| Area | Before | After |
|---|---|---|
| Compact leading | White placeholder rect | Real app icon (PNG from App Group) |
| Compact trailing | `.timer` style, always red | `Xh Ym` format, grey <1h, red ≥1h |
| Minimal | White placeholder rect | App icon only |
| Lock screen | App name + timer | App name + time + nudge line |
| Onboarding | No icon saving | Save app icon PNG to App Group on pick |

---

## Compact Pill

Always visible while the user is in a tracked app.

- **Left (compact leading):** App icon, 22×22pt, rounded rect (cornerRadius 5). Read from App Group key `app_icon_<appName>` (e.g. `app_icon_Instagram`) as PNG data → `UIImage` → SwiftUI `Image`. If missing, fall back to a letter circle (first letter of app name, grey background).
- **Right (compact trailing):** Time in `Xh Ym` format.
  - Under 1 hour: show `Xm` only (e.g. "42m"), color `white.opacity(0.75)`.
  - 1 hour or more: show `Xh Ym` (e.g. "1h 24m"), color `.red`.
  - Computed from `accumulatedStart` offset: `Int(Date().timeIntervalSince(accumulatedStart))`.
  - Updates on Live Activity push — same cadence as today (extension-driven). No live ticking in compact; the number jumps on each update.

---

## Minimal Pill

Shown when the Dynamic Island is shared with another Live Activity.

- App icon only, 16×16pt, rounded rect. Same fallback logic as compact.

---

## Expanded View (long press)

- **Leading:** App icon (28×28pt) + app name, `font(.system(size: 14, weight: .semibold))`.
- **Trailing:** Time in same `Xh Ym` format, large (`font(.system(size: 20, weight: .bold))`), red if ≥1h.
- **Bottom:** "today" label in grey — no change from current.

---

## Lock Screen Banner

Shown on the lock screen while a Live Activity is active.

Layout (HStack):
1. App icon, 32×32pt, rounded rect
2. App name, `.headline`
3. Spacer
4. VStack:
   - Time (`Xh Ym` format, red if ≥1h)
   - Nudge line: `"[X]h [Y]m you won't get back."` — same time value, `.caption`, `white.opacity(0.5)`

Example: `"1h 24m you won't get back."`

Under 1 hour, nudge line reads `"[X]m you won't get back."` — same format, no special casing.

---

## Time Formatting

Extract a shared helper used by all four surfaces:

```swift
func formattedTime(from accumulatedStart: Date) -> (text: String, isOver1Hour: Bool) {
    let seconds = Int(Date().timeIntervalSince(accumulatedStart))
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    if h > 0 { return ("\(h)h \(m)m", true) }
    return ("\(m)m", false)
}
```

`isOver1Hour` drives the red/grey color switch.

---

## App Icon Storage (Onboarding Change)

**Where:** `AppPickerView.swift` — after the user confirms their selection.

**How:**
1. Iterate `selection.applicationTokens`.
2. For each token, create a SwiftUI `Label` using `Label(token)` (FamilyControls provides this).
3. Render to PNG via `ImageRenderer` at 2× scale.
4. Save to App Group keyed by display name: `defaults.set(pngData, forKey: "app_icon_\(displayName)")`.

`ApplicationToken.bundleIdentifier` is private — bundle IDs are unavailable. Icons are keyed by display name (`appName`) which is already carried in `context.attributes` in the extension, so no model change is needed.

**Add to `AppGroupKeys`:**
```swift
static func appIconKey(for appName: String) -> String { "app_icon_\(appName)" }
```

---

## Files Changed

| File | Change |
|---|---|
| `LiveActivityExt/TimeTrackerLiveActivityView.swift` | Full rewrite — new compact, minimal, expanded, lock screen views |
| `Wasted/Onboarding/AppPickerView.swift` | Save icon PNGs to App Group on selection confirm |
| `Wasted/Shared/Models/AppGroupKeys.swift` | Add `appIconKey(for:)` helper |
| `Wasted/Shared/LiveActivity/TimeTrackerAttributes.swift` | No change needed |
| `DeviceActivityMonitorExt/LiveActivityManager.swift` | No change needed |

---

## Out of Scope

- Lock screen widgets (accessoryCircular / accessoryRectangular) — needs paid developer account
- Notification rich content redesign
- Any change to the hourly nudge notification copy

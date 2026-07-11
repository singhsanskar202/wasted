# Wasted Design Guide

## Overview

Wasted is a screen time mirror, not a blocker. The design reflects this: the app itself is nearly invisible, and the number is impossible to ignore. The visual system exists to serve that single purpose: make the user confront how much time they've lost.

**Core principle:** voice is serif (the mirror speaking, lowercase, faintly italic). interface is sans (efficient, without flourish). Red appears only when a number is bad. Motion springs on entrance; exits fade away.

---

## Color System

All colors are defined in `Wasted/Theme.swift` and applied consistently across the main app, onboarding, and receipt view.

### Palette

```swift
Color.canvas    = #0A0A0A (RGB: 0.039, 0.039, 0.039)
Color.ink       = #F5F3EE (RGB: 0.961, 0.953, 0.933)
Color.inkFaint  = ink.opacity(0.5)
Color.alarm     = #FF3A30 (RGB: 1.0, 0.23, 0.19) // red only when the number is bad
```

### Usage rules

- **Canvas** is the universal background—every screen, every sheet, every corner.
- **Ink** is primary text. Use at full opacity for headings and important numbers. Use `Color.ink.opacity(0.5)` for microcopy, labels, and structural text. Never use pure gray—always layer through `inkFaint` for consistency.
- **Alarm** appears only when a number is genuinely bad: a heatmap peak ≥1h, a weekly card showing heavy usage, or the blurred paywall state. No decorative red, no accent pops. When a number is on-brand but not alarming, it stays `ink`.
- **No semantic colors.** There are no greens, no yellows, no success/warning states beyond the numbers themselves. The app trusts the numbers to speak.

### Theme implementation

Light and dark themes are irrelevant—the app commits to dark mode as the design world the app lives in. Color.canvas is black-adjacent; Color.ink is warm off-white. This is not a theme toggle; it's the design.

---

## Typography

### Typeface selection

- **Display/heading:** System font, serif design (`.serif`). Used for the daily total ("3h 12m"), receipts, insight lines, and the mirror's voice (equivalent, peak-hour). Weight: `.bold` or `.light` depending on voice—serif bold for the number is confrontational; serif light italic for the mirror is reflective.
- **Body/interface:** System font, sans design (`.rounded` on smaller screens, default sans on watchOS, `.default` everywhere else). Used for buttons, labels, settings rows, onboarding copy. Weight: `.regular` or `.light` for microcopy.
- **Monospace:** Only in debug contexts or the Live Activity timer—never in user-facing copy.

### Type scale

All sizes are derived from the system font metrics. Respect `accessibilityFont` where users have set a text-size preference.

| Use | Size | Weight | Design | Color |
|---|---|---|---|---|
| Daily total | 68pt | bold | serif | ink |
| Receipt total | 32pt | bold | serif | ink |
| Section heading | 14pt | light | sans | ink |
| Body copy | 16pt | regular | sans | ink |
| Microcopy | 12pt | light | sans | inkFaint |
| Button | 16pt | regular | sans | canvas text on ink bg |
| Equivalent line | 16pt | regular | serif italic | inkFaint |

### Typographic restraint

- No exclamation points anywhere in the app.
- Lowercase for headings and microcopy unless proper nouns.
- Serif = the mirror's voice, always reflective and faintly italic.
- Sans = efficient interface, never decorative.
- Letter-spacing on labels: `.tracking(2)` for structural labels ("you wasted", "on your phone today").

---

## Components & Patterns

### Buttons

All buttons follow a single pattern:

```swift
Button(action: {}) {
    Text("button label")
        .font(.system(size: 16, weight: .regular))
        .foregroundStyle(Color.canvas)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.ink)
        .cornerRadius(8)
}
```

- Background is always `Color.ink` (off-white).
- Text is always `Color.canvas` (black) for maximum contrast.
- No bordered variants, no subtle states—buttons are binary (tappable or disabled).
- Haptics: light on press, success on completion, warning on denial.

### Text input fields

Not used in the main app, but the guess screen in onboarding uses chip-based single select:

```swift
// Selection chips — not text input
HStack(spacing: 8) {
    ForEach(options, id: \.self) { option in
        Text(option)
            .font(.system(size: 14, weight: .regular))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(selection == option ? Color.ink : Color.canvas.opacity(0.1))
            .foregroundStyle(selection == option ? Color.canvas : Color.ink)
            .cornerRadius(4)
    }
}
```

### Cards & containers

The receipt and insight cards follow the receipt-printer aesthetic (dashed rules, serif totals, sans item labels):

```swift
VStack(spacing: 12) {
    Divider().overlay(dashLine())  // dashed rule
    HStack {
        Text("instagram")
            .font(.system(size: 14, weight: .regular))
        Spacer()
        Text("2h 14m")
            .font(.system(size: 14, weight: .regular, design: .serif))
    }
    Divider().overlay(dashLine())
    HStack {
        Text("total").font(.system(size: 16, weight: .bold, design: .serif))
        Spacer()
        Text("4h 32m").font(.system(size: 16, weight: .bold, design: .serif))
    }
}
.padding(16)
.background(Color.canvas)
```

### Heatmap & weekly chart

Charts use the on-canvas palette: ink bars for neutral usage, alarm-red bars for peaks ≥1h. Grids are faint (`inkFaint`). No gradient fills, no decorative drop shadows.

### Live Activity / Dynamic Island

The island renders in real-time, ticking up as the user scrolls. It shows:
- App icon (letter tile fallback, on-palette)
- Time in `Xh Ym` format
- Lock screen nudge: app name, time, and the nudge body

The ticking timer uses `accumulatedStart = Date() - totalSeconds` so it resumes from the day's total, not resets on every update.

---

## Motion & Interaction

### Entrance animations

Every screen with an entrance animation checks `@Environment(\.accessibilityReduceMotion)`. When reduced motion is enabled, content appears immediately.

- **HomeView big number:** Spring animation, 0.6s duration, 0.3 bounce, 0.1s delay. Pair with a 0.85× scale opacity on load.
- **Onboarding screens (Hook, Differentiation, Notifications, Done):** Fade-in with a slight upward translate. Spring for Done (heavy haptic on entrance—the app's one .heavy haptic).
- **Quote & receipt:** Fade-in only, no translate.

### Interactions

- **Threshold crossing:** When usage crosses a 30-minute threshold, a nudge notification fires. The Live Activity updates silently—no animation, just the number ticks.
- **Receipt open:** Light haptic, sheet animates in from bottom.
- **Paywall open:** Light haptic, sheet animates in from bottom.
- **Reality check dismiss:** Light haptic, card fades out.

### Haptics table (per spec, these are the only haptics allowed)

| Context | Haptic | Type |
|---|---|---|
| onboarding advance (except Done) | light | `UIImpactFeedbackGenerator(style: .light)` |
| selection haptic (picker, chips) | selection | `UISelectionFeedbackGenerator` |
| permission denied | warning | `UINotificationFeedbackGenerator(type: .warning)` |
| purchase success | success | `UINotificationFeedbackGenerator(type: .success)` |
| Done screen entrance | heavy | `UIImpactFeedbackGenerator(style: .heavy)` |

---

## Onboarding flow

The onboarding sequence is:

1. **Hook** – serif quote about lost time, sans button "ready to look?"
2. **Differentiation** – serif body explaining the app is a mirror, not a blocker
3. **Permission** – FamilyControls authorization ("your data. your device. nobody else sees it.")
4. **App Picker** – `familyActivityPicker`, select which apps to track
5. **Notifications** – request notification permission, explain the 30-min nudge cadence
6. **Done** – serif affirmation, button to proceed to home

Each screen fades in and out. The Done screen has a heavy haptic on entrance—the app's strongest tactile moment, signaling onboarding is over.

---

## Home screen layout

The home screen is a single scroll view with this structure:

1. **Quote** – serif, italic, faintly transparent. Rotates daily via `QuoteBank.todaysQuote`.
2. **Reality check** (conditional) – full-width card, appears once after day 1 of tracking if the user guessed a starting time. Shows guess vs. actual usage. Serif for all three lines, `Haptics.medium()` on first appearance.
3. **Big number** – "you wasted {duration} on your phone today". Sans label, serif bold total, spring animation on load.
4. **Equivalent** – serif italic, faintly transparent. "that's {equivalent task}" (e.g., "that's a movie").
5. **Today's receipt** – tap to open the receipt sheet. Light haptic.
6. **Heatmap** – 7-day grid showing hourly breakdowns. Axes are faintly labeled; peak hours are red if ≥1h.
7. **Weekly card** – shows days 1–7 with the heaviest app for each. Red bars for days ≥2h.
8. **Danger zones** – days with severe imbalance (afternoon/evening heavy). Red accent.
9. **Peak-hour insight** (conditional) – appears once ≥3 days of history exist. Serif: "you lose the most time between 9pm–11pm. 5 of the last 7 days."
10. **Settings row** – "tracking N apps", long-press to show paywall (debug only, removed in shipping).

---

## Receipt view

The receipt is a sheet that opens from the home screen. It renders the day's summary in a receipt-printer aesthetic:

- Header: sans, "wasted" + date
- Item rows: app name on left (sans), time on right (serif)
- Dashed rules between items
- Total row: serif bold
- Percentage line: serif, "that's X% of your waking hours"
- Zero-usage state: serif, "nothing yet."

Colors: canvas background, ink text, no accents except when computing percentage (no color change—the percentage itself is the value, not a semantic state).

---

## Paywall

The paywall is a sheet that presents when the trial expires. It uses the mirror voice:

- Headline (serif): "keep the mirror."
- Body (sans, faint): "no subscription. no streak to protect. pay once. it's yours — until you don't need it anymore."
- Primary button: "unlock forever — {price}"
- Footer: "restore purchases" (light haptic on tap)

The paywall does not show on expired state until explicitly opened—it's not forced on the user, just available.

---

## Dynamic Island (Live Activity)

The Live Activity renders four surfaces:

1. **Compact leading** – app icon + time
2. **Minimal** – time only
3. **Expanded** – icon, app name, time, and the nudge body (if a nudge is active)
4. **Lock screen** – app name, time, and the nudge body

All surfaces read `AppGroupKeys.formattedTime(from: accumulatedStart)` so the timer ticks live from a stored anchor point. The rendering happens in the extension (`LiveActivityExt` target) via `TimeTrackerLiveActivityView`.

---

## Implementation checklist

- [ ] All colors sourced from `Color.canvas`, `Color.ink`, `Color.inkFaint`, `Color.alarm`
- [ ] No hardcoded hex values in SwiftUI views
- [ ] Reduced motion respected in every entrance animation
- [ ] Haptics match the table exactly
- [ ] Serif used only for mirror voice (numbers, receipts, insights, equivalents)
- [ ] Sans used for all interface (buttons, labels, copy)
- [ ] No decorative colors, no semantic states beyond numbers
- [ ] Live Activity renders from `accumulatedStart` formula
- [ ] Receipt totals are serif, items are sans
- [ ] Buttons are always `ink` background, `canvas` text
- [ ] Onboarding sequence is Hook → Differentiation → Permission → Picker → Notifications → Done

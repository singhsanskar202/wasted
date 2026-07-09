# Wasted 1.0 Launch Pass — Implementation Plan

> **For agentic workers:** Execute task-by-task, in order — later phases depend on earlier ones. Check boxes as you complete steps. Run the self-critique pass from the project's quality bar (§3 of the 2026-07-06 brief) before marking any UI task done. Product rationale, gating rules, and pricing live in `docs/superpowers/specs/2026-07-09-launch-pass.md` — read it first; every copy decision must match its voice.

**Goal:** Take the working mirror loop from "built" to "sellable and on the founder's iPhone": on-device bring-up, correctness fine-tuning, trial + one-time purchase, guess→reality conversion moment, widgets, app icon, App Store groundwork.

**Ground rules for the executor:**
- Voice: lowercase, blunt, short sentences. Serif = the mirror speaking. Red (`Color.alarm`) only when a number is bad. No exclamation points anywhere.
- Every new pure function gets XCTest coverage in `WastedTests/`, matching existing patterns (`@testable import Wasted`, injected `UserDefaults(suiteName:)` for storage tests).
- Any new file under `Wasted/Shared/` that the monitor extension uses **must** be added to the `DeviceActivityMonitorExt` `membershipExceptions` list in `Wasted.xcodeproj/project.pbxproj` (search for `Exceptions for "Wasted" folder in "DeviceActivityMonitorExt" target`). Forgetting this fails the ext build with "cannot find type".
- Watch for Swift type-check timeouts in the ext target on chained functional expressions — prefer plain loops (this bit `DailyReceipt` once already).
- Full verify loop after every task: `xcodebuild -scheme Wasted -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test` (61 tests green today; only add, never lose).
- Device build: `xcodebuild -scheme Wasted -destination 'id=9B8A2D59-C282-5C05-A501-51C47D3C724E' -allowProvisioningUpdates build` then install/launch via `xcrun devicectl device install app` / `... process launch`. Device: "Sanskar's iphone", iPhone 15, iOS 26.5 — has Dynamic Island.

---

## Phase 0 — Device bring-up (½ day, human-in-the-loop)

Provisioning is already verified (2026-07-09): `-allowProvisioningUpdates` mints Family Controls dev profiles for all three targets. Remaining steps need the phone in hand.

- [ ] **0.1 Install & first-run smoke test on device.** Build+install with the commands above (phone plugged in, unlocked, Developer Mode on). Walk onboarding on-device: FamilyControls sheet appears at "allow access", picker lists real apps, notification prompt fires, every haptic in the table lands. Record any copy overflow on the 6.1" screen.
- [ ] **0.2 Verify the tracking loop end-to-end.** Track Instagram (or any 2 real apps), scroll ≥5 min, confirm: threshold event fires (usage appears on home), Live Activity appears in the island, number resumes (not restarts) on app re-entry, nudge notification at 30 min, badge shows minutes.
- [ ] **0.3 Verify icon rendering.** Check whether `ActivityScheduler.saveIcons` produced real PNGs in the App Group (island shows app icon vs letter tile). Known risk: `ImageRenderer(Label(token))` renders blank off-screen on device. If blank: **delete `saveIcons` and the island's stored-icon path; ship the letter tile as the design** (it's on-palette and honest) rather than chasing a private-API workaround. Decide once, here.
- [ ] **0.4 Log findings** as checklist notes in this file (edit in place) — they steer Phase 1 priorities.

## Phase 1 — Correctness fine-tuning (1 day)

### Task 1.1: Home screen refreshes while you watch it
**Files:** `Wasted/Home/HomeView.swift`
- [ ] Add `@Environment(\.scenePhase)`; on `.active`, re-run the `onAppear` refresh block (extract to `private func refresh()`). The number must be current every time the app foregrounds, not only on first appear.
- [ ] Also call `refresh()` on receipt-sheet dismiss (`onDismiss:`).
- [ ] Acceptance: foreground the app after new usage accrues → number and heatmap update without relaunch.

### Task 1.2: Receipt reliability — main-app fallback + 9 PM auto-show
**Files:** move `DeviceActivityMonitorExt/ReceiptScheduler.swift` → `Wasted/Shared/ReceiptScheduler.swift` (+ pbxproj membershipExceptions); `Wasted/WastedApp.swift`; `Wasted/Home/HomeView.swift`; `Wasted/Shared/Models/AppGroupKeys.swift`
- [ ] Move `ReceiptScheduler` to Shared (it only uses Foundation + UserNotifications; compiles in both targets). Update pbxproj exceptions.
- [ ] `WastedApp`: on `scenePhase == .active`, call `ReceiptScheduler().refresh(usage:displayNames:)` — covers days when no threshold fires before 9 PM but the user opened the app.
- [ ] Auto-show: add `AppGroupKeys.lastReceiptAutoShowKey = "last_receipt_auto_show"`. In `HomeView.refresh()`: if `hour >= AppGroupKeys.receiptHour`, today's usage > 0, and stored value ≠ today → set `showingReceipt = true`, store today. (Light haptic already fires on receipt open — do not add another.)
- [ ] Tests: none new (Date-now dependent UI glue); logic that is pure (`AppGroupKeys` key) is covered by convention.
- [ ] Acceptance: open app at 9:30 PM with usage → receipt sheet presents itself, once; again tomorrow.

### Task 1.3: Live Activity staleness + threshold diet
**Files:** `DeviceActivityMonitorExt/LiveActivityManager.swift`, `Wasted/Monitoring/ActivityScheduler.swift`, new `WastedTests/Monitoring/ThresholdTests.swift`
- [ ] `staleDate`: 300 → **2700** (45 min). Thresholds are minutes apart; 5 min staleness dims the island constantly.
- [ ] Threshold diet in `ActivityScheduler.startMonitoring` — replace the flat 5-min stride with:
  ```swift
  static let thresholdMinutes: [Int] =
      Array(stride(from: 5, through: 120, by: 5)) +
      Array(stride(from: 130, through: 240, by: 10)) +
      Array(stride(from: 255, through: 480, by: 15))
  ```
  (52 events/app instead of 96 — same early fidelity, fewer extension wakes, headroom against DeviceActivity's undocumented event limits.) Make it `static let` on `ActivityScheduler` so it's testable.
- [ ] Test: every multiple of 30 from 30…480 is present (NudgeGate depends on it); list is strictly ascending; count == 52.
- [ ] Acceptance: island stays bright between thresholds on device; nudges still fire at every 30-min mark.

## Phase 2 — The sellable layer (2–3 days)

### Task 2.1: TrialClock + entitlement cache (pure logic first)
**Files:** new `Wasted/Shared/TrialClock.swift` (+ pbxproj ext exceptions); `Wasted/Shared/Models/AppGroupKeys.swift`; `Wasted/Shared/Storage/UsageStore.swift`; new `WastedTests/Monetization/TrialClockTests.swift`
- [ ] `AppGroupKeys`: add `firstLaunchKey = "first_launch_at"`, `lifetimeUnlockedKey = "lifetime_unlocked"`, `lifetimeProductID = "com.sanskar.Wasted.lifetime"`.
- [ ] `TrialClock`:
  ```swift
  enum TrialState: Equatable { case trial(daysLeft: Int); case expired; case unlocked }
  enum TrialClock {
      static let trialDays = 7
      static func state(firstLaunch: Date?, unlocked: Bool, now: Date = Date()) -> TrialState
      // unlocked → .unlocked. nil firstLaunch → .trial(daysLeft: 7) (caller stamps it).
      // daysLeft = trialDays - wholeDaysSince(firstLaunch), clamped ≥ 0; 0 → .expired.
  }
  ```
- [ ] `UsageStore`: `firstLaunchDate()`, `stampFirstLaunchIfNeeded(now:)`, `isUnlocked()`, `setUnlocked(_:)` — all through the injected `defaults`.
- [ ] `WastedApp`: stamp first launch on app start (device builds only — keep simulator behavior unchanged so previews/tests never hit gating; wrap the stamp + all gating in the existing `#if targetEnvironment(simulator)` pattern: simulator is always `.unlocked`).
- [ ] Tests: unlocked wins over expired; day 0 → trial(7); day 6.9 → trial(1); day 7.0 → expired; nil date → trial(7); store round-trip for all four accessors.

### Task 2.2: StoreKit 2 purchase flow
**Files:** new `Wasted/Monetization/LifetimeStore.swift`; new `Wasted/Monetization/PaywallView.swift`; new `Wasted/Wasted.storekit` (StoreKit configuration file, added to the scheme's Run options for local testing); `Wasted/Theme.swift` untouched
- [ ] `LifetimeStore` (`@MainActor final class LifetimeStore: ObservableObject`):
  - `@Published var product: Product?`, `@Published var isUnlocked: Bool`
  - `load()` — `Product.products(for:)`; `refreshEntitlement()` — iterate `Transaction.currentEntitlements`, verify, set `isUnlocked`, **cache to App Group via `UsageStore.setUnlocked`** (the extension reads only the cache); `purchase()`; `restore()` (`AppStore.sync()` then refresh). Listen to `Transaction.updates` for the app's lifetime.
  - On successful purchase: `Haptics.success()` — one of the two new haptics allowed by the spec.
- [ ] `PaywallView` — canvas background, in-voice, dismissible sheet:
  - serif headline: `keep the mirror.`
  - body (sans, faint): `no subscription. no streak to protect.\npay once. it's yours — until you\ndon't need it anymore.`
  - primary button: `unlock forever — {product.displayPrice}` (ink bg, black text, same style as onboarding buttons)
  - footer row (tiny, faint): `restore purchases` — wired to `restore()`.
- [ ] `Wasted.storekit` config: one non-consumable, `com.sanskar.Wasted.lifetime`, $9.99. Set the scheme (Run → Options → StoreKit Configuration) so purchase/restore is testable in simulator despite simulator being force-unlocked — add a `#if DEBUG` "show paywall" path: long-press on the settings row's "tracking N apps" text presents the paywall for QA.
- [ ] Tests: StoreKit itself isn't unit-tested (transaction API); TrialClock covers the logic. Manual QA via the storekit file.

### Task 2.3: Gating — home, extension, receipt
**Files:** `Wasted/Home/HomeView.swift`; `DeviceActivityMonitorExt/DeviceActivityMonitorExtension.swift`; `Wasted/WastedApp.swift`
- [ ] `HomeView`: compute `trialState` from `UsageStore` + `LifetimeStore.isUnlocked` on `refresh()`.
  - `.trial(daysLeft:)` → everything works; add one tiny line under the settings row: `day {8-daysLeft} of 7 — then it's {price} once.` (sans, `ink.opacity(0.3)`, same size as settings row). Honest trial disclosure, App Review-friendly.
  - `.expired` → big number gets `.blur(radius: 14)` + `.redacted(reason: .placeholder)` on receipt/insight sections; overlay under the number, serif italic: `still counting. you just can't see it.` and the standard button `unlock forever — {price}` → presents `PaywallView`. Receipt button presents paywall instead of receipt. Auto-receipt (Task 1.2) suppressed.
  - `.unlocked` → nothing shown. No badge, no thanks-screen. Silence is premium.
- [ ] Extension `eventDidReachThreshold`: after the delta-recording block (recording **always** runs), compute `TrialClock.state(firstLaunch: store.firstLaunchDate(), unlocked: store.isUnlocked())`; if `.expired` → skip Live Activity, nudge, and receipt refresh; still `WidgetCenter.reloadAllTimelines()`. Also skip Live Activity start in `.expired` from `intervalDidStart` if present.
- [ ] Acceptance (simulate by back-dating `first_launch_at` 8 days via a `#if DEBUG` long-press action or direct defaults write): home blurs with the line + button; purchase in storekit-config sim → everything unfrosts live; restore works after delete/reinstall.

### Task 2.4: Guess → Reality (the conversion moment)
**Files:** new `Wasted/Onboarding/GuessView.swift`; `Wasted/Onboarding/OnboardingContainerView.swift`; new `Wasted/Shared/RealityCheck.swift` (+ ext exceptions NOT needed — main app only, put in `Wasted/Insights/`); `Wasted/Home/HomeView.swift`; `WastedTests/Insights/RealityCheckTests.swift`
- [ ] `GuessView` — new onboarding step between Hook and Differentiation (order becomes: Hook → **Guess** → Differentiation → Permission → Picker → Notifications → Done):
  - headline (sans semibold 32, matching PermissionView): `how much do you\nscroll a day?`
  - subtitle: `be honest. nobody's watching.`
  - five choice chips (single select, selection haptic): `under 1h · 2h · 3h · 4h · 5h or more` → stores `daily_guess_seconds` (3600/7200/10800/14400/18000) via new `AppGroupKeys.dailyGuessKey`. Continue button `lock it in` (light haptic — this replaces the Hook-advance haptic slot for this screen; still exactly one per screen).
- [ ] `RealityCheck` (pure, `Wasted/Insights/RealityCheck.swift`):
  ```swift
  struct RealityCheck: Equatable {
      let guessLine: String    // "you guessed 2h."
      let realityLine: String  // "reality: 4h 12m."
      let deltaLine: String    // "off by 110%." | actual ≤ guess → "you actually knew."
      static func make(guessSeconds: Int, firstFullDaySeconds: Int) -> RealityCheck?
      // nil if guess missing/zero or day had 0 usage. Delta = (actual-guess)/guess rounded %.
  }
  ```
- [ ] HomeView: when history.count ≥ 1, guess exists, and `reality_check_shown` flag unset → show a full-width card above the quote, serif for all three lines, `Haptics.medium()` once on its first appearance (the spec's second allowed new haptic), `understood` text button to dismiss (sets flag). Never shows again.
- [ ] Tests: nil cases; exact strings for guess 7200 / actual 15120 → "you guessed 2h." / "reality: 4h 12m." / "off by 110%."; actual below guess → "you actually knew."; formattedDuration reuse (no new formatter).

### Task 2.5: Widgets
**Files:** new target **WastedWidgets** (reuse `WastedWidget/` folder sources); new entitlements file with the App Group; pbxproj
- [ ] **Human step (Xcode GUI, 2 min):** File → New → Target → Widget Extension, name `WastedWidgets`, no configuration intent, embed in Wasted. Hand-editing a whole new target into pbxproj is not worth the risk — flag for the user, then continue.
- [ ] Add App Group entitlement (`group.com.sanskar.Wasted`) to the new target; add `AppGroupKeys.swift`, `DailyUsage.swift`, `UsageStore.swift`, `HourlyUsage.swift`, `TrialClock.swift` to its membership (File Inspector or pbxproj exceptions).
- [ ] Rewrite `WastedWidget/WastedWidget.swift`: `TimelineProvider` reading `UsageStore().totalSecondsAllApps()`; single entry, `.after(next hour)` policy (extension already calls `reloadAllTimelines()` on every threshold — the policy is just a backstop).
  - `systemSmall`: canvas bg, `you wasted` microlabel, serif bold total (red iff ≥1h), `today` microlabel. containerBackground canvas.
  - `accessoryRectangular`: `wasted · {total}` — total red-tinted iff ≥1h. `accessoryCircular`: serif total only.
  - `.expired` state (via TrialClock from shared defaults): show `⌛︎`-free, on-voice lock: total replaced by `??m`, microlabel `unlock to see`.
- [ ] Acceptance: widget on device home screen updates within one threshold of real usage; matches palette exactly; Canvas previews added for all three families.

### Task 2.6: App icon
**Files:** `Wasted/Assets.xcassets/AppIcon.appiconset/`
- [ ] Generate a 1024×1024 PNG: `#0A0A0A` fill, centered serif italic bold "W" in `#F5F3EE` at ~62% cap height, no border, no gradient, no shadow. Generate programmatically (small `swift` script with CoreGraphics/CoreText or Python+Pillow with a bundled serif — do it in the scratchpad, drop only the PNG into the asset catalog, single-size "Any" slot).
- [ ] Acceptance: icon on device home screen; dark/tinted variants inherit acceptably (near-black bg already reads correctly in dark mode).

## Phase 3 — Store groundwork (parallel to testing week; mostly human)

- [ ] **3.1 Create the App Store Connect app record** — name attempt: `Wasted — Screen Time Mirror` (27 chars); bundle `com.sanskar.Wasted`. If name collides, fallbacks: `Wasted: Screen Time Mirror`, `Wasted — the screen time mirror` (record what stuck).
- [ ] **3.2 Immediately submit the Family Controls distribution entitlement request** (developer.apple.com → account → entitlement request form) for `com.sanskar.Wasted` **and** `com.sanskar.Wasted.DeviceActivityMonitorExt`. This is the launch long pole (days–weeks); everything else can proceed while it's pending. Dev builds are unaffected.
- [ ] **3.3 Enroll in the App Store Small Business Program** (15% commission).
- [ ] **3.4 Create the $9.99 non-consumable** in ASC matching `com.sanskar.Wasted.lifetime`.
- [ ] **3.5 Privacy**: nutrition label = Data Not Collected (verify: no analytics, no network calls anywhere in the codebase — grep for URLSession to prove it); write a 1-page privacy policy (static page, "nothing leaves your device"), host anywhere linkable.
- [ ] **3.6 Store copy** (draft in `docs/store/listing.md`, in-voice but *sentence case* for the description body — App Store context, not the app):
  - Subtitle (30 chars): `you can't unsee the number`
  - Promo text: the anti-subscription line from the spec.
  - Description skeleton: the emotional sequence from spec §1 — guess/reality/receipt/no-subscription — then the "what it never does" list (never blocks, no streaks, no ads, no tracking).
  - Keywords: screen time, digital wellbeing, phone addiction, app usage, focus, dumb phone, scroll, habit — refine with the app-store skill later.
- [ ] **3.7 Screenshots**: 6 shots mirroring the mockup artifact scenes (hook line, home number, receipt, island, reality check, "no subscription" card). Device frames from the real iPhone 15 once Phase 2 is on it.
- [ ] **3.8 TestFlight**: internal build once Phase 2 lands; then 5–10 friends external. One question to testers only: *"after a week — did you open it on your own?"* (That answers §1's retention bet; everything else is noise.)

## Definition of done for this pass

1. All phases 0–2 checked; 61+N tests green; device build installs and the full loop (track → island → nudge → receipt → reality check → paywall → purchase → unfrost) demonstrated on the physical iPhone.
2. Phase 3 items 3.1–3.4 submitted/created (human), 3.5–3.7 drafted.
3. `.claude/memory/project-mindfultime.md` updated: what shipped, icon-rendering decision from 0.3, entitlement-request submission date, what's next.
4. Work committed to a `fable/launch-pass` branch (branch from `fable/mirror-polish` or merged main — check with the user which base they merged).

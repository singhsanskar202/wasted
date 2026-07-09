---
name: project-wasted
description: Wasted — iOS screen time awareness app. Paid Apple Developer account active, launch pass (trial + $9.99 lifetime IAP, guess/reality, widgets) implemented and installed on physical iPhone 2026-07-09. 68 tests pass.
metadata: 
  node_type: memory
  type: project
  originSessionId: 329444d4-ba54-4700-8297-c235c24e4d9a
---

**Wasted** is an iOS app (iPhone 14 Pro+, iOS 17+) that tracks per-app screen time, shows a live ticking counter in the Dynamic Island, and confronts the user with blunt usage data. It is a **mirror, not a blocker** — never blocks/locks, no streak guilt, no ads.

**Positioning (locked in 2026-07-09):** "you can ignore a blocker. you can't unsee a number." Free 7-day trial → **$9.99 one-time lifetime unlock, no subscription** — the anti-subscription stance is the marketing, not just the price.

**GitHub:** https://github.com/singhsanskar202/wasted
**Local project:** `/Users/sanskarsingh/Documents/wasted/Wasted/`

---

## Current state (2026-07-09)

**Builds clean** on Xcode 26.6, iOS 26.5, both simulator and **physical device** (iPhone 15, "Sanskar's iphone", devicectl id `9B8A2D59-C282-5C05-A501-51C47D3C724E`). **Tests: 68/68 pass** (`xcodebuild -scheme Wasted -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`).

**Apple Developer Program is active** (was pending as of 2026-07-06, confirmed active by 2026-07-09). Family Controls dev provisioning verified working — `xcodebuild -scheme Wasted -destination 'id=<device>' -allowProvisioningUpdates build` succeeds and signs all 3 targets with real entitlements.

**Device build/install/launch commands** (no Xcode GUI needed):
```bash
xcodebuild -scheme Wasted -destination 'id=9B8A2D59-C282-5C05-A501-51C47D3C724E' -allowProvisioningUpdates build
xcrun devicectl device install app --device 9B8A2D59-C282-5C05-A501-51C47D3C724E "<DerivedData path>/Wasted.app"
xcrun devicectl device process launch --device 9B8A2D59-C282-5C05-A501-51C47D3C724E com.sanskar.Wasted
```
`xcrun devicectl list devices` to check connectivity (must show `connected`, not `available (paired)` — the latter means unlock the phone). `xcrun devicectl device info processes --device <id> | grep -i wasted` to check whether `DeviceActivityMonitorExt` and `Wasted` are running — useful for confirming DeviceActivity registration actually succeeded without deeper log access (no `idevicesyslog`/log-stream tooling available in this environment for physical devices).

**Architecture — 3 Xcode targets + tests + not-yet-wired widget source:** `Wasted` (app), `DeviceActivityMonitorExt`, `LiveActivityExtExtension`, `WastedTests`. `WastedWidget/` folder has ready source but **no Xcode target yet** (needs manual File → New → Target → Widget Extension — see "What's next").
**Key identifiers:** Bundle `com.sanskar.Wasted`, App Group `group.com.sanskar.Wasted`, Team `ZZZ87SSQ8S`, target iOS 26.5. StoreKit product `com.sanskar.Wasted.lifetime` ($9.99 non-consumable), local `.storekit` config wired into the Wasted scheme's Run+Test actions for simulator testing.

---

## What shipped 2026-07-09 ("launch pass")

Spec/plan: `docs/superpowers/{specs,plans}/2026-07-09-launch-pass.md`.

- **Entitlements wired for real device**: `Wasted/Wasted.entitlements`, `DeviceActivityMonitorExt/DeviceActivityMonitorExt.entitlements`, `LiveActivityExt/LiveActivityExt.entitlements` — Family Controls + App Groups. Removed the free-account `CODE_SIGNING_REQUIRED=NO` workaround.
- **TrialClock** (`Wasted/Shared/TrialClock.swift`, both targets) — pure `state(firstLaunch:unlocked:now:)`, 7-day local trial computed from elapsed wall-clock time (not calendar days, to avoid DST edge cases). `UsageStore` gained `firstLaunchDate/stampFirstLaunchIfNeeded/isUnlocked/setUnlocked`.
- **StoreKit 2**: `Wasted/Monetization/LifetimeStore.swift` (`@MainActor ObservableObject`, caches entitlement to the App Group so the extension can read it without StoreKit access) + `PaywallView.swift` ("keep the mirror." / no-subscription copy / restore purchases). `.storekit` config at `Wasted/Wasted.storekit`.
- **Gating**: HomeView blurs+redacts the number/receipt/insight block and shows a frost overlay ("still counting. you just can't see it.") when `.expired`; trial shows a quiet "day N of 7 — then it's $9.99 once." line. Extension (`DeviceActivityMonitorExtension.eventDidReachThreshold`) skips Live Activity/nudge/receipt when expired but **usage recording never stops** — data is there the day they buy.
- **Guess → Reality conversion moment**: new `GuessView` onboarding screen (Hook → **Guess** → Differentiation → Permission → Picker → Notifications → Done), pure `RealityCheck.make(guessSeconds:firstFullDaySeconds:)` in `Wasted/Insights/`, persistent reveal card on HomeView shown until dismissed (medium haptic once per view lifecycle, not per refresh).
- **Correctness fixes**: HomeView now refreshes on `scenePhase == .active` and on receipt-sheet dismiss (was onAppear-only). `ReceiptScheduler` moved from ext-only to `Wasted/Shared/` and also called from `WastedApp` on foreground — closes the gap where no threshold fired before 9 PM. Live Activity `staleDate` 300s → 2700s (island was dimming between threshold updates).
- **Threshold diet, then un-dieted at the low end**: tapered 5→10→15-min steps past 2h/4h (52 events/app) to stay off DeviceActivity's undocumented per-app event cap — but **first on-device test showed nothing tracking**, root-caused to the 5-minute *first* threshold combined with Apple's well-known "best effort" latency on top of that. Added 1-min granularity for the first 5 minutes (`1,2,3,4,5` then existing cadence) — 56 events/app now. This is a genuine product improvement too (mirror should react fast), not just a debug hack. **Important:** changing this list in code does NOT retroactively re-register an already-running DeviceActivityCenter schedule — the user must trigger `ActivityScheduler.startMonitoring` again (e.g. Home → edit → toggle a tracked app off/on) after installing a build with new thresholds, or redo onboarding.
- **App icon**: generated programmatically (Python/Pillow + NewYorkItalic.ttf) — serif italic "W", `#F5F3EE` on `#0A0A0A`/black, light/dark/tinted variants in `AppIcon.appiconset`.
- **Widget source rewritten** (`WastedWidget/WastedWidget.swift`) to match palette + trial gating (systemSmall + accessoryCircular + accessoryRectangular in one widget, family-switched) — ready to drop into a target once created via Xcode GUI.

## Key gotchas (cumulative)

- `ApplicationToken.bundleIdentifier` is private — event names are `"appIndex:minutes"`; icons keyed by display name. Known risk (untested as of 2026-07-09): `ImageRenderer(Label(token))` can render blank off-screen on real devices — if the Island shows letter tiles instead of real icons, that's the fallback working as designed, not a bug; decide whether to keep chasing real icons or ship the letter tile permanently.
- `accumulatedStart = Date() - totalSeconds` makes the Live Activity resume from the day's total.
- **Synchronized-group target membership:** shared files used by the extension must be listed in the ext's `membershipExceptions` in `project.pbxproj` (now includes `Nudges.swift`, `DailyReceipt.swift`, `ReceiptScheduler.swift`, `TrialClock.swift`). A missed entry fails with "cannot find type …".
- Big chained functional expressions can hit "unable to type-check in reasonable time" in the ext target — write loops, not `.filter/.map/.sorted` chains (bit `DailyReceipt` once already).
- `LifetimeStore`/`PaywallView` need `import StoreKit`; `LifetimeStore` also needs explicit `import Combine` (doesn't import SwiftUI, so `@Published`/`ObservableObject` don't come for free) — both caused real build failures this session, easy to hit again in new StoreKit code.
- `UsageStore.defaults` must stay `internal`; `#if targetEnvironment(simulator)` bypasses onboarding *and* forces `.unlocked` trial state in `WastedApp.swift`/`HomeView.swift` — simulator never shows the paywall.
- **Device connectivity**: `xcrun devicectl list devices` showing `available (paired)` instead of `connected` means the phone is locked or the tunnel dropped — unlock it. A stale Xcode account session (`DVTDeveloperAccountCredentialsError`) needs Xcode → Settings → Accounts → remove and re-add the Apple ID; can't be fixed from CLI.
- **DeviceActivity threshold changes require re-registration**: editing `ActivityScheduler.thresholdMinutes` and shipping a new build does not update an already-running monitoring schedule. Must call `startMonitoring` again post-install (toggle tracked apps in Settings, or redo onboarding).

## What's next
1. **Confirm tracking works on-device** with the new 1-minute first threshold (in progress — user was mid-test when this session's context ended; re-trigger monitoring registration first per the gotcha above).
2. **Icon rendering decision** (Phase 0.3 from the launch-pass plan, still open): once tracking is confirmed, check whether the Island shows real app icons or letter tiles, and decide whether to keep `ActivityScheduler.saveIcons` or delete it.
3. **Widget target**: 2-minute manual Xcode step (File → New → Target → Widget Extension, name `WastedWidgets`, embed in Wasted, add App Group entitlement, add `AppGroupKeys/DailyUsage/UsageStore/HourlyUsage/TrialClock` to its membership) — source is ready in `WastedWidget/`.
4. **App Store groundwork** (Phase 3 of the launch-pass plan, entirely human/account-side): create the ASC app record, **submit the Family Controls distribution entitlement request immediately** (this is the actual launch long pole — days to weeks turnaround), enroll in the Small Business Program, create the $9.99 IAP in ASC, privacy policy + store copy.
5. Full end-to-end demo on device: onboarding → tracking → nudge → receipt → reality check → paywall → purchase (via `.storekit` config, not real money) → unfrost.

**How to apply:** Pick up exactly where this session left off — the user was actively testing on their iPhone when it ended. Don't re-plan; check in on the tracking test result first.

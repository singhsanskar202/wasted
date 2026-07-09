---
name: project-wasted
description: Wasted — iOS screen time awareness app. Paid dev account active, launch pass implemented. Deep in Dynamic Island debugging on physical iPhone 2026-07-09 — two real platform bugs found and fixed (missing plist key, extension can't call Activity.request()), third fix (black-screen rendering) applied but NOT YET VERIFIED on device.
metadata: 
  node_type: memory
  type: project
  originSessionId: 329444d4-ba54-4700-8297-c235c24e4d9a
---

**Wasted** is an iOS app (iPhone 14 Pro+, iOS 17+) that tracks per-app screen time, shows a live ticking counter in the Dynamic Island, and confronts the user with blunt usage data. It is a **mirror, not a blocker** — never blocks/locks, no streak guilt, no ads.

**Positioning (locked in 2026-07-09):** "you can ignore a blocker. you can't unsee a number." Free 7-day trial → **$9.99 one-time lifetime unlock, no subscription** — the anti-subscription stance is the marketing, not just the price.

**GitHub:** https://github.com/singhsanskar202/wasted (branch `fable/mirror-polish`)
**Local project:** `/Users/sanskarsingh/Documents/wasted/Wasted/`

---

## ⚠️ START HERE next session

Mid-debug on the physical device. Three real Apple-platform bugs found via live device testing (not simulator-discoverable — simulator doesn't run DeviceActivity at all). Two are confirmed fixed. The third (black Dynamic Island / black lock screen banner) has a code fix applied and pushed, **but was never actually verified on the device before this session ended** — that's the very next thing to do.

**Immediate next step:** rebuild for device, install, launch, have the user foreground the app once (to trigger the main-app-side Live Activity start), then check whether the Island/lock screen actually shows content now instead of a black shape. See "Device commands" below.

---

## Current state (2026-07-09, end of session)

**Builds clean**, **68/68 tests pass** (`xcodebuild -scheme Wasted -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`). Confirmed building/signing/installing on the physical device throughout this session.

**Apple Developer Program is active.** Family Controls dev provisioning verified working.

### Device commands (no Xcode GUI needed)
```bash
# Check connectivity first — must say "connected", not "available (paired)" (locked phone)
xcrun devicectl list devices

# Build, install, launch
xcodebuild -scheme Wasted -destination 'id=9B8A2D59-C282-5C05-A501-51C47D3C724E' -allowProvisioningUpdates build
APP_PATH="/Users/sanskarsingh/Library/Developer/Xcode/DerivedData/Wasted-aafjzoguyxmfxabzoqdomhmhgbnv/Build/Products/Debug-iphoneos/Wasted.app"
xcrun devicectl device install app --device 9B8A2D59-C282-5C05-A501-51C47D3C724E "$APP_PATH"
xcrun devicectl device process launch --device 9B8A2D59-C282-5C05-A501-51C47D3C724E com.sanskar.Wasted
```

### Pulling real diagnostic data off the device (huge win this session — use this before guessing)
No log-streaming tool is available for physical devices in this environment (no `idevicesyslog`, `log stream` is simulator/Mac-only). Instead, **pull the App Group's shared UserDefaults plist directly** — this is how every real bug this session actually got found, not by guessing:
```bash
xcrun devicectl device copy from \
  --device 9B8A2D59-C282-5C05-A501-51C47D3C724E \
  --domain-type appGroupDataContainer \
  --domain-identifier group.com.sanskar.Wasted \
  --source "Library/Preferences/group.com.sanskar.Wasted.plist" \
  --destination /tmp/wasted.plist
plutil -convert xml1 -o - /tmp/wasted.plist
```
`daily_usage` is base64-encoded JSON inside the plist — decode with `python3 -c "import base64; print(base64.b64decode('...').decode())"`. There's also a `systemCrashLogs` domain-type available via the same `devicectl device copy from` pattern if a future bug needs crash logs instead of app state.

A **temporary diagnostic key** `debug_live_activity_log` was added to the shared storage by `LiveActivityManager.logDebug()` (in `Wasted/Shared/LiveActivityManager.swift`) — logs the last 8 attempts to start/update a Live Activity, including thrown errors. **Remove this once Live Activity behavior is confirmed working** — it's marked TEMPORARY in the code.

---

## The three real bugs found this session (in order discovered)

All three were invisible in the simulator and only surfaced via physical-device testing — this is expected; DeviceActivity/ActivityKit are effectively no-ops on the simulator.

### 1. FIXED & CONFIRMED — missing `NSSupportsLiveActivities` Info.plist key
`Activity.request()` requires this key on the **main app's** Info.plist or it fails silently (wrapped in the original code's `try?`). Was never set. Fixed by adding `INFOPLIST_KEY_NSSupportsLiveActivities = YES;` to both Debug/Release configs of the `Wasted` target in `project.pbxproj`. Verified present in the built Info.plist via `PlistBuddy`.

### 2. FIXED & CONFIRMED — `Activity.request()` can only be called from the main app process
`DeviceActivityMonitorExt` (the background extension that detects usage thresholds) was calling `Activity<TimeTrackerAttributes>.request()` directly — this **always** throws `ActivityAuthorizationError.unsupportedTarget` on real devices, confirmed via pulled diagnostic logs (`request FAILED: unsupportedTarget areActivitiesEnabled=true` — note `areActivitiesEnabled=true`, ruling out the Settings-toggle theory). Confirmed via Apple's own docs and multiple independent developer forum threads: only the containing app may create a Live Activity; extensions may not, though an extension *can* update an already-existing one.

**Architecture change made:** moved `LiveActivityManager.swift` from `DeviceActivityMonitorExt/` to `Wasted/Shared/LiveActivityManager.swift` (wired into both targets' compile sources via `project.pbxproj` `membershipExceptions`). Added `WastedApp.swift` → `startLiveActivityIfNeeded(store:displayNames:)`, called on `scenePhase == .active`, which finds the top-usage app for today and calls `LiveActivityManager().startOrUpdate(...)` — this now runs in the **main app** process, where `.request()` is allowed. The extension's existing `startOrUpdate` calls (unchanged) now land on the "update existing activity" branch once the main app has created one. Confirmed via pulled logs: `request OK id=163E3991-... areActivitiesEnabled=true total=1200`.

**Product-behavior consequence (accepted, explained to user):** the Island can no longer spontaneously appear the instant a tracked app is opened if Wasted hasn't been foregrounded yet that session — it needs one "warm-up" open of Wasted to create the first activity of the day. After that, if extension-side `.update()` on an existing activity works (see next item — **still unconfirmed**), it should update close to real-time for the rest of that day.

### 3. FIX APPLIED, **NOT YET VERIFIED ON DEVICE** — black/empty Dynamic Island + no lock-screen banner
After bug #2's fix, the user reported: tapping the Dynamic Island (which appeared as a plain black shape) opened the app correctly (proving the Activity *is* running and registered), but showed no visible icon/text/time. Lock screen showed nothing at all. This is a **known, documented ActivityKit issue** (confirmed via Apple Developer Forums thread 807726, "Live Activity Shows Only Black Dynamic Island") — the fix community/Apple-recommended: use `.activityBackgroundTint(_:)` + `.activitySystemActionForegroundColor(_:)` on the Live Activity's root view instead of a plain SwiftUI `.background()` modifier, and specifically *avoid* `.containerBackground()` for Live Activities (that's a regular-widget-only requirement, not for ActivityKit).

**Fix applied** in `LiveActivityExt/TimeTrackerLiveActivityView.swift`: added `.activityBackgroundTint(Color.black)` and `.activitySystemActionForegroundColor(Color.white)` to the lock-screen closure in `ActivityConfiguration`, and removed the old `.background(Color.black)` from `LockScreenBannerView`. Builds and tests pass (simulator-only — this can't be verified in the simulator at all).

**This is the very next thing to test**: rebuild for device, install, launch, foreground the app once (creates the activity via bug-#2's fix), then have the user look at the Island and lock screen to confirm actual content now renders instead of black.

### Also noticed, not yet fixed (low priority, cosmetic)
Display names show as generic "App 0"/"App 1" instead of "Instagram" etc. — `token.localizedDisplayName` is returning `nil` in `ActivityScheduler.startMonitoring`/`saveIcons` on this device, a known FamilyControls quirk. Confirmed via the same pulled plist (`display_names` decoded to `{"0":"App 0","1":"App 1"}`). Also means no real app icons were ever saved (the `saveIcons` guard on `!name.isEmpty` silently skips when name is nil), so the Island/lock-screen icon fallback (letter-tile) is what's actually in play — separate from the black-screen bug, will only become visible/testable once bug #3 is confirmed fixed.

---

## What shipped 2026-07-09 ("launch pass" — before the debugging above)

Spec/plan: `docs/superpowers/{specs,plans}/2026-07-09-launch-pass.md`.

- **Entitlements wired for real device**: `Wasted/Wasted.entitlements`, `DeviceActivityMonitorExt/DeviceActivityMonitorExt.entitlements`, `LiveActivityExt/LiveActivityExt.entitlements` — Family Controls + App Groups.
- **TrialClock** (`Wasted/Shared/TrialClock.swift`, both targets) — pure `state(firstLaunch:unlocked:now:)`, 7-day local trial. `UsageStore` gained `firstLaunchDate/stampFirstLaunchIfNeeded/isUnlocked/setUnlocked`.
- **StoreKit 2**: `Wasted/Monetization/LifetimeStore.swift` + `PaywallView.swift`. `.storekit` config at `Wasted/Wasted.storekit`, wired into the scheme.
- **Gating**: HomeView blurs+redacts and shows a frost overlay when trial `.expired`; extension skips Live Activity/nudge/receipt when expired but usage recording never stops.
- **Guess → Reality conversion moment**: `GuessView` onboarding screen (Hook → Guess → Differentiation → Permission → Picker → Notifications → Done), `RealityCheck.make(...)`, persistent reveal card on HomeView.
- **Correctness fixes**: HomeView refreshes on `scenePhase == .active` and receipt-sheet dismiss. `ReceiptScheduler` moved to `Wasted/Shared/`, also called from `WastedApp` on foreground. Live Activity `staleDate` 300s → 2700s.
- **Threshold list**: `1,2,3,4,5` then `10...120` by 5, `130...240` by 10, `255...480` by 15 (56 events/app) — the 1-minute-first-five exists specifically so the Island reacts fast once bugs #2/#3 above are confirmed fixed.
- **App icon**: generated programmatically (Python/Pillow + NewYorkItalic.ttf) — serif italic "W" — light/dark/tinted variants in `AppIcon.appiconset`.
- **Widget source rewritten** (`WastedWidget/WastedWidget.swift`) — ready to drop into a target once created via Xcode GUI (not yet done).

## Key gotchas (cumulative — read before touching Live Activity or extension code)

- **`Activity.request()` is main-app-only. Never call it from `DeviceActivityMonitorExt`.** (bug #2 above — this is the big one, easy to reintroduce if `LiveActivityManager` usage is ever refactored again.)
- **Live Activities need `.activityBackgroundTint()`/`.activitySystemActionForegroundColor()`, not a plain `.background()` modifier, or content renders as a black shape** (bug #3 above).
- `NSSupportsLiveActivities` must be `YES` in the main app's Info.plist (`INFOPLIST_KEY_NSSupportsLiveActivities` build setting) — easy to lose if the target's build settings ever get regenerated.
- `ApplicationToken.bundleIdentifier` is private — event names are `"appIndex:minutes"`; icons keyed by display name, which can be `nil` on-device (see "also noticed" above) — the letter-tile fallback exists for exactly this reason, treat it as expected, not broken.
- `accumulatedStart = Date() - totalSeconds` makes the Live Activity resume from the day's total via SwiftUI's own ticking, not repeated pushes.
- **Synchronized-group target membership:** shared files used by the extension must be listed in the ext's `membershipExceptions` in `project.pbxproj` (now includes `Nudges.swift`, `DailyReceipt.swift`, `ReceiptScheduler.swift`, `TrialClock.swift`, `LiveActivityManager.swift`). A missed entry fails with "cannot find type …".
- Big chained functional expressions can hit "unable to type-check in reasonable time" in the ext target — write loops, not `.filter/.map/.sorted` chains.
- `LifetimeStore`/`PaywallView` need `import StoreKit`; `LifetimeStore` also needs explicit `import Combine`.
- `#if targetEnvironment(simulator)` bypasses onboarding *and* forces `.unlocked` trial state — simulator never shows the paywall, and **can't test any ActivityKit/DeviceActivity behavior at all** — all three bugs above were only discoverable on a real device.
- **Device connectivity**: `available (paired)` instead of `connected` means the phone is locked — ask the user to unlock it, don't assume a build/launch will work.
- **DeviceActivity threshold changes require re-registration**: editing `ActivityScheduler.thresholdMinutes` and shipping a new build does not update an already-running monitoring schedule. Must call `startMonitoring` again post-install (toggle tracked apps in Settings, or redo onboarding) — though note Apple's threshold counters appear to track total-usage-for-the-day regardless of when your app (re-)registered, so a toggle doesn't necessarily "reset the clock" the way you'd expect. Still investigating exact semantics here.

## What's next
1. **Verify bug #3's fix on device** (the immediate next step — see "START HERE" above).
2. If Island/lock-screen content renders correctly now: test whether the *extension's* `.update()` calls (on the activity the main app created) actually take effect in near-real-time, or whether the Island only ever refreshes on next app foreground. This determines the real product behavior — document whichever it turns out to be.
3. Remove the temporary `debug_live_activity_log` diagnostic once confirmed working (`Wasted/Shared/LiveActivityManager.swift`).
4. Fix the `localizedDisplayName` nil issue so the Island shows "Instagram" instead of "App 1", and real icons instead of letter tiles (or confirm this is unfixable and lean into the letter-tile design).
5. **Widget target**: 2-minute manual Xcode step (File → New → Target → Widget Extension, name `WastedWidgets`, embed in Wasted, add App Group entitlement, add `AppGroupKeys/DailyUsage/UsageStore/HourlyUsage/TrialClock` to its membership) — source is ready in `WastedWidget/`.
6. **App Store groundwork** (Phase 3 of the launch-pass plan, entirely human/account-side): create the ASC app record, **submit the Family Controls distribution entitlement request immediately** (this is the actual launch long pole — days to weeks turnaround), enroll in the Small Business Program, create the $9.99 IAP in ASC, privacy policy + store copy.

**How to apply:** Don't re-plan, don't re-diagnose bugs #1/#2 (confirmed fixed) — go straight to verifying bug #3 on device per "START HERE."

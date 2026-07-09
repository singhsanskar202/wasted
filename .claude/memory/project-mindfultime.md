---
name: project-wasted
description: Wasted — iOS screen time awareness app. Launch pass implemented. STUCK on a Dynamic Island rendering bug across an entire debugging session 2026-07-09 — extensive elimination done (6+ real bugs found/fixed along the way), but the core symptom (Live Activity creates successfully, extension never renders) persists. One untested hypothesis remains — see "START HERE."
metadata: 
  node_type: memory
  type: project
  originSessionId: 329444d4-ba54-4700-8297-c235c24e4d9a
---

**Wasted** is an iOS app (iPhone 14 Pro+, iOS 17+) that tracks per-app screen time, shows a live ticking counter in the Dynamic Island, and confronts the user with blunt usage data. It is a **mirror, not a blocker** — never blocks/locks, no streak guilt, no ads.

**Positioning:** "you can ignore a blocker. you can't unsee a number." Free 7-day trial → **$9.99 one-time lifetime unlock, no subscription**.

**GitHub:** https://github.com/singhsanskar202/wasted (branch `fable/mirror-polish`)
**Local project:** `/Users/sanskarsingh/Documents/wasted/Wasted/`
**Device under test:** "Sanskar's iphone", iPhone 15, iOS 26.5, devicectl id `9B8A2D59-C282-5C05-A501-51C47D3C724E`.

---

## ⚠️ START HERE next session

**The Dynamic Island / Live Activity is still not rendering any content on the physical device, after an entire session of elimination.** This is the #1 open problem. Read this whole section before touching code — an enormous amount has already been ruled out, and re-testing any of it wastes time.

### Confirmed facts (via direct device evidence, not guesses)
- `Activity<TimeTrackerAttributes>.request()` **succeeds** reliably from the main app (confirmed via pulled diagnostic logs, dozens of times, all day: `request OK id=... areActivitiesEnabled=true total=...`).
- The widget extension (`LiveActivityExtExtension`) has **never once appeared in the device's running-process list**, all day, across 10+ installs — while every other installed app's widget/Live Activity extension (Instagram, WhatsApp, Zomato, Gmail, etc.) *is* listed as running. `liveactivitiesd` (Apple's own system daemon) is running fine.
- A custom diagnostic (`debug_render_log`, written from *inside* `TimeTrackerWidget.body` / `LockScreenBannerView.body` / every `DynamicIsland` region closure) has **never received a single entry**, meaning the system has never even invoked our SwiftUI rendering code — this isn't a "renders wrong," it's "never asked to render at all."
- Visually: the Dynamic Island shows a **plain black pill** (tappable — tapping/long-pressing it opens the app, but shows zero content, confirmed via screenshot during 3D Touch). Lock screen shows nothing.
- User confirmed in iOS Settings: **Live Activities toggle for Wasted is ON.**

### Ruled out this session (each with concrete evidence — do not re-investigate)
1. ~~Missing `NSSupportsLiveActivities`~~ — added, verified present in built Info.plist via PlistBuddy. Not the (whole) fix.
2. ~~Extension calling `Activity.request()` directly~~ — real bug, real fix: moved `LiveActivityManager` to `Wasted/Shared/`, main app now creates the first activity via `WastedApp.startLiveActivityIfNeeded()` on `scenePhase == .active`. Confirmed working (`.request()` succeeds from main app). Did not fix the rendering symptom.
3. ~~"Black Dynamic Island" needs `.activityBackgroundTint()` not `.background()`~~ — applied (this is a real, documented ActivityKit gotcha and the fix is correct practice regardless), did not fix the symptom.
4. ~~Stale/racing activity object~~ — found and fixed a real bug: `scenePhase` can fire `.active` more than once per cold launch, and the fire-and-forget `endAllActivities()` could race a fresh creation. Fixed with `endAllActivitiesAndWait()` + a `Self.hasAttemptedLiveActivityThisLaunch` static guard (once per process). Did not fix the symptom.
5. ~~Debug-dylib stub not loading~~ — **real, serious bug, definitely fix, but not sufficient alone.** Modern Xcode compiles Debug builds as a tiny stub executor + separate `.debug.dylib` (for Previews injection). This mechanism assumes an active Xcode session; confirmed via `strings`/`nm` that our extension's *actual* compiled code only lived in the `.debug.dylib`, while the main executable was a ~90KB stub containing none of our strings/symbols. Fixed by adding `ENABLE_DEBUG_DYLIB = NO;` to the project-level Debug config in `project.pbxproj`. Verified: binary size jumped from 90KB → 630KB and now contains our real strings (`"you won't get back."` etc.) directly. **This was a great find and should stay fixed regardless of what else is wrong** — but the render log was still empty after this fix too.
6. ~~Leftover Xcode template files causing conflicts~~ — `LiveActivityExt/` had 4 completely unused, uninspected files from the original Xcode "New Target" scaffold: `LiveActivityExtLiveActivity.swift` (a *second*, dead `ActivityConfiguration` for a fake `LiveActivityExtAttributes` type!), `LiveActivityExt.swift`, `LiveActivityExtControl.swift`, `AppIntent.swift`. None were referenced by the actual `@main` `LiveActivityExtBundle`, but deleted them anyway to rule out any interference. Clean build, all tests pass. Did not fix the symptom.
7. ~~Device restart~~ — user did a full power-cycle (not just lock/unlock). No change.
8. ~~Install method (devicectl CLI vs Xcode's own Run button)~~ — user ran directly via Xcode ▶. Extension still never appeared in the process list afterward.
9. ~~Crash~~ — checked `systemCrashLogs` domain exhaustively (`devicectl device info files --domain-type systemCrashLogs`, plus a targeted Jetsam pull) — zero crash reports for Wasted/LiveActivity/TimeTracker, ever.
10. ~~Entitlements / provisioning profile mismatch~~ — checked both the *requested* entitlements (`LiveActivityExt.entitlements`) and the **actual Apple-granted profile** embedded in the built `.appex` (`security cms -D -i embedded.mobileprovision`) — both correctly grant `com.apple.security.application-groups` for `group.com.sanskar.Wasted`. No mismatch.

### The one remaining, untested hypothesis
Every other app with a rendering widget extension on this device is **distribution-signed** (App Store). Ours is **development-signed** (`get-task-allow=true` in the profile). Working theory: `liveactivitiesd` may require an **actively-attached Xcode debug session** to be willing to spawn a debug-signed sibling extension process — meaning it might only render while Xcode's session is live, not after a CLI launch returns or after switching away from Xcode.

**Untested next step:** run via Xcode's ▶ button, and — without pressing Stop or switching away from Xcode — immediately check the phone's Dynamic Island *while Xcode still shows "Running Wasted on [device]" in its top bar*. This was asked of the user but the session ended before we got the result. **This is the very first thing to check in the next session.**

If that's *not* it either, remaining untried ideas, roughly in order of promise:
- Try a genuine **TestFlight** build (real distribution signing) — if the Island renders under TestFlight but never under any development-signed build, that confirms the development-signing theory conclusively, and is likely just something to accept until closer to launch.
- File/search Apple Developer Forums for "`liveactivitiesd` extension never launches development build" specifically (narrower than searches already tried this session).
- Consider that this specific iPhone 15 / iOS 26.5 combination (a very recent OS version) might have a genuine platform bug — try (if available) a second physical device to isolate device-specific vs. universal.
- As an absolute last resort: a full from-scratch new Xcode Widget Extension target (rather than continuing to debug this one), migrating only `TimeTrackerWidget`'s body content over — in case there's damage to the target's configuration from the original scaffold that isn't visible in any file we've inspected (e.g. a corrupted target UUID reference, orphaned build phase, etc. inside `project.pbxproj` that's hard to spot by reading).

### Diagnostic tooling that works (reuse freely, don't rebuild)
No log-streaming tool exists for physical devices in this environment (no `idevicesyslog`, `log stream` is simulator/Mac-only). Instead:

```bash
# Device connectivity check — must say "connected", not "available (paired)" (locked phone)
xcrun devicectl list devices

# Build, install, launch (swap in current DerivedData hash if it changes)
xcodebuild -scheme Wasted -destination 'id=9B8A2D59-C282-5C05-A501-51C47D3C724E' -allowProvisioningUpdates build
APP_PATH="/Users/sanskarsingh/Library/Developer/Xcode/DerivedData/Wasted-aafjzoguyxmfxabzoqdomhmhgbnv/Build/Products/Debug-iphoneos/Wasted.app"
xcrun devicectl device install app --device 9B8A2D59-C282-5C05-A501-51C47D3C724E "$APP_PATH"
xcrun devicectl device process launch --device 9B8A2D59-C282-5C05-A501-51C47D3C724E com.sanskar.Wasted

# Pull the App Group's shared UserDefaults plist directly off the device —
# this is how literally every bug this session got found, not by guessing
xcrun devicectl device copy from \
  --device 9B8A2D59-C282-5C05-A501-51C47D3C724E \
  --domain-type appGroupDataContainer \
  --domain-identifier group.com.sanskar.Wasted \
  --source "Library/Preferences/group.com.sanskar.Wasted.plist" \
  --destination /tmp/wasted.plist
plutil -convert xml1 -o - /tmp/wasted.plist
# daily_usage etc. are base64-encoded JSON inside — decode with:
# python3 -c "import base64; print(base64.b64decode('...').decode())"

# Check what's actually running (widget extensions for every OTHER app show
# up here; ours never has)
xcrun devicectl device info processes --device 9B8A2D59-C282-5C05-A501-51C47D3C724E | grep -i "livea\|wasted"

# Crash logs (all empty for us so far, but the domain works)
xcrun devicectl device info files --device 9B8A2D59-C282-5C05-A501-51C47D3C724E --domain-type systemCrashLogs --filter "Name CONTAINS 'X'"

# Verify a built binary isn't a stub (bit us once — see ruled-out #5)
strings "<path>/SomeExtension.appex/SomeExtension" | grep "some known string from your code"
ls -la "<path>/SomeExtension.appex/"   # look for a lingering *.debug.dylib

# Verify actual Apple-granted entitlements vs. what you requested
codesign -d --entitlements :- "<path>/SomeExtension.appex"
security cms -D -i "<path>/SomeExtension.appex/embedded.mobileprovision" | plutil -extract Entitlements xml1 -o - -
```

Two **temporary diagnostic keys** are live in the shared App Group storage, written by `Wasted/Shared/LiveActivityManager.swift` and `LiveActivityExt/TimeTrackerLiveActivityView.swift` respectively — **remove both once the rendering bug is actually fixed**:
- `debug_live_activity_log` — last 8 attempts to start/update/request a Live Activity, including thrown errors, from the app/extension side.
- `debug_render_log` — last 10 invocations of the widget's own SwiftUI rendering code (currently always empty — that's the whole mystery).

### Current diagnostic-mode code state (intentional, temporary)
`LiveActivityExt/TimeTrackerLiveActivityView.swift` currently has **stripped-down, bulletproof placeholder content** (plain `Text("W")` instead of real icons, no `AppIconView`) specifically to eliminate variables while debugging — **restore the real icon-rendering version once the extension is confirmed to render at all.** The pre-diagnostic version (with `AppIconView` reading stored PNG icons + letter-tile fallback) is recoverable from git history (commit `82768dd`, before this debugging arc started) if a clean restore is easier than re-editing.

---

## What shipped 2026-07-09 ("launch pass" — before the debugging arc above)

Spec/plan: `docs/superpowers/{specs,plans}/2026-07-09-launch-pass.md`.

- **Entitlements wired for real device**: `Wasted/Wasted.entitlements`, `DeviceActivityMonitorExt/DeviceActivityMonitorExt.entitlements`, `LiveActivityExt/LiveActivityExt.entitlements` — Family Controls + App Groups.
- **TrialClock** (`Wasted/Shared/TrialClock.swift`, both targets) — pure `state(firstLaunch:unlocked:now:)`, 7-day local trial. `UsageStore` gained `firstLaunchDate/stampFirstLaunchIfNeeded/isUnlocked/setUnlocked`.
- **StoreKit 2**: `Wasted/Monetization/LifetimeStore.swift` + `PaywallView.swift`. `.storekit` config at `Wasted/Wasted.storekit`, wired into the scheme.
- **Gating**: HomeView blurs+redacts and shows a frost overlay when trial `.expired`; extension skips Live Activity/nudge/receipt when expired but usage recording never stops.
- **Guess → Reality conversion moment**: `GuessView` onboarding screen (Hook → Guess → Differentiation → Permission → Picker → Notifications → Done), `RealityCheck.make(...)`, persistent reveal card on HomeView.
- **Correctness fixes**: HomeView refreshes on `scenePhase == .active` and receipt-sheet dismiss. `ReceiptScheduler` moved to `Wasted/Shared/`, also called from `WastedApp` on foreground.
- **Threshold list**: `1,2,3,4,5` then `10...120` by 5, `130...240` by 10, `255...480` by 15 (56 events/app) — confirmed firing correctly and recording usage all day (this part works great, independent of the Island bug).
- **Nudge notifications work correctly** — confirmed via real device screenshot, correct copy/timing, only cosmetic issue is the app-name gap (see below).
- **Legibility pass**: several cards had 7-9pt text at 0.18-0.28 opacity (below Apple HIG minimums) — raised across `DangerZonesCard`, `WeeklyCard`, `HeatmapView`, `HomeView`, `ReceiptView`.
- **App icon**: generated programmatically (Python/Pillow + NewYorkItalic.ttf) — serif italic "W" — light/dark/tinted variants in `AppIcon.appiconset`.
- **Widget source rewritten** (`WastedWidget/WastedWidget.swift`) — ready to drop into a target once created via Xcode GUI (not yet done, and now lower priority than fixing the Live Activity rendering bug, since they share the same underlying WidgetKit rendering pipeline — worth testing whether *that* extension renders once created, as another data point on whether this is systemic).

## Known cosmetic gap (unrelated to the Island bug, low priority)
`token.localizedDisplayName` returns `nil` on this device — display names show as generic "App 0"/"App 1" instead of "Instagram" (confirmed via a real notification screenshot: "30m on App 1"). This is a deliberate FamilyControls privacy boundary (confirmed: the codebase's own git history shows an abandoned attempt to Mirror-extract the name from `Label(token)`, which Apple defeats by using an opaque private view type). Fixed nudge notification copy to drop the app-name reference entirely (`NudgeCopy.title(minutes:)` no longer takes an `appName` param) rather than show a broken-looking placeholder. The *real* name can still only be shown via the system's own `Label(token)` view rendered live in SwiftUI (main app or widget extension context) — not extractable as a String for use in notifications, receipts, etc.

## Key gotchas (cumulative)

- **`Activity.request()` is main-app-only. Never call it from `DeviceActivityMonitorExt`.**
- **Live Activities need `.activityBackgroundTint()`/`.activitySystemActionForegroundColor()`, not a plain `.background()` modifier** for the lock-screen presentation specifically.
- **Check for the Debug-as-dylib trap** on any Debug-config iOS extension target: `ENABLE_DEBUG_DYLIB = NO;` is now set at the project level — if it ever gets removed/overridden, extension binaries silently become empty stubs. Verify with `strings`/`nm` on the built `.appex` binary if anything "shouldn't be possible" happens again.
- **`NSSupportsLiveActivities`** must be `YES` on the **main app's** Info.plist (`INFOPLIST_KEY_NSSupportsLiveActivities` build setting).
- `ApplicationToken`-derived display names/icons are unreliable (`nil` on this device) — design around it (generic copy, letter-tile fallback), don't try to force it.
- **Synchronized-group target membership:** shared files used by extensions must be listed in each target's `membershipExceptions` in `project.pbxproj` (`Nudges.swift`, `DailyReceipt.swift`, `ReceiptScheduler.swift`, `TrialClock.swift`, `LiveActivityManager.swift`, `TimeTrackerAttributes.swift`, `AppGroupKeys.swift`, etc.) — a missed entry fails with "cannot find type …".
- Big chained functional expressions (`.filter/.map/.sorted` chains) can hit "unable to type-check in reasonable time" in extension targets — write loops instead.
- `LifetimeStore`/`PaywallView` need `import StoreKit`; `LifetimeStore` also needs explicit `import Combine`.
- `#if targetEnvironment(simulator)` bypasses onboarding *and* forces `.unlocked` trial state — **the simulator cannot exercise ActivityKit/DeviceActivity at all**, every bug in this whole saga was only discoverable on a real device.
- **Device connectivity**: `available (paired)` instead of `connected` in `devicectl list devices` usually just means the phone is locked — but builds/installs can still often succeed anyway; don't block on this status alone.
- `scenePhase == .active` can fire more than once per cold launch — any one-time-per-launch side effect needs an explicit guard (see `Self.hasAttemptedLiveActivityThisLaunch` pattern in `WastedApp.swift`), not just a `guard phase == .active` check.

## What's next
1. **Resolve the Dynamic Island rendering bug** — see "START HERE" above. This blocks everything else Live-Activity-related.
2. Once resolved: remove both temporary diagnostic log mechanisms, restore real icon rendering in `TimeTrackerLiveActivityView.swift`.
3. Test whether the *extension's* `.update()` calls (on an activity the main app created) work in near-real-time, or whether the Island only refreshes on next app foreground — determines real product behavior, document whichever it is.
4. **Widget target**: File → New → Target → Widget Extension (`WastedWidgets`), embed in Wasted, App Group entitlement, add `AppGroupKeys/DailyUsage/UsageStore/HourlyUsage/TrialClock` to its membership — source ready in `WastedWidget/`. Consider doing this *before* fully resolving #1, actually — a fresh, from-scratch widget extension target might render fine even if `LiveActivityExtExtension` doesn't, which would be a hugely useful data point (points to something broken in that specific target vs. something systemic to this project/device).
5. **App Store groundwork**: create the ASC app record, **submit the Family Controls distribution entitlement request immediately** (days-to-weeks turnaround — the actual launch long pole), enroll in Small Business Program, create the $9.99 IAP in ASC, privacy policy + store copy.

**How to apply:** Read the whole "START HERE" section before writing any code. Try the Xcode-attached-session test first. Don't re-verify anything in the "ruled out" list — all of it has concrete evidence already gathered.

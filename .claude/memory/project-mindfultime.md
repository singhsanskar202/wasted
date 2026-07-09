---
name: project-wasted
description: Wasted — iOS screen time awareness app. Dynamic Island rendering bug SOLVED 2026-07-09 (stale local-fallback provisioning profile). Live Activity lifecycle redesigned: one persistent daily activity, adaptive tick cap, real app names via Label(token). Next: device verification of app names, then App Store groundwork.
metadata:
  node_type: memory
  type: project
  originSessionId: 329444d4-ba54-4700-8297-c235c24e4d9a
---

**Wasted** is an iOS app (iPhone 14 Pro+, iOS 17+) that tracks per-app screen time, shows a live ticking counter in the Dynamic Island, and confronts the user with blunt usage data. It is a **mirror, not a blocker** — never blocks/locks, no streak guilt, no ads.

**Positioning:** "you can ignore a blocker. you can't unsee a number." Free 7-day trial → **$9.99 one-time lifetime unlock, no subscription**.

**GitHub:** https://github.com/singhsanskar202/wasted (branch `fable/mirror-polish`)
**Local project:** `/Users/sanskarsingh/Documents/wasted/Wasted/`
**Device under test:** "Sanskar's iphone", iPhone 15, iOS 26.5 (build 23F77), devicectl id `9B8A2D59-C282-5C05-A501-51C47D3C724E`, UDID `00008120-001E19A93C12601E`.

---

## ✅ SOLVED 2026-07-09: the Dynamic Island rendering bug

**Root cause:** the LiveActivityExt extension was signed with a **locally-generated fallback provisioning profile** (`LocalProvision = true`, 7-day expiry) instead of a portal-issued team profile — Xcode silently fell back on 2026-07-06 when a portal request failed, then kept reusing the cached local profile. iOS launches the *main app* fine with such a profile (Xcode/devicectl installs bypass trust), but refuses to autonomously spawn *extensions* signed by it: amfid rejects with `0xe8008025 "The user did not explicitly trust the provisioning profile"` → launchd `EBADEXEC (85)` → chronod logs "Ignoring restricted or unknown extension". Main app + DeviceActivityMonitorExt had real portal profiles (1-year), which is why only the widget extension was dead.

**Fix:** delete the cached local profile from `~/Library/Developer/Xcode/UserData/Provisioning Profiles/` and rebuild with `-allowProvisioningUpdates` → fresh portal profile minted. **Diagnostic that cracked it:** live device syslog via `pymobiledevice3 syslog live` (installed via pip, needs USB) captured during install+spawn, then grep `amfid|chronod|runningboardd`. A temporary home-screen widget in the same bundle was the decisive registration test (since removed).

**Check the profile kind whenever extensions misbehave:**
```bash
security cms -D -i "<appex>/embedded.mobileprovision" | grep -c LocalProvision  # 1 = local fallback = bad
security cms -D -i "<appex>/embedded.mobileprovision" | plutil -extract ExpirationDate raw -o - -  # ~7 days = bad
```

## Live Activity lifecycle design (implemented 2026-07-09, after the signing fix)

- **One persistent daily activity, updated in place.** `Activity.request()` is main-app-only; the old "end other app's activity + request new" stranded the DeviceActivityMonitor extension on the request path (`unsupportedTarget`) and killed the Island. Now: current app lives in **ContentState** (`appBundleId`, `appName`), attributes only carry `day`. `LiveActivityManager.startOrUpdate(bundleId:appName:totalSeconds:isLive:)` always updates the first existing activity regardless of app.
- **Main app** starts/refreshes the activity on foreground (`isLive: false` → static exact total; being in Wasted ≠ being in a tracked app), even with 0 usage (only chance to create it for the day). Once-per-process guard on scenePhase.
- **Extension** updates on every threshold (`isLive: true` → ticking).
- **Ticking:** `Text(timerInterval:countsDown:false)` — NOT `Text(_:style:.timer)`, which freezes intermittently in Live Activities AND greedily stretches the compact island to full width (fixed-width `.frame` on compact slots too; verified pill 211pt vs 122pt idle housing via sim screenshot measurements).
- **Adaptive tick cap:** no "user left the app" event exists, so the timer interval's upper bound = last confirmed total + current threshold band gap + 120s margin (`capSeconds` in ContentState). Timer physically stops there (verified in sim: froze exactly at interval end). `context.isStale` re-renders proved **unreliable in sim** — never rely on staleness alone to stop a timer; it's only used to dim.
- **Thresholds** (ActivityScheduler bands, mirrored in `LiveActivityManager.thresholdGapSeconds`): 1-5m by 1, 10-120 by 5, 130-240 by 10, 255-480 by 15.
- **Real app names in the Island:** `token.localizedDisplayName` is nil (FamilyControls privacy) — the ONLY way to show real names is Apple's `Label(token)` view. ActivityScheduler persists `[index: ApplicationToken]` JSON to App Group (`AppGroupKeys.appTokensKey`); LiveActivityExt (now has the `com.apple.developer.family-controls` entitlement) renders `Label(token).labelStyle(.titleOnly)` with fallback to stored "App N" name. `WastedApp.backfillTokensIfNeeded()` re-runs startMonitoring once for pre-token installs — the index↔token mapping MUST be built in the same startMonitoring call as the events (Set ordering isn't stable across calls).
- **NOT yet user-verified on device:** Label(token) actually rendering real names inside the Live Activity (entitlement + portal profile confirmed present in build).

## What shipped earlier 2026-07-09 ("launch pass")

Spec/plan: `docs/superpowers/{specs,plans}/2026-07-09-launch-pass.md`. TrialClock 7-day local trial; StoreKit 2 lifetime IAP (`LifetimeStore`/`PaywallView`, `.storekit` config); HomeView trial gating (blur+frost when expired, recording never stops); Guess→Reality onboarding conversion moment; legibility pass; programmatic serif-italic "W" app icon; `WastedWidget/WastedWidget.swift` source ready but target not yet created.

## Key gotchas (cumulative)

- **`Activity.request()` is main-app-only. Never call it from `DeviceActivityMonitorExt`.** Extensions can `.update()` and `.end()` an existing activity.
- **`Text(_:style:.timer)` is broken in Live Activities** (freezes + stretches compact island). Use `Text(timerInterval:countsDown:)` with a bounded interval + fixed-width frame in compact slots.
- **`context.isStale` re-render is unreliable** — bound timers by interval end, don't rely on staleness.
- Live Activities need `.activityBackgroundTint()`/`.activitySystemActionForegroundColor()`, not `.background()`.
- **`ENABLE_DEBUG_DYLIB = NO;`** set project-wide — if removed, Debug extension binaries become empty Previews stubs (verify with `strings` on the built appex).
- **`NSSupportsLiveActivities`** = YES on main app Info.plist AND extension Info.plist.
- **Local-fallback provisioning profiles** (see SOLVED section) — check `LocalProvision` key when an extension won't spawn but the app runs.
- `Label(token)` is the only way to show FamilyControls app names; requires family-controls entitlement in the rendering target. Names are never available as String.
- **Synchronized-group membership:** shared files used by extensions must be in each target's `membershipExceptions` in project.pbxproj.
- `#if targetEnvironment(simulator)` no longer excludes the Live Activity start path — ActivityKit WORKS in the simulator (iPhone 17 Pro sim used for island screenshots via `simctl io screenshot`); DeviceActivity does not.
- Device syslog capture: `pip install pymobiledevice3` → `python3 -m pymobiledevice3 syslog live` (USB only — check `usbmux list` returns non-empty; devicectl silently works over Wi-Fi, hiding that USB isn't connected).
- User's zsh profile shadows `log` — use `/usr/bin/log` explicitly.
- `scenePhase == .active` can fire multiple times per cold launch — guard one-time side effects.
- Big `.filter/.map` chains can fail type-check in extension targets — write loops.
- `token.localizedDisplayName` nil on-device → generic "App N" anywhere a String is required (notifications, receipts); design copy around it.

## What's next
1. **User-verify real app names** render in the island (Label(token) path) — first thing next session if not confirmed.
2. Widget target (`WastedWidgets`) via Xcode GUI — source ready in `WastedWidget/`.
3. **App Store groundwork**: ASC app record, **Family Controls distribution entitlement request (long pole — submit ASAP)**, Small Business Program, $9.99 IAP, privacy policy + store copy.

**How to apply:** trust the SOLVED section — don't re-debug signing. When touching Live Activity code, preserve the single-persistent-activity invariant and the bounded-timer pattern.

---
name: project-wasted
description: Wasted — iOS screen time awareness app showing live per-app timer in Dynamic Island with hourly nudge notifications. Fully built, 16 tests pass, pushed to GitHub.
metadata: 
  node_type: memory
  type: project
  originSessionId: 329444d4-ba54-4700-8297-c235c24e4d9a
---

**Wasted** is an iOS app (iPhone 14 Pro+, iOS 17+) that automatically tracks how long the user spends in each app and shows a live ticking counter in the Dynamic Island. Hourly milestone notifications fire with blunt, guilt-inducing copy. The main app screen shows a rotating confrontational quote and app toggles — no dashboard, no history.

**Why:** User wants a digital wellbeing awareness tool for personal use, then TestFlight friends, then App Store.

**GitHub:** https://github.com/singhsanskar202/wasted

**Local project:** `/Users/sanskarsingh/Documents/wasted/Wasted/`

**Spec:** `docs/superpowers/specs/2026-05-25-app-time-tracker-design.md` (in MindfulTime repo)

**Plan:** `docs/superpowers/plans/2026-05-25-mindfultime-ios.md` (in MindfulTime repo)

**Current state (as of 2026-05-26):** Fully implemented. Build succeeds on iOS 26.5 simulator. 16/16 unit tests pass. Pushed to GitHub.

**Architecture:** 4 Xcode targets:
- `Wasted` (main app): Onboarding (3 screens), HomeView (quote + toggles), ActivityScheduler
- `DeviceActivityMonitorExt`: DeviceActivityMonitorExtension, LiveActivityManager, NotificationScheduler
- `LiveActivityExt`: Widget extension rendering Dynamic Island (compact/expanded/minimal)
- `WastedTests`: 16 unit tests (DailyUsage x4, UsageStore x6, TimeTrackerAttributes x2, QuoteBank x3, template x1)

**Key identifiers:**
- Bundle ID: `com.sanskar.Wasted`
- App Group: `group.com.sanskar.Wasted`
- Team ID: `ZZZ87SSQ8S` (free personal account)
- Dev deployment target: iOS 26.5

**What's blocked until paid Apple Developer account ($99):**
- Family Controls entitlement → needed for DeviceActivity tracking
- App Groups on device → needed for inter-extension data sharing
- Testing real Dynamic Island on device

**Workaround in place:** `#if targetEnvironment(simulator)` in WastedApp.swift bypasses onboarding and shows HomeView directly on simulator.

**Technical notes:**
- `ApplicationToken.bundleIdentifier` is private — event names use index format `"0:60"` (appIndex:minutes)
- `Application.token` is `ApplicationToken?` (optional) — guard-unwrap before use in DeviceActivityEvent
- `accumulatedStart = Date() - totalSeconds` trick makes SwiftUI `.timer` style tick live
- `PBXFileSystemSynchronizedBuildFileExceptionSet` for the owning target = EXCLUSION (removed this to fix AppGroupKeys scope error)
- `import ManagedSettings` required for `localizedDisplayName` on Application tokens
- `CODE_SIGNING_REQUIRED = NO` set on DeviceActivityMonitorExt to bypass provisioning on free account

**How to apply:** When user asks about Wasted, this is the complete picture. Next steps when they get a paid account: register App Group, request Family Controls entitlement, remove simulator bypass, test on physical iPhone 14 Pro+.

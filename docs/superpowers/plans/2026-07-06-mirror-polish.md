# Mirror Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Differentiation onboarding screen, haptics + §2 visual pass, 30-minute nudges, daily receipt (notification + in-app), peak-hour history insight. Spec: `docs/superpowers/specs/2026-07-06-mirror-polish.md`.

**Architecture:** All new decision logic is pure and shared (`Nudges.swift`, `DailyReceipt.swift`, `InsightEngine.historicalPeak`) so it's unit-testable and usable from both the app and the DeviceActivityMonitor extension. UI work (DifferentiationView, ReceiptView, palette pass) is manually verified via Canvas, same convention as the Dynamic Island work.

**Tech stack:** Swift, SwiftUI, DeviceActivity, UserNotifications, XCTest.

---

### Task 1: Theme + Haptics foundation

**Files:** create `Wasted/Theme.swift`; modify `Wasted/Shared/Models/AppGroupKeys.swift`, `WastedTests/Models/AppGroupKeysTests.swift`

- [x] Add `Color.canvas / .ink / .inkFaint / .alarm` and `Haptics` enum (light/medium/heavy/selection/success/warning) in `Theme.swift`
- [x] `AppGroupKeys`: add `awakeDayHours = 16`, `receiptHour = 21`, `nudgeRecordsKey`; add `formattedDuration(_ seconds:)` and refactor `formattedTime` onto it; delete dead `hourlyUsageKey` helpers
- [x] Extend `AppGroupKeysTests` with `formattedDuration` cases (0, 42m, 1h 0m, 1h 24m, negative clamps to 0m)

### Task 2: Differentiation screen + onboarding re-sequence

**Files:** create `Wasted/Onboarding/DifferentiationView.swift`; modify `OnboardingContainerView.swift`, `NotificationPermissionView.swift`

- [x] `DifferentiationView` — headline `this won't\nblock anything.`, body per spec, `understood` button
- [x] Re-sequence container: Hook → Differentiation → Permission → AppPicker → Notification → Done (picker needs FamilyControls auth first — documented platform constraint)
- [x] NotificationPermissionView: keep first two blocks, replace rest with the 30-min-nudge + receipt why; adjust stagger delays
- [x] Self-critique pass: cut anything that doesn't serve the screen

### Task 3: Haptics + §2 visual pass

**Files:** modify all onboarding views, `HomeView.swift`, `HeatmapView.swift`, `DangerZonesCard.swift`, `WeeklyCard.swift`

- [x] Wire haptics exactly per the brief's table (hook/differentiation advance = light; picker selection = selection; i'm ready = medium; ST granted = success / denied = warning + fallback subtitle; notif granted/denied = success/warning; Done entrance = heavy)
- [x] Palette sweep: `Color.black` → `.canvas`, `.white` → `.ink` on onboarding + Home; cards swap private red for `.alarm`
- [x] HomeView big number → serif; equivalent line → serif faint ink, drop emoji + orange; heatmap peak → `.alarm` only when peak hour ≥1h
- [x] Reduced-motion: entrance animations collapse to immediate visibility when `accessibilityReduceMotion` is set
- [x] Self-critique pass on each touched screen

### Task 4: 30-minute nudges

**Files:** create `Wasted/Shared/Nudges.swift`, `WastedTests/Notifications/NudgeTests.swift`; modify `UsageStore.swift`, `NotificationScheduler.swift`, `DeviceActivityMonitorExtension.swift`, `project.pbxproj`

- [x] `Nudges.swift`: `NudgeRecord`, `NudgeGate.shouldNudge` (30-multiple, > last minutes today, ≥10 min gap), `NudgeCopy` (title + 6 bodies per spec)
- [x] `UsageStore.lastNudge(for:)` / `recordNudge(minutes:for:)` under `nudgeRecordsKey`
- [x] Rewrite `NotificationScheduler` → `scheduleNudge(appName:minutes:)` on NudgeCopy; delete old hourly copy bank
- [x] Extension: replace `minutes % 60` branch with gate + record
- [x] pbxproj: add `Shared/Nudges.swift` to DeviceActivityMonitorExt membershipExceptions
- [x] Tests: gate (non-multiple / first / lower / stale-day / burst-gap), copy formatting, store round-trip

### Task 5: Daily receipt

**Files:** create `Wasted/Shared/DailyReceipt.swift`, `Wasted/Receipt/ReceiptView.swift`, `DeviceActivityMonitorExt/ReceiptScheduler.swift`, `WastedTests/Receipt/DailyReceiptTests.swift`; modify `DeviceActivityMonitorExtension.swift`, `HomeView.swift`, `project.pbxproj`

- [x] `DailyReceipt.build` — items sorted desc, names via displayNames (fallback "app N"), percent of 16h awake day, `summaryLine`
- [x] `ReceiptScheduler.refresh` — replaceable `wasted.receipt` calendar notification at 21:00, skipped when past or zero usage; called from `eventDidReachThreshold`
- [x] `ReceiptView` — receipt-printer layout per spec; empty state `nothing yet.`
- [x] HomeView: `today's receipt` row → sheet, light haptic on open
- [x] pbxproj: add `Shared/DailyReceipt.swift` to ext membershipExceptions
- [x] Tests: percent math (11 520s → 20%), sorting, name fallback, summary line, zero day
- [x] Self-critique pass on ReceiptView

### Task 6: Peak-hour history insight

**Files:** modify `InsightEngine.swift`, `HomeView.swift`; create `WastedTests/Insights/HistoricalPeakTests.swift`

- [x] `historicalPeak(history:)` — nil under 3 days or zero usage; best 2-hour window by summed seconds; daysActive count
- [x] HomeView: serif mirror line + day-count subline, shown when non-nil
- [x] Tests: gating, window choice, tie behavior, day counting

### Task 7: Cleanup, build, memory

- [x] Delete `ContentView.swift`, `AppGridView.swift` (unreferenced)
- [x] `xcodebuild -scheme Wasted test` — full suite green (was 37 tests; now 37 + new)
- [x] Update `.claude/memory/project-mindfultime.md` with what shipped + what's next

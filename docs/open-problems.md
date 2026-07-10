# Wasted — open problems & enhancements

Status as of 2026-07-10. Device under test: iPhone 15, iOS 26.5,
devicectl id `9B8A2D59-C282-5C05-A501-51C47D3C724E`. Branch `fable/mirror-polish`.
Full technical context: `.claude/memory/project-mindfultime.md`.

---

## Critical / blocking

### P1 — Live Activity timer does not update in real time
**Symptom:** the Dynamic Island total freezes at whatever value the main app
last wrote; it only changes when Wasted is foregrounded, never while the user
is inside a tracked app.

**Root cause (confirmed from on-device logs):** the `DeviceActivityMonitor`
extension runs in a *separate process*, and `Activity<TimeTrackerAttributes>.activities`
is **empty** there — so the extension has no handle to the activity the main
app created and every threshold-time `update()` is a no-op. Device log shows
`ext update called ... activities=0` → `NO activity to update`, while usage is
still recorded correctly.

**Tried:** blocking the extension callback on a semaphore (updates still had
nothing to update); a poll/retry that waits for `.activities` to sync in the
freshly-spawned extension process. **2026-07-10 (in working tree, needs
deploy + device test):** the retry was hardened — the blocking LA update is now
the LAST step of `eventDidReachThreshold` (so a long wait can never starve the
nudge/receipt/badge/widget work), which made it safe to widen the poll from
~2.4s to ~5s (10 × 500ms); the `debug_la` log now records `waited=<ms>`.
Test protocol: use a tracked app ~5 min, pull `debug_la`. If it logs
`NO activity after wait` with `waited≈5000ms`, treat `.activities` as **never**
syncing in this extension, not merely slow — see below.

**2026-07-10 research — recommendation if the retry fails:**

- **Why the retry may be doomed:** `Activity.activities` appears to be
  per-process/per-bundle, not merely slow to sync. The one documented case of
  an extension seeing an empty `activities` array (widget-interaction
  AppIntents, [forum thread 735382](https://developer.apple.com/forums/thread/735382))
  was fixed by making the system run the intent *in the app's process* — a
  lever that does not exist for `DeviceActivityMonitor`, whose callbacks always
  run in the extension process.
- **ActivityKit push is NOT feasible for this app — do not build push infra.**
  Every remote path — `pushType: .token` updates, push-to-start (iOS 17.2+),
  broadcast channels (iOS 18+) — requires the update to arrive *through APNs
  from a server* ([Apple: Starting and updating Live Activities with
  ActivityKit push notifications](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications)).
  Two architectural blockers, stronger than "needs a server":
  1. The DeviceActivityMonitor extension — the only component that knows a
     threshold fired — is sandboxed **without network access** (privacy: usage
     data must not leave the extension; see the Screen Time API series,
     [part 3](https://letvar.medium.com/time-after-screen-time-part-3-the-device-activity-monitor-extension-284da931391b)).
     It cannot call a server to trigger the push.
  2. An APNs Live Activity push must carry the full `content-state` — i.e. the
     new total — which only exists in the App Group on the device. A server
     (or OneSignal/Firebase relay) can never know the number to push.
  So push updates are a dead end for usage-driven content, full stop.
- **Recommended fallback (no server, honest):** keep the current design and
  close the gap opportunistically:
  1. The island already *self-ticks* via `Text(timerInterval:)` up to
     `capSeconds` — between-threshold liveness is real even with zero
     extension updates.
  2. Add a `BGAppRefreshTask` in the **main app** (its process CAN update the
     activity) that re-reads the App Group total and calls
     `startOrUpdate(isLive: false)` — a few opportunistic re-anchors per day
     at iOS's discretion, plus the existing exact update on every foreground.
  3. Product framing stays as designed: ticking while plausibly in a tracked
     app, frozen/dimmed (staleDate) once unconfirmed, exact on app open.

**Do not remove the `debug_la` diagnostics until this is resolved.**

---

## Bugs

### P2 — Danger-zones card repeats the same apps across zones — FIXED 2026-07-10 (code)
Was: `InsightEngine.topAppIndices` attached the **day's** top apps to *every*
zone (we only store per-hour totals, not per-app-per-hour), so the same names
repeated down the card. Fix = option (a): `DangerZone.appIndices` removed;
`InsightResult` now carries day-level `topAppIndices` and `DangerZonesCard`
shows one "TOP APPS" summary row (with icons, see E1) under the zone list.
Builds + unit tests pass; visual check on device still pending. Real per-zone
attribution would need per-app-per-hour tracking in `UsageStore` (not planned).

### P3 — Verify receipt row layout
The receipt now renders real names via `TrackedAppLabel`
(`.fixedSize(horizontal: false, vertical: true)` to tame `Label(token)`'s greedy
height). Confirm on device that rows are compact AND names are full-width
(earlier attempts either over-spaced the rows or truncated "Instagram" → "Ir").
2026-07-10: receipt rows now also show the real icon (E1) — same visual check
covers icon sizing.

---

## Cleanup (after P1 resolves)

### P4 — Remove diagnostics
`LiveActivityManager.log(...)` + the `debug_la` App Group key, and any leftover
`debug_render_log` / `debug_live_activity_log` values. Keep until the timer is
proven.

### P5 — Extension entitlement no longer used
`LiveActivityExt` still requests `com.apple.developer.family-controls` (added for
the abandoned in-island `Label(token)` approach; the island now shows a name-free
total). Removing it is cleaner but re-provisions the extension — do it carefully
given the earlier local-fallback-profile battle (see memory), and verify the
built `.appex` still gets a portal profile (`LocalProvision` absent).

---

## Enhancements

### E1 — App icons beside names (in-app screens) — IMPLEMENTED 2026-07-10
`TrackedAppLabel` gained `showsIcon: Bool` (system `.titleAndIcon` label style,
same `.fixedSize(horizontal: false, vertical: true)` guard). Enabled in the
receipt rows and the new danger-zones "TOP APPS" row. Compiles; **needs a
device look** — icon size/alignment next to the receipt's 15pt light text may
want tuning (a custom `LabelStyle` constraining `configuration.icon` is the
lever if so). Icons still do **not** work in the Live Activity or via
`ImageRenderer` (redaction placeholder) — in-app SwiftUI only.

### E2 — Home-screen widget target
`WastedWidget/WastedWidget.swift` source is ready but the `WastedWidgets` target
isn't created yet (File → New → Target → Widget Extension; App Group + shared
files). Shares the WidgetKit pipeline, so worth doing after P1.

### E3 — App Store groundwork
Create the ASC record; **submit the Family Controls distribution entitlement
request ASAP** (days-to-weeks turnaround — the real launch long pole); Small
Business Program; $9.99 lifetime IAP; privacy policy + store copy.

---

## Known hard limits (not fixable — documented so nobody re-tries)

- **App name/icon in the Dynamic Island / Live Activity is impossible.**
  `localizedDisplayName` is nil; `Label(token)` renders a redaction placeholder
  anywhere it's rasterized or hosted by a system process (the Live Activity
  renderer). The island therefore shows a **name-free total** by design. Real
  names DO work in the app's own foreground screens (see E1) — that distinction
  is the whole trick.
- **No "app closed" event exists in Screen Time.** The island can't vanish the
  instant a tracked app is closed; it's a persistent daily counter (the user
  agreed this is desirable as a constant reminder) that freezes/dims when usage
  stops and clears at midnight.
- **Usage is only reported at threshold crossings.** Both the island and the
  in-app total step at thresholds; there is no per-second truth from iOS.

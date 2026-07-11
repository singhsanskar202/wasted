# Wasted Implementation Guide

## Development philosophy

**Do one thing well.** Each file, class, and function has a single responsibility. The architecture is layered—models don't import views, storage doesn't import UI, extensions don't import the main app. This isolation makes testing possible and bugs localized.

**Prefer simple over clever.** A loop is clearer than a chained functional expression. Explicit state transitions beat implicit state machines. When in doubt, write the straightforward version first.

**No premature abstraction.** If three similar lines exist, leave them. If they drift into five, consolidate then. Three is pattern-seeking; five is waste.

**Trust the frameworks.** SwiftUI's `@State`, `@Environment`, and `@Published` work. ActivityKit's timer works. Family Controls works. Don't layer your own state machine on top unless the framework provably fails.

---

## Code style & conventions

### Naming

- **Classes:** PascalCase, full words (`HomeView`, `UsageStore`, `HistoricalPeak`)
- **Functions & properties:** camelCase, start with verb if they perform an action (`refresh()`, `loadTodayUsage()`, `formattedDuration(...)`)
- **Constants:** `camelCase`, grouped in `enum` namespaces (e.g., `AppGroupKeys`, `NudgeGate`)
- **Computed properties:** read-only, no side effects; use sparingly (prefer methods if logic is complex)
- **Private helpers:** prefix with `private func`; no underscore prefix

### Imports

- Alphabetical within each group (Frameworks, then project imports)
- No unused imports
- Example:
  ```swift
  import ActivityKit
  import Charts
  import Combine
  import FamilyControls
  import StoreKit
  import SwiftUI

  import Wasted   // never
  ```

### Formatting

- Indentation: 4 spaces (Xcode default)
- Line length: soft limit 100 chars, hard limit 120 (break long lines at logical points)
- Blocks: opening brace on same line, closing brace on its own line (K&R style)
- Spacing: one blank line between methods, two between major sections

Example:
```swift
final class UsageStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: AppGroupKeys.appGroupID) ?? .standard) {
        self.defaults = defaults
    }

    // MARK: - Loading

    func loadTodayUsage() -> DailyUsage {
        guard let data = defaults.data(forKey: AppGroupKeys.dailyUsageKey),
              let usage = try? JSONDecoder().decode(DailyUsage.self, from: data)
        else { return DailyUsage() }
        return usage
    }
}
```

### Comments

**Write no comments.** If the code's intent is non-obvious, the code should be clearer, not commented. The exception: constraints that are not obvious from the code alone.

Examples of acceptable comments:
- Workarounds for OS bugs: `// iOS 17.2 bug: activity doesn't update from extension`
- Performance notes: `// This runs on every foreground; keep it O(n) not O(n²)`
- Platform constraints: `// Activity.request() only works from main app target`
- Hidden assumptions: `// dateComponents ignores seconds; pass calibrated to minute`

Do not write comments like:
- `// load today's usage` (the function name says this)
- `// increment counter` (what the line does is obvious)
- `// used by HomeView` (belongs in git history/PR, not the source)

---

## SwiftUI patterns

### View composition

Keep views small. A 200-line view is a sign of missing extraction.

```swift
// Bad: HomeView is 500 lines
struct HomeView: View {
    var body: some View {
        VStack {
            // Quote
            // Big number
            // Receipt
            // Heatmap
            // Weekly
            // Insights
        }
    }
}

// Good: extracted into subviews
struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                QuoteSection()
                BigNumberSection(totalSeconds: totalSeconds)
                if let receipt = todayReceipt {
                    ReceiptRow(receipt: receipt)
                }
                HeatmapView(data: heatmap)
                WeeklyCard(days: history)
                InsightSection(engine: engine)
            }
        }
    }
}
```

### State management

**Global state:** `@Published` properties on ObservableObject singletons (e.g., `LifetimeStore.shared`).

```swift
@MainActor
final class LifetimeStore: ObservableObject {
    static let shared = LifetimeStore()
    @Published var isUnlocked = false
    @Published var product: Product?
    
    private init() { }
}
```

**Local state:** `@State` for transient UI state (sheet presentation, selection, animation flags).

```swift
struct HomeView: View {
    @State private var showingReceipt = false
    @State private var showingPaywall = false
    
    var body: some View {
        Button("today's receipt") {
            showingReceipt = true
        }
        .sheet(isPresented: $showingReceipt) {
            ReceiptView()
        }
    }
}
```

**Injected dependencies:** pass as parameters for testability.

```swift
struct HomeView: View {
    let store: UsageStore  // injected, defaults to a shared instance
    
    init(store: UsageStore = UsageStore()) {
        self.store = store
    }
}
```

### Reactive updates

HomeView polls `UsageStore` on a timer and responds to app state changes:

```swift
struct HomeView: View {
    @State private var totalSeconds = UsageStore().totalSecondsAllApps()
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Text(AppGroupKeys.formattedDuration(totalSeconds))
            .onReceive(refreshTimer) { _ in
                totalSeconds = UsageStore().totalSecondsAllApps()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    totalSeconds = UsageStore().totalSecondsAllApps()
                }
            }
    }
}
```

Do not use `@StateObject` for data queries—they're best reserved for complex long-lived objects (like `ActivityScheduler`, which holds state across navigation). For passive data reads, poll via timer or `onReceive`.

### Animations

Use the design system's animations (Theme.swift). Respect `accessibilityReduceMotion`:

```swift
Text("total")
    .font(.system(size: 68, weight: .bold, design: .serif))
    .opacity(appeared ? 1 : 0)
    .scaleEffect(appeared || reduceMotion ? 1 : 0.85)
    .animation(
        reduceMotion ? nil : .spring(duration: 0.6, bounce: 0.3).delay(0.1),
        value: appeared
    )
```

---

## Data storage patterns

### App Group UserDefaults

All persisted state lives in `UserDefaults(suiteName: AppGroupKeys.appGroupID)`. Never use the main app's default `UserDefaults()`.

```swift
final class UsageStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: AppGroupKeys.appGroupID) ?? .standard) {
        self.defaults = defaults
    }

    func saveUsage(_ usage: DailyUsage) {
        guard let encoded = try? JSONEncoder().encode(usage) else { return }
        defaults.set(encoded, forKey: AppGroupKeys.dailyUsageKey)
    }
}
```

Inject `UserDefaults` in tests:

```swift
func testLoadUsage() {
    let mock = UserDefaults(suiteName: "test.suite")!
    mock.set(try? JSONEncoder().encode(DailyUsage()), forKey: AppGroupKeys.dailyUsageKey)
    
    let store = UsageStore(defaults: mock)
    let loaded = store.loadTodayUsage()
    XCTAssertEqual(loaded, expected)
}
```

### Codable models

All data models conform to `Codable` for serialization:

```swift
struct DailyUsage: Codable, Equatable {
    let dateString: String
    var appUsage: [Int: Int]  // app index → seconds
    var hourly: [Int: Int] = [:]  // hour (0–23) → seconds
}
```

Use `JSONEncoder` / `JSONDecoder` for persistence:

```swift
let encoder = JSONEncoder()
if let encoded = try? encoder.encode(usage) {
    defaults.set(encoded, forKey: key)
}

if let data = defaults.data(forKey: key),
   let decoded = try? JSONDecoder().decode(DailyUsage.self, from: data) {
    return decoded
}
```

### Date handling

- Store dates as ISO 8601 strings for user defaults: `"2026-07-10"`
- Use `DateComponents` for calendar calculations
- Use `Date()` for time-based logic (elapsed, intervals)

```swift
// Bad: store a Date object
defaults.set(Date(), forKey: "date")

// Good: store an ISO string
let today = Calendar.current.component(.year, from: Date())  // ...
let dateString = "\(year)-\(month)-\(day)"
defaults.set(dateString, forKey: AppGroupKeys.firstLaunchKey)
```

---

## Testing patterns

### Unit tests

Every pure function gets XCTest coverage. Use `@testable import Wasted` to access internal types.

```swift
import XCTest
@testable import Wasted

final class InsightEngineTests: XCTestCase {
    func testHistoricalPeakWithInsufficientHistory() {
        let history = [DailyUsage(), DailyUsage()]  // 2 days, need 3+
        let peak = InsightEngine.historicalPeak(history: history)
        XCTAssertNil(peak)
    }

    func testHistoricalPeakSelectsCorrectWindow() {
        var day1 = DailyUsage()
        day1.hourly = [21: 1800, 22: 1800]  // 9–11 PM
        
        var day2 = DailyUsage()
        day2.hourly = [21: 2400, 22: 2400]  // 9–11 PM (heavier)
        
        let peak = InsightEngine.historicalPeak(history: [day1, day2, DailyUsage()])
        XCTAssertEqual(peak?.startHour, 21)
        XCTAssertEqual(peak?.daysActive, 2)
    }
}
```

### Testing App Group storage

Inject a test suite UserDefaults:

```swift
func testRoundTripUsage() {
    let testDefaults = UserDefaults(suiteName: "test.wasted.roundtrip")!
    testDefaults.removePersistentDomain(forName: "test.wasted.roundtrip")  // fresh
    
    let store = UsageStore(defaults: testDefaults)
    let original = DailyUsage()
    store.saveUsage(original)
    
    let loaded = store.loadTodayUsage()
    XCTAssertEqual(loaded, original)
}
```

### Testing async / StoreKit

StoreKit 2 transactions are difficult to unit-test. Test the caching logic instead:

```swift
func testTrialStateTransitionsFromExpiredToUnlocked() {
    let store = UsageStore(defaults: testDefaults)
    
    // Simulate expired trial
    let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
    store.stampFirstLaunch(eightDaysAgo)
    store.setUnlocked(false)
    
    var state = TrialClock.state(firstLaunch: store.firstLaunchDate(), unlocked: store.isUnlocked())
    XCTAssertEqual(state, .expired)
    
    // Simulate purchase
    store.setUnlocked(true)
    state = TrialClock.state(firstLaunch: store.firstLaunchDate(), unlocked: store.isUnlocked())
    XCTAssertEqual(state, .unlocked)
}
```

### Manual testing on device

Create a `#if DEBUG` section in the main app for QA:

```swift
#if DEBUG
struct HomeView: View {
    var body: some View {
        VStack {
            // ... normal home view ...
            if isDebug {
                DebugMenu()
            }
        }
    }
    
    @ViewBuilder
    private func DebugMenu() -> some View {
        VStack {
            Button("Back-date trial by 8 days") {
                let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
                UsageStore().stampFirstLaunch(eightDaysAgo)
            }
            Button("Show paywall") {
                showingPaywall = true
            }
            Button("Clear all data") {
                UserDefaults(suiteName: AppGroupKeys.appGroupID)?.removePersistentDomain(forName: AppGroupKeys.appGroupID)
            }
        }
        .padding()
        .background(Color.canvas)
    }
}
#endif
```

---

## Extension-specific patterns

### DeviceActivityMonitorExtension entry point

The extension receives events and processes them synchronously:

```swift
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent) {
        let store = UsageStore()
        
        // Parse the threshold name
        guard let name = event.eventName.rawValue as String? else { return }
        let parts = name.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        let (appIndex, minutes) = (parts[0], parts[1])
        
        // Record usage delta
        var usage = store.loadTodayUsage()
        let delta = store.deltaSeconds(for: appIndex)
        usage.appUsage[appIndex] = (usage.appUsage[appIndex] ?? 0) + delta
        store.saveUsage(usage)
        
        // Evaluate nudge gate and fire if eligible
        let displayName = displayName(for: appIndex)
        let nudgeRecord = store.lastNudge(for: appIndex)
        if NudgeGate.shouldNudge(minutes, nudgeRecord, today: dateString(), now: Date()) {
            NotificationScheduler().scheduleNudge(displayName, minutes)
            store.recordNudge(minutes, for: appIndex)
        }
        
        // Update live activity and widget
        ReceiptScheduler().refresh(usage: usage)
        Task {
            await LiveActivityManager().startOrUpdate(totalSeconds: totalSeconds())
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
```

### Avoiding type-check timeouts

The extension's type-checker is slow. Avoid chaining functional expressions:

```swift
// Bad: type-checker times out
let total = history
    .flatMap { $0.hourly.values }
    .reduce(0, +)

// Good: explicit loop
var total = 0
for day in history {
    for seconds in day.hourly.values {
        total += seconds
    }
}
```

### Membershipexceptions in pbxproj

Any file in `Wasted/Shared/` used by the extension must be listed in `membershipExceptions`:

```bash
grep -A 30 'Exceptions for "Wasted" folder in "DeviceActivityMonitorExt" target' Wasted.xcodeproj/project.pbxproj
```

If a file is missing, the extension build fails with "cannot find type". When adding a new shared file:

1. Create it in `Wasted/Shared/`
2. Add it to the Wasted target (File Inspector)
3. Edit `Wasted.xcodeproj/project.pbxproj` and add the file path to the `membershipExceptions` list under the DeviceActivityMonitorExt target section

---

## Theming & design compliance

### Using the color system

Always use the Theme colors, never hardcode hex:

```swift
// Bad
.foregroundStyle(Color(red: 0.96, green: 0.95, blue: 0.93))

// Good
.foregroundStyle(Color.ink)
```

If you need opacity:
```swift
.foregroundStyle(Color.ink.opacity(0.5))  // Use .inkFaint for common 50% opacity
.foregroundStyle(Color.alarm)              // Red only for bad numbers
```

### Using haptics

Import and call from `Theme.swift`:

```swift
import SwiftUI

struct Theme {
    enum Haptics {
        static func light() {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        static func selection() {
            UISelectionFeedbackGenerator().selectionChanged()
        }
        static func success() {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        static func warning() {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        static func heavy() {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}

// Usage
Button("Next") {
    Haptics.light()
    advance()
}
```

### Respecting reduced motion

Every animated entrance must check `accessibilityReduceMotion`:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

var body: some View {
    Text("content")
        .opacity(appeared ? 1 : 0)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.3),
            value: appeared
        )
        .onAppear { appeared = true }
}
```

---

## Performance guidelines

### Avoid expensive operations on main thread

UserDefaults reads/writes are cheap. JSON decode is cheap. Do not dispatch to background unnecessarily:

```swift
// OK: quick operation on main
let usage = store.loadTodayUsage()

// Unnecessary: this is fast
DispatchQueue.global().async {
    let usage = store.loadTodayUsage()  // don't do this
}
```

### Limit SwiftUI view re-renders

Keep `@State` small and localized. Don't make a single `@State` that the whole view depends on:

```swift
// Bad: totalSeconds change re-renders entire view
@State private var totalSeconds = 0
var body: some View {
    VStack {
        BigNumber(totalSeconds)
        ComplexChart()
        LongList()
    }
}

// Good: pass only what each subview needs
@State private var totalSeconds = 0
var body: some View {
    VStack {
        BigNumber(seconds: totalSeconds)
        ComplexChart()  // doesn't depend on totalSeconds
        LongList()      // doesn't depend on totalSeconds
    }
}
```

### Timer management

Timers hold a strong reference to the view. Use `autoconnect()` and rely on view lifecycle:

```swift
private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

var body: some View {
    Text("...")
        .onReceive(refreshTimer) { _ in
            refresh()
        }  // timer stops when view is deallocated
}
```

---

## Git & commit hygiene

### Commit messages

Follow Conventional Commits. Message format:

```
<type>(<scope>): <subject>

<body>

Co-Authored-By: Claude <noreply@anthropic.com>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `style`, `chore`

Examples:
```
feat(home): add historical peak insight

Shows users the 2-hour window where they lose the most time,
across the last 7 days. Displays once ≥3 days of history exist.

fix(nudges): respect 10-minute gap between 30-min step nudges

Previously, dense threshold events could fire two nudges within
seconds of each other. Now enforces minGap of 600s.

refactor(storage): extract formattedDuration to AppGroupKeys
```

### Before committing

1. Run tests: `xcodebuild -scheme Wasted test`
2. Check for unused imports
3. Verify no `print()` statements in production code
4. Ensure no hardcoded values (use `AppGroupKeys`, `Theme`)

---

## Debugging tips

### Live Activity not appearing

1. Verify `Activity.request()` succeeded (return value is not nil)
2. Check that `TimeTrackerAttributes` and `ContentState` are `Codable`
3. Confirm the activity's `day` matches today's date string
4. Verify the Live Activity entitlement is enabled in the scheme
5. Verify the `NSSupportsLiveActivities` Info.plist key is set

### Extension not receiving threshold events

1. Verify `familyActivityPicker` was completed (selection saved)
2. Verify `startMonitoring()` was called with the selection
3. Check that threshold events are registered (inspect DeviceActivityCenter)
4. Verify the extension's membershipExceptions include all shared files
5. Check extension logs: `log stream --predicate 'process == "com.sanskar.Wasted.DeviceActivityMonitorExt"'`

### Nudge not firing

1. Verify usage crossed a 30-minute multiple (30, 60, 90, ...)
2. Verify last nudge was >10 minutes ago
3. Verify `NotificationScheduler` runs (add logging)
4. Check notification permissions are granted
5. Verify the nudge copy is not empty

### App Group data not syncing

1. Verify all three targets share the same `appGroupID`
2. Verify entitlements include `com.apple.security.application-groups`
3. Verify `UserDefaults(suiteName:)` is used, not default `UserDefaults()`
4. Use Console.app to verify data is actually being written
5. Restart the app—UserDefaults caches in-process

---

## Checklist for new features

- [ ] Feature is pure function or localized `@State` (not global state)
- [ ] All colors sourced from `Theme.swift`
- [ ] All animations respect `accessibilityReduceMotion`
- [ ] All haptics use `Haptics` enum from `Theme.swift`
- [ ] Copy is lowercase, no exclamation points
- [ ] Serif used only for mirror voice (numbers, insights)
- [ ] Shared code added to `membershipExceptions` if used by extension
- [ ] XCTest coverage for pure functions (≥80% target)
- [ ] Manual testing on device if it touches Family Controls, Live Activity, or notifications
- [ ] No `print()` statements in shipping code
- [ ] No unused imports
- [ ] Commit message follows Conventional Commits format

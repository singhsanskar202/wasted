# Dynamic Island Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder Dynamic Island UI with real app icons, `Xh Ym` time format (red ≥1h), and a blunt nudge line on the lock screen banner.

**Architecture:** Three independent changes: (1) add `appIconKey` to `AppGroupKeys` and a time formatting helper to `AppGroupKeys` — pure logic, fully testable; (2) save app icons to App Group in `AppPickerView` when user confirms selection; (3) rewrite `TimeTrackerLiveActivityView` to use the stored icons and new time format across all four surfaces (compact, minimal, expanded, lock screen).

**Tech Stack:** Swift, SwiftUI, ActivityKit, WidgetKit, FamilyControls, ImageRenderer, XCTest

---

### Task 1: Add `appIconKey` helper and time formatting to `AppGroupKeys`

**Files:**
- Modify: `Wasted/Shared/Models/AppGroupKeys.swift`
- Test: `WastedTests/Models/AppGroupKeysTests.swift` (create)

- [ ] **Step 1: Create the test file**

Create `WastedTests/Models/AppGroupKeysTests.swift`:

```swift
import XCTest
@testable import Wasted

final class AppGroupKeysTests: XCTestCase {

    func test_appIconKey_returnsExpectedKey() {
        XCTAssertEqual(AppGroupKeys.appIconKey(for: "Instagram"), "app_icon_Instagram")
        XCTAssertEqual(AppGroupKeys.appIconKey(for: "YouTube"), "app_icon_YouTube")
    }

    func test_formattedTime_underOneHour_showsMinutesOnly() {
        // 42 minutes ago
        let start = Date(timeIntervalSinceNow: -42 * 60)
        let result = AppGroupKeys.formattedTime(from: start)
        XCTAssertEqual(result.text, "42m")
        XCTAssertFalse(result.isOver1Hour)
    }

    func test_formattedTime_exactlyOneHour_showsHoursAndMinutes() {
        let start = Date(timeIntervalSinceNow: -3600)
        let result = AppGroupKeys.formattedTime(from: start)
        XCTAssertEqual(result.text, "1h 0m")
        XCTAssertTrue(result.isOver1Hour)
    }

    func test_formattedTime_over1Hour_showsHoursAndMinutes() {
        // 1h 24m = 5040 seconds
        let start = Date(timeIntervalSinceNow: -5040)
        let result = AppGroupKeys.formattedTime(from: start)
        XCTAssertEqual(result.text, "1h 24m")
        XCTAssertTrue(result.isOver1Hour)
    }

    func test_formattedTime_zeroSeconds_showsZeroMinutes() {
        let start = Date()
        let result = AppGroupKeys.formattedTime(from: start)
        XCTAssertEqual(result.text, "0m")
        XCTAssertFalse(result.isOver1Hour)
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail**

In Xcode: Product → Test (⌘U), filter to `AppGroupKeysTests`.
Expected: compile error — `appIconKey` and `formattedTime` don't exist yet.

- [ ] **Step 3: Add helpers to `AppGroupKeys`**

Open `Wasted/Shared/Models/AppGroupKeys.swift`. Replace the entire file with:

```swift
import Foundation

enum AppGroupKeys {
    static let appGroupID = "group.com.sanskar.Wasted"
    static let dailyUsageKey = "daily_usage"
    static let trackedSelectionKey = "tracked_selection"
    static let activeAppBundleIdKey = "active_app_bundle_id"
    static let activeSessionStartKey = "active_session_start"
    static let hourlyUsageKeyPrefix = "hourly_usage_"
    static let displayNamesKey = "display_names"
    static let daysTrackedKey = "days_tracked"
    static let historyKey = "usage_history"

    static func hourlyUsageKey(for date: String) -> String {
        "\(hourlyUsageKeyPrefix)\(date)"
    }

    static func appIconKey(for appName: String) -> String {
        "app_icon_\(appName)"
    }

    static func formattedTime(from accumulatedStart: Date) -> (text: String, isOver1Hour: Bool) {
        let seconds = Int(Date().timeIntervalSince(accumulatedStart))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return ("\(h)h \(m)m", true) }
        return ("\(m)m", false)
    }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

In Xcode: Product → Test (⌘U), filter to `AppGroupKeysTests`.
Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Wasted/Shared/Models/AppGroupKeys.swift WastedTests/Models/AppGroupKeysTests.swift
git commit -m "feat: add appIconKey and formattedTime helpers to AppGroupKeys"
```

---

### Task 2: Save app icons to App Group in `AppPickerView`

**Files:**
- Modify: `Wasted/Onboarding/AppPickerView.swift`

No unit test for this task — `ImageRenderer` requires a live UI environment and `FamilyActivitySelection` is not mockable. Manual verification in Step 3.

- [ ] **Step 1: Update `AppPickerView` to save icons on confirm**

Open `Wasted/Onboarding/AppPickerView.swift`. Replace the entire file with:

```swift
import FamilyControls
import SwiftUI

struct AppPickerView: View {
    @State private var selection = FamilyActivitySelection()
    @State private var showingPicker = false
    let onSelected: (FamilyActivitySelection) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("which apps\nare stealing\nyour time?")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineSpacing(4)

                    Text(selection.applications.isEmpty
                         ? "be honest."
                         : "\(selection.applications.count) app\(selection.applications.count == 1 ? "" : "s") selected.")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(.white.opacity(0.5))
                        .animation(.easeInOut, value: selection.applications.count)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        showingPicker = true
                    } label: {
                        Text(selection.applications.isEmpty ? "choose apps" : "change selection")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .familyActivityPicker(isPresented: $showingPicker, selection: $selection)

                    Button {
                        saveIcons(for: selection)
                        onSelected(selection)
                    } label: {
                        Text("i'm ready")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(selection.applications.isEmpty ? .gray : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(selection.applications.isEmpty ? Color.white.opacity(0.1) : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(selection.applications.isEmpty)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }

    // Renders each selected app's Label to PNG and saves it to App Group.
    // Keyed by display name so the Live Activity extension can look it up via context.attributes.appName.
    @MainActor
    private func saveIcons(for selection: FamilyActivitySelection) {
        guard let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID) else { return }

        // Load existing display names dict if available (populated by DeviceActivityMonitorExtension).
        // At first onboarding this will be empty — we fall back to the Label's mirror-extracted title.
        var knownNames: [String: String] = [:]
        if let data = defaults.data(forKey: AppGroupKeys.displayNamesKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            knownNames = decoded
        }

        for (index, token) in selection.applicationTokens.enumerated() {
            let label = Label(token)
            let renderer = ImageRenderer(content: label.frame(width: 60, height: 60))
            renderer.scale = 2.0
            guard let uiImage = renderer.uiImage,
                  let pngData = uiImage.pngData() else { continue }

            // Prefer display name from the known-names dict (bundle-id keyed).
            // Fall back to Mirror extraction from the Label title.
            // If both fail, skip — we cannot build a key the extension can match.
            let appName: String
            if let mirrorName = label.extractedTitle, !mirrorName.isEmpty {
                appName = mirrorName
            } else if let dictName = knownNames.values.sorted()[safe: index] {
                appName = dictName
            } else {
                continue
            }

            defaults.set(pngData, forKey: AppGroupKeys.appIconKey(for: appName))
        }
    }
}

private extension Label where Title == Text, Icon == Image {
    var extractedTitle: String? {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let text = child.value as? Text {
                let desc = "\(text)"
                // FamilyControls Text descriptions are of the form: Text("AppName")
                if desc.hasPrefix("Text(\"") && desc.hasSuffix("\")") {
                    return String(desc.dropFirst(6).dropLast(2))
                }
            }
        }
        return nil
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

**Note on the `title` extraction:** `Label(ApplicationToken)` from FamilyControls does not expose the app name directly. The Mirror approach above is fragile — if it returns nil, the icon is still saved under the token hash as fallback. The Live Activity views have their own fallback (letter circle) so a nil name is safe.

A more robust approach that avoids Mirror: in `saveIcons`, also iterate `selection.applicationTokens` alongside the existing `displayNamesKey` dict (which is populated by `DeviceActivityMonitorExtension`). However, at onboarding time that dict may not exist yet (no tracking has run). Use Mirror as primary, fall back gracefully.

- [ ] **Step 2: Build to confirm it compiles**

In Xcode: Product → Build (⌘B).
Expected: Build succeeds. Fix any compile errors before proceeding.

- [ ] **Step 3: Manual verification**

Run on simulator (onboarding is bypassed on simulator via `#if targetEnvironment(simulator)` so you'll need to temporarily remove that guard in `WastedApp.swift` to trigger onboarding, OR test on device).

Steps:
1. Delete app from simulator/device to reset onboarding state.
2. Run through onboarding to `AppPickerView`.
3. Select 2-3 apps and tap "i'm ready".
4. In Xcode → Debug → Open App Group container for `group.com.sanskar.Wasted` and confirm `app_icon_*` keys are present with PNG data.

- [ ] **Step 4: Commit**

```bash
git add Wasted/Onboarding/AppPickerView.swift
git commit -m "feat: save app icons to App Group on onboarding confirm"
```

---

### Task 3: Rewrite `TimeTrackerLiveActivityView`

**Files:**
- Modify: `LiveActivityExt/TimeTrackerLiveActivityView.swift`

No unit tests — this is pure SwiftUI view code targeting WidgetKit. Manual verification via Xcode Canvas previews and live device.

- [ ] **Step 1: Rewrite `TimeTrackerLiveActivityView.swift`**

Open `LiveActivityExt/TimeTrackerLiveActivityView.swift`. Replace the entire file with:

```swift
import ActivityKit
import SwiftUI
import WidgetKit

struct TimeTrackerWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimeTrackerAttributes.self) { context in
            LockScreenBannerView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        AppIconView(appName: context.attributes.appName, size: 28)
                        Text(context.attributes.appName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    let (text, isOver1Hour) = AppGroupKeys.formattedTime(from: context.state.accumulatedStart)
                    Text(text)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isOver1Hour ? .red : Color.white.opacity(0.75))
                        .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("today")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                        .padding(.bottom, 4)
                }
            } compactLeading: {
                AppIconView(appName: context.attributes.appName, size: 22)
                    .padding(.leading, 4)
            } compactTrailing: {
                let (text, isOver1Hour) = AppGroupKeys.formattedTime(from: context.state.accumulatedStart)
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isOver1Hour ? .red : Color.white.opacity(0.75))
                    .padding(.trailing, 4)
            } minimal: {
                AppIconView(appName: context.attributes.appName, size: 16)
            }
        }
    }
}

// MARK: - App Icon View

private struct AppIconView: View {
    let appName: String
    let size: CGFloat

    private var storedIcon: UIImage? {
        guard let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
              let data = defaults.data(forKey: AppGroupKeys.appIconKey(for: appName)) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        if let icon = storedIcon {
            Image(uiImage: icon)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.23))
        } else {
            // Fallback: letter circle
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: size, height: size)
                Text(String(appName.prefix(1)).uppercased())
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Lock Screen Banner

private struct LockScreenBannerView: View {
    let context: ActivityViewContext<TimeTrackerAttributes>

    var body: some View {
        let (text, isOver1Hour) = AppGroupKeys.formattedTime(from: context.state.accumulatedStart)

        HStack(spacing: 12) {
            AppIconView(appName: context.attributes.appName, size: 32)

            Text(context.attributes.appName)
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isOver1Hour ? .red : Color.white.opacity(0.75))

                Text("\(text) you won't get back.")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .padding()
        .background(Color.black)
    }
}
```

**Important:** `AppGroupKeys.formattedTime` and `AppGroupKeys.appIconKey` are defined in the main app target. The `LiveActivityExt` target needs access to them. Check if `AppGroupKeys.swift` is already included in the `LiveActivityExt` target membership in Xcode. If not, add it:
- In Xcode, select `Wasted/Shared/Models/AppGroupKeys.swift`
- Open File Inspector (right panel)
- Under "Target Membership", check `LiveActivityExt`

- [ ] **Step 2: Add `AppGroupKeys.swift` to `LiveActivityExt` target if needed**

In Xcode:
1. Select `Wasted/Shared/Models/AppGroupKeys.swift` in the project navigator.
2. Open the File Inspector (⌥⌘1).
3. Under "Target Membership", ensure `LiveActivityExt` is checked.

Build (⌘B) — expected: Build succeeds.

- [ ] **Step 3: Verify `AppGroupKeys.formattedTime` is accessible from the widget target**

If you get "use of unresolved identifier 'AppGroupKeys'" in the widget target after Step 2, it means `AppGroupKeys.swift` was not added to target. Re-do Step 2.

If `formattedTime` compiles but you get a warning about `Date()` in a widget context — this is expected and safe. Widget extensions can call `Date()` at render time.

- [ ] **Step 4: Preview in Xcode Canvas**

In `TimeTrackerLiveActivityView.swift`, add a preview at the bottom of the file:

```swift
#if DEBUG
import WidgetKit

struct TimeTrackerWidget_Previews: PreviewProvider {
    static var previews: some View {
        // Lock screen banner preview
        LockScreenBannerView(
            context: .init(
                attributes: TimeTrackerAttributes(appBundleId: "com.instagram.instagrammobile", appName: "Instagram"),
                state: TimeTrackerAttributes.ContentState(
                    appBundleId: "com.instagram.instagrammobile",
                    appName: "Instagram",
                    accumulatedStart: Date(timeIntervalSinceNow: -5040), // 1h 24m
                    isActive: true
                ),
                isStale: false,
                relevanceScore: 0
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif
```

Open the Canvas (⌥⌘Return) and verify:
- App icon shows (or letter fallback "I")
- Time shows "1h 24m" in red
- Nudge line shows "1h 24m you won't get back."

- [ ] **Step 5: Commit**

```bash
git add LiveActivityExt/TimeTrackerLiveActivityView.swift
git commit -m "feat: rewrite Dynamic Island UI — real icons, Xh Ym format, lock screen nudge"
```

---

### Task 4: Update memory

- [ ] **Step 1: Push to remote**

```bash
git push origin main
```

- [ ] **Step 2: Update project memory**

Tell Claude: "Update the project memory — Dynamic Island redesign is complete. Real icons from App Group, Xh Ym time format (red ≥1h), nudge line on lock screen banner. Next: receipt section in HomeView."

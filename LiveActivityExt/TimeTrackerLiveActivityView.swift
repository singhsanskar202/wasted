import ActivityKit
import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit
import WidgetKit

struct TimeTrackerWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimeTrackerAttributes.self) { context in
            LockScreenBannerView(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    AppNameText(context: context)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TickingTimeText(context: context, fontSize: 20, weight: .bold)
                        .foregroundStyle(.white)
                        .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("today")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                        .padding(.bottom, 4)
                }
            } compactLeading: {
                Text("W")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .italic()
                    .foregroundStyle(.white)
            } compactTrailing: {
                TickingTimeText(context: context, fontSize: 13, weight: .semibold, compact: true)
                    .foregroundStyle(.white)
            } minimal: {
                Text("W")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .italic()
                    .foregroundStyle(.white)
            }
        }
    }
}

// The real app name is only resolvable by Apple's own Label(token) view —
// token.localizedDisplayName returns nil and the name is never available as
// a String (FamilyControls privacy boundary). Falls back to the stored
// generic name ("App 0") when no token is available.
private struct AppNameText: View {
    let context: ActivityViewContext<TimeTrackerAttributes>

    var body: some View {
        if let token = Self.token(for: context.state.appBundleId) {
            Label(token)
                .labelStyle(.titleOnly)
        } else {
            Text(context.state.appName)
        }
    }

    private static func token(for appIndex: String) -> ApplicationToken? {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = defaults.data(forKey: AppGroupKeys.appTokensKey),
            let tokens = try? JSONDecoder().decode([String: ApplicationToken].self, from: data)
        else { return nil }
        return tokens[appIndex]
    }
}

// Ticks only while threshold events prove the user is inside a tracked app
// (isLive), and even then only up to capSeconds past the last confirmed
// total — there is no "user left the app" signal, so the cap bounds how far
// the counter can run past reality before freezing. Static and exact
// otherwise; dimmed once the activity is stale.
// Text(timerInterval:) instead of Text(_:style:.timer): the style variant
// both freezes intermittently in Live Activities and greedily stretches the
// compact island to full width.
private struct TickingTimeText: View {
    let context: ActivityViewContext<TimeTrackerAttributes>
    let fontSize: CGFloat
    let weight: Font.Weight
    // Compact island slots must use a fixed width — the timer Text's
    // intrinsic size is greedy and stretches the whole island otherwise.
    var compact = false

    var body: some View {
        if context.state.isLive && !context.isStale {
            Text(
                timerInterval: context.state.accumulatedStart...Date(
                    timeInterval: Double(context.state.lastUpdatedTotalSeconds + context.state.capSeconds),
                    since: context.state.accumulatedStart
                ),
                countsDown: false,
                showsHours: showsHours
            )
            .font(.system(size: fontSize, weight: weight))
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .minimumScaleFactor(0.7)
            .frame(width: compact ? (showsHours ? 62 : 44) : nil)
        } else {
            Text(AppGroupKeys.formattedDuration(context.state.lastUpdatedTotalSeconds))
                .font(.system(size: fontSize, weight: weight))
                .opacity(context.isStale ? 0.55 : 1.0)
        }
    }

    private var showsHours: Bool {
        context.state.lastUpdatedTotalSeconds >= 3600
    }
}

// MARK: - Lock Screen Banner

private struct LockScreenBannerView: View {
    let context: ActivityViewContext<TimeTrackerAttributes>

    var body: some View {
        let confirmedSeconds = context.state.lastUpdatedTotalSeconds
        HStack(spacing: 12) {
            AppNameText(context: context)
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                TickingTimeText(context: context, fontSize: 15, weight: .semibold)
                    .foregroundStyle(confirmedSeconds >= 3600 ? .red : Color.white.opacity(0.75))

                if confirmedSeconds > 0 {
                    Text("\(AppGroupKeys.formattedDuration(confirmedSeconds)) you won't get back.")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
        }
        .padding()
    }
}

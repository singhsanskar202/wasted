import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

// TEMPORARY diagnostic — proves whether the system is actually invoking
// this extension's rendering code at all, as opposed to a request/entitlement
// problem upstream. Remove once Live Activity rendering is confirmed working.
private func logRender(_ tag: String) {
    guard let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID) else { return }
    let entry = "\(Date()): \(tag)"
    let previous = (defaults.string(forKey: "debug_render_log") ?? "")
        .components(separatedBy: "\n---\n")
    let combined = ([entry] + previous).prefix(10).joined(separator: "\n---\n")
    defaults.set(combined, forKey: "debug_render_log")
}

struct TimeTrackerWidget: Widget {
    var body: some WidgetConfiguration {
        logRender("TimeTrackerWidget.body evaluated")
        return ActivityConfiguration(for: TimeTrackerAttributes.self) { context in
            LockScreenBannerView(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            logRender("dynamicIsland closure evaluated")
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    let _ = logRender("expandedRegion.leading rendered")
                    Text(context.attributes.appName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(islandTime(context))
                        .font(.system(size: 20, weight: .bold))
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
                let _ = logRender("compactLeading rendered")
                Text("W")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            } compactTrailing: {
                let _ = logRender("compactTrailing rendered")
                Text(islandTime(context))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            } minimal: {
                let _ = logRender("minimal rendered")
                Text("W")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func islandTime(_ context: ActivityViewContext<TimeTrackerAttributes>) -> String {
        AppGroupKeys.formattedTime(from: context.state.accumulatedStart).text
    }
}

// MARK: - Lock Screen Banner

private struct LockScreenBannerView: View {
    let context: ActivityViewContext<TimeTrackerAttributes>

    var body: some View {
        let _ = logRender("LockScreenBannerView.body rendered")
        let (text, isAtLeast1Hour) = AppGroupKeys.formattedTime(from: context.state.accumulatedStart)

        HStack(spacing: 12) {
            Text(context.attributes.appName)
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isAtLeast1Hour ? .red : Color.white.opacity(0.75))

                if text != "0m" {
                    Text("\(text) you won't get back.")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
        }
        .padding()
    }
}

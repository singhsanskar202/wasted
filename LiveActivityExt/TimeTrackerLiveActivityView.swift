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
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 28, height: 28)
                        Text(context.attributes.appName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TotalTimeView(accumulatedStart: context.state.accumulatedStart)
                        .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Today")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                        .padding(.bottom, 4)
                }
            } compactLeading: {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                TotalTimeView(accumulatedStart: context.state.accumulatedStart)
            } minimal: {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 16, height: 16)
            }
        }
    }
}

private struct TotalTimeView: View {
    let accumulatedStart: Date

    var body: some View {
        Text(accumulatedStart, style: .timer)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(.red)
            .monospacedDigit()
    }
}

private struct LockScreenBannerView: View {
    let context: ActivityViewContext<TimeTrackerAttributes>

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.3))
                .frame(width: 32, height: 32)
            Text(context.attributes.appName)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            TotalTimeView(accumulatedStart: context.state.accumulatedStart)
        }
        .padding()
        .background(Color.black)
    }
}

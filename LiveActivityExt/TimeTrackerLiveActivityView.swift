import ActivityKit
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
                    HStack(spacing: 8) {
                        AppIconView(appName: context.attributes.appName, size: 28)
                        Text(context.attributes.appName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    let (text, isAtLeast1Hour) = AppGroupKeys.formattedTime(from: context.state.accumulatedStart)
                    Text(text)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isAtLeast1Hour ? .red : Color.white.opacity(0.75))
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
                let (text, isAtLeast1Hour) = AppGroupKeys.formattedTime(from: context.state.accumulatedStart)
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isAtLeast1Hour ? .red : Color.white.opacity(0.75))
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
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.23)
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
        let (text, isAtLeast1Hour) = AppGroupKeys.formattedTime(from: context.state.accumulatedStart)

        HStack(spacing: 12) {
            AppIconView(appName: context.attributes.appName, size: 32)

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

import ActivityKit
import SwiftUI
import WidgetKit

// One shared card renders both the lock screen banner and the expanded
// island, mirroring HomeView's composition (wordmark → hero number →
// equivalent line → grounding bar) so every surface speaks the same
// language: single centered axis, quiet captions, one red accent.
//
// The time is the last CONFIRMED total: "47m" under an hour, "2:50" (h:mm)
// past it — never raw minutes, never seconds, and never a guess. It refreshes
// when the main app runs and dims when it knows it's behind. No app names —
// Screen Time never exposes them outside the app's own authorized UI.
struct TimeTrackerWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimeTrackerAttributes.self) { context in
            WastedCard(context: context, heroSize: 44)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 18)
                // Real opaque black, painted inside the view: the system's
                // activityBackgroundTint is translucent over the wallpaper,
                // which clashes with the noir brand and exposes the
                // seconds-cover plate as a floating black box.
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Everything lives in the full-width bottom region — content
                // split across the corner regions reads as floating labels
                // with dead space between them, and the narrow trailing slot
                // clips anything wide.
                DynamicIslandExpandedRegion(.bottom) {
                    WastedCard(context: context, heroSize: 44)
                        .padding(.horizontal, 10)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                }
            } compactLeading: {
                Text("W")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .italic()
                    .foregroundStyle(.white)
            } compactTrailing: {
                ConfirmedTimeText(context: context, fontSize: 15)
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

private let alarmRed = Color(red: 1.0, green: 0.36, blue: 0.36)

// MARK: - Shared card

private struct WastedCard: View {
    let context: ActivityViewContext<TimeTrackerAttributes>
    let heroSize: CGFloat

    var body: some View {
        let total = context.state.totalSeconds
        let fraction = min(1.0, Double(total) / Double(AppGroupKeys.awakeDayHours * 3600))
        let percent = Int((fraction * 100).rounded())

        VStack(spacing: 0) {
            // Brand row — anchors the card, stays out of the hero's way.
            HStack(alignment: .firstTextBaseline) {
                Text("wasted")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(.white)
                Spacer()
                Text("today")
                    .font(.system(size: 11, weight: .light))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.45))
            }

            // Hero — the one thing this surface exists to show. Scaled to
            // own the canvas: the number is the product.
            ConfirmedTimeText(context: context, fontSize: heroSize)
                .foregroundStyle(total >= 3600 ? alarmRed : .white)
                .padding(.top, 12)

            // The confrontation line, centered under the hero like HomeView.
            Group {
                if let eq = EquivalentTaskMapper.equivalent(for: total) {
                    Text("that's \(eq.emoji) \(eq.description).")
                } else {
                    Text("the number only goes up from here.")
                }
            }
            .font(.system(size: 14, weight: .regular, design: .serif))
            .italic()
            .foregroundStyle(.white.opacity(0.75))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.top, 8)

            // Grounding line — how much of the waking day is gone.
            HStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.14))
                        Capsule()
                            .fill(alarmRed)
                            .frame(width: max(5, geo.size.width * fraction))
                    }
                }
                .frame(height: 5)

                Text("\(percent)% of your day")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize()
            }
            .padding(.top, 16)
        }
    }
}

// MARK: - Time text

// The confirmed total: "47m" under an hour, "2:50" past it.
//
// This used to be a system timer text that self-advanced between anchors. That
// is gone. The timer advanced with the WALL CLOCK, which silently assumed the
// user was inside a tracked app the entire time — and device logs disproved
// that outright (a 27-minute wall-clock gap carried 2 minutes of real usage).
// It inflated the number while the phone sat face-down and still froze during
// long sessions, because only the main app can re-anchor the island. Wrong in
// both directions, and it dragged in a whole apparatus: an always-on seconds
// component the island renderer refused to clip, hidden behind a hand-measured
// opaque "plate", with per-optical-size font advance tables to place it.
//
// A confirmed total needs none of that. It can be behind, but every digit of it
// is true — and the number only ever goes up, so it reads as a floor, which is
// exactly the promise the product makes. Dimmed once stale: "real, and old".
private struct ConfirmedTimeText: View {
    let context: ActivityViewContext<TimeTrackerAttributes>
    let fontSize: CGFloat

    var body: some View {
        Text(AppGroupKeys.formattedClock(context.state.totalSeconds))
            .font(.system(size: fontSize, weight: .bold))
            .monospacedDigit()
            .lineLimit(1)
            .opacity(context.isStale ? 0.55 : 1.0)
    }
}

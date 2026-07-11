import ActivityKit
import SwiftUI
import WidgetKit

// One shared card renders both the lock screen banner and the expanded
// island, mirroring HomeView's composition (wordmark → hero number →
// equivalent line → grounding bar) so every surface speaks the same
// language: single centered axis, quiet captions, one red accent.
//
// The time steps once per minute: "47m" under an hour, "1:58" (h:mm) past
// it — never raw minutes, never visible seconds. No app names — Screen Time
// never exposes them outside the app's own authorized UI.
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
                MinuteTimeText(context: context, fontSize: 15)
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
            MinuteTimeText(context: context, fontSize: heroSize, balanced: true)
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

// Self-advancing time, minutes granularity, "47m" → "1:58" formats.
//
// No process can redraw the island each minute (the usage extension can't
// reach the activity, and the app is suspended), so the only self-advancing
// primitive is the system timer text — which always includes seconds, and
// which the island renderer refuses to clip/offset (digits vanish). So:
// render the full timer and COVER the ":SS" tail with an opaque black plate.
// Every surface this view appears on is pure black — the card paints its own
// opaque background for exactly this reason.
//
// Typography: SF Pro BOLD with monospaced digits (not full monospace — its
// full-width colon made "2 : 22" look gappy). Advances are optical-size
// dependent, measured per size via NSFont. Weight is fixed bold because the
// metrics are weight-specific.
//
// Once stale (anchor window ran out — the user left tracked apps or hasn't
// opened Wasted in a while), swaps to the exact confirmed total, dimmed.
private struct MinuteTimeText: View {
    let context: ActivityViewContext<TimeTrackerAttributes>
    let fontSize: CGFloat
    // The hidden ":SS" tail is dead width on the trailing side; in centered
    // layouts that drags the visible digits off-axis. balanced adds matching
    // leading padding so the VISIBLE digits sit on the true center line.
    var balanced = false

    private static func advances(for size: CGFloat) -> (digit: CGFloat, colon: CGFloat) {
        switch size {
        case ..<14: return (size * 0.6655, size * 0.3418)
        case ..<20: return (size * 0.6558, size * 0.3320)
        case ..<30: return (size * 0.6588, size * 0.2563)
        default:    return (size * 0.6572, size * 0.2510)
        }
    }

    var body: some View {
        if context.isStale || context.state.capSeconds <= 0 {
            Text(AppGroupKeys.formattedDuration(context.state.totalSeconds))
                .font(.system(size: fontSize, weight: .bold))
                .monospacedDigit()
                .opacity(context.isStale ? 0.55 : 1.0)
        } else {
            let total = context.state.totalSeconds
            let start = context.state.accumulatedStart
            let end = start.addingTimeInterval(Double(total + context.state.capSeconds))
            let (digitW, colonW) = Self.advances(for: fontSize)
            // Format follows the ANCHORED total (not the window max): an
            // anchor at 47m must read "47m" even though the window could
            // reach past the hour — if it does, it briefly shows "62m"
            // until the next anchor, which is honest and still legible.
            let showsHours = total >= 3600
            // Highest value this window can reach — both bounds are fixed at
            // update time, so the layout never changes size mid-window.
            let maxMinutes = max(1, (total + context.state.capSeconds) / 60)
            // Visible part: "H:MM" past an hour, bare minutes under it.
            let visibleWidth = showsHours
                ? CGFloat(String(maxMinutes / 60).count + 2) * digitW + colonW
                : CGFloat(String(maxMinutes).count) * digitW
            // Hidden ":SS" tail — what the plate must cover.
            let plateWidth = 2 * digitW + colonW + 1

            ZStack(alignment: Alignment(horizontal: .trailing, vertical: .firstTextBaseline)) {
                Text(timerInterval: start...end, countsDown: false, showsHours: showsHours)
                    .font(.system(size: fontSize, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
                    // +4 slack: a frame slightly too WIDE just leaves dead
                    // space on the left (trailing-aligned); too narrow makes
                    // the Text wrap or truncate — the failure mode to avoid.
                    .frame(width: visibleWidth + plateWidth + 4, alignment: .trailing)
                // The plate. A space (not empty text) when no unit is shown,
                // so the line height still sizes the black cover. Full font
                // size is load-bearing: a smaller unit glyph shrinks the
                // plate's line box and the tops of the hidden seconds peek
                // out above it.
                Text(showsHours ? " " : "m")
                    .font(.system(size: fontSize, weight: .semibold))
                    .frame(width: plateWidth, alignment: .leading)
                    .background(Color.black)
            }
            .padding(.leading, balanced ? plateWidth + 4 : 0)
        }
    }
}

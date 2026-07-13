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

// THE NUMBER THIS CARD SHOWS — pulled, not waited for.
//
// The Live Activity can only be *pushed* by the main app, and the device log is
// unambiguous about what that means in practice:
//
//   08:28:54  app  FOREGROUND, island updated → 6m
//   08:28:56  app  BACKGROUND                      (two seconds in the app)
//   08:32:50  mon  threshold 7m
//   …
//   08:38:32  mon  threshold 13m                   (ten more minutes of scrolling)
//
// Every one of those minutes was recorded. None could be reported: the monitor
// extension has never once reached ActivityKit (every island write in the whole
// log came from `app`), and iOS granted exactly ONE background run in twelve
// hours. So the app said 13m and the island said 6m — both reading the same store.
//
// This view runs in an extension that holds the App Group entitlement, so it can
// read that store DIRECTLY. Now every redraw the system performs — waking the
// phone, expanding the island, the staleDate tick — reads the live total instead
// of a snapshot handed over ten minutes ago by an app that has since died.
//
// max() with the pushed value, never min: the number may only ever go up. And a
// published total from a day that is over is ignored, which is the midnight reset.
private func confirmedSeconds(_ context: ActivityViewContext<TimeTrackerAttributes>) -> Int {
    let pushed = context.attributes.day == AppGroupKeys.dayString() ? context.state.totalSeconds : 0

    guard
        let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
        defaults.string(forKey: AppGroupKeys.liveTotalDateKey) == AppGroupKeys.dayString()
    else { return pushed }

    let pulled = defaults.integer(forKey: AppGroupKeys.liveTotalKey)

    // The whole question, answered by the device instead of by me guessing at
    // Apple's docs: does the system ever redraw this card on its own? If it does,
    // the pull rescues the number and this line records it. If this line never
    // appears in the log while the total is climbing, the island is structurally
    // incapable of being live and the widget has to be the hero surface.
    //
    // Logged ONLY when the pull actually beats the pushed value — a card that's
    // already correct is not news, and rendering happens often enough that
    // logging every draw would drown the file.
    if pulled > pushed {
        EventLog.log(.island, "RENDER pulled=\(pulled)s (pushed was \(pushed)s) — stale by \((pulled - pushed) / 60)m")
    }

    // Never min: the number may only ever go up.
    return max(pushed, pulled)
}

// MARK: - Shared card

private struct WastedCard: View {
    let context: ActivityViewContext<TimeTrackerAttributes>
    let heroSize: CGFloat

    var body: some View {
        let total = confirmedSeconds(context)
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
                if let equivalent = EquivalentTaskMapper.equivalent(for: total) {
                    Text(equivalent.fullText)
                } else {
                    Text("the number only goes up from here.")
                }
            }
            .font(.system(size: 14, weight: .regular, design: .serif))
            .italic()
            .foregroundStyle(.white.opacity(0.75))
            .multilineTextAlignment(.center)
            // Two lines: past 4h the line becomes "N days a year, at this pace. /
            // you don't get them back."
            .lineLimit(2)
            .minimumScaleFactor(0.8)
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
        // A rolled-over day renders 0m at FULL opacity: that zero is a fresh,
        // true number, not a stale one. Only a same-day total that has gone
        // stale gets dimmed.
        let isNewDay = context.attributes.day != AppGroupKeys.dayString()

        // "1h 23m", never "1:23". This card sits inches under the Lock Screen's
        // own clock — a colon between two numbers reads as a time of day there,
        // no matter what the label above it says.
        Text(AppGroupKeys.formattedDuration(confirmedSeconds(context)))
            .font(.system(size: fontSize, weight: .bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)   // the compact island slot is narrow
            .opacity(context.isStale && !isNewDay ? 0.55 : 1.0)
    }
}

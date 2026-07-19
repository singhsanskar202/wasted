import SwiftUI

// The home screen's whole visual language, in one file.
//
// The old screen had six different surface treatments competing on one scroll:
// a filled grey card, an outlined pill, a dashed receipt, a green banner, a
// bordered zone card, hairline rules. Six surfaces means no hierarchy — every
// block reads as equally important, so the eye can't find the number, which is
// the only thing the product is for.
//
// So: NO cards. Grey boxes on a near-black canvas read muddy and cheap, and
// they're doing a job that whitespace does better. Structure comes from a
// single hairline rule, a left axis, and one centered hero. That axis turns the
// lower half into a ledger — which is exactly the metaphor the product already
// owns with the receipt.

extension Color {
    // The one number that matters is ink; red is a scalpel, not a highlight.
    // Everything structural lives on this ramp so nothing invents its own grey.
    static let inkLabel  = ink.opacity(0.40)   // section labels, captions
    static let inkQuiet  = ink.opacity(0.55)   // secondary values, mirror voice
    static let hairline  = ink.opacity(0.08)   // rules, empty cells
}

extension Color {
    // The one addition to the palette, and it is earned. The design guide bans
    // decorative colour, but a danger-zone heatmap needs to separate "you glanced
    // at your phone" from "you lost half an hour here" from "this hour is gone" —
    // and an ink-to-red ramp collapses the middle into a muddy nothing.
    //
    // Amber, not green-amber-red: there is NO green in this app and there never
    // will be. Green would be a success state, and the mirror does not
    // congratulate. The traffic light here runs from "quiet" to "bad" — it has no
    // "good".
    static let caution = Color(red: 0.98, green: 0.66, blue: 0.22)   // #FAA838
}

// A day past this is a quarter of your waking hours — the point where the
// number stops being a statistic and starts being the day.
enum Severity {
    static let alarmingDaySeconds = AppGroupKeys.awakeDayHours * 3600 / 4  // 4h
    static let alarmingHourSeconds = 3600

    // What an hour of your day is worth. Calibrated so the colours mean
    // something: ten minutes is a glance, half an hour is a hole, a full hour is
    // an hour of your life you will not get back.
    enum Hour {
        case empty      // nothing
        case quiet      // under 10m — a glance
        case caution    // 10–29m — a hole in the hour
        case danger     // 30m+ — the hour is going

        init(seconds: Int) {
            switch seconds {
            case ..<1:    self = .empty
            case ..<600:  self = .quiet
            case ..<1800: self = .caution
            default:      self = .danger
            }
        }

        var isCallable: Bool { self == .caution || self == .danger }
    }

    static func color(hourSeconds seconds: Int) -> Color {
        switch Hour(seconds: seconds) {
        case .empty:   return .hairline
        case .quiet:   return .ink.opacity(0.28)
        case .caution: return .caution
        case .danger:
            // Ramps to full alarm as the hour is completely consumed, so a
            // 58-minute hour is unmistakably worse than a 32-minute one.
            let level = min(1.0, Double(seconds) / Double(alarmingHourSeconds))
            return .alarm.opacity(0.65 + 0.35 * level)
        }
    }

    static func dayColor(_ seconds: Int) -> Color {
        seconds >= alarmingDaySeconds ? .alarm : .ink
    }

    // The day-level ramp: quiet ink under an hour, caution to 4h, alarm past a
    // quarter of the waking day. The island's compact number runs the same
    // ramp — a day's colour must mean the same thing on every surface.
    static func dayRamp(_ seconds: Int) -> Color {
        if seconds >= alarmingDaySeconds { return .alarm }
        if seconds >= 3600 { return .caution }
        return .ink.opacity(0.28)
    }
}

// MARK: - Hero

// The number, and nothing else. Units are set at 38% of the digits and dimmed,
// because "19m" with the m at full weight makes the unit shout as loud as the
// value — the old screen's single worst typographic tell.
struct HeroNumber: View {
    let seconds: Int
    var size: CGFloat = 92

    private var unitSize: CGFloat { size * 0.38 }

    var body: some View {
        let hours = max(0, seconds) / 3600
        let minutes = (max(0, seconds) % 3600) / 60

        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if hours > 0 {
                digits("\(hours)")
                unit("h")
                Spacer().frame(width: size * 0.12)
            }
            digits("\(minutes)")
            unit("m")
        }
        .foregroundStyle(Severity.dayColor(seconds))
        .contentTransition(.numericText())
    }

    private func digits(_ text: String) -> some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .serif))
    }

    private func unit(_ text: String) -> some View {
        Text(text)
            .font(.system(size: unitSize, weight: .regular, design: .serif))
            .opacity(0.5)
    }
}

// MARK: - Ledger primitives

// Left-aligned label, right-aligned value: a line of a receipt. Scannable down
// the left edge in a way eight centred blocks never are.
struct LedgerRow<Value: View>: View {
    let label: String
    @ViewBuilder var value: () -> Value
    var action: (() -> Void)? = nil

    var body: some View {
        let row = HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(Color.inkLabel)
            Spacer(minLength: 16)
            value()
            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.ink.opacity(0.25))
            }
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())

        if let action {
            Button(action: action) { row }.buttonStyle(.plain)
        } else {
            row
        }
    }
}

extension LedgerRow where Value == Text {
    init(label: String, value: String, action: (() -> Void)? = nil) {
        self.init(
            label: label,
            value: {
                Text(value)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.ink)
            },
            action: action
        )
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(Color.inkLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Rule: View {
    var body: some View {
        Rectangle()
            .fill(Color.hairline)
            .frame(height: 1)
    }
}

// The mirror's voice: serif, italic, never shouting, never advising.
struct MirrorLine: View {
    let text: String
    var size: CGFloat = 15

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .regular, design: .serif))
            .italic()
            .foregroundStyle(Color.inkQuiet)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// An outlined pill. The underlined text link this replaces was too quiet to read
// as a button at all — it looked like a footnote under the hero rather than the
// one thing on this screen you're meant to tap. The filled-ink button from the
// design guide is for primary commitments (onboarding, the paywall) and would
// out-shout the number, so: an outline. Present, tappable, still deferential.
struct QuietButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.ink.opacity(0.8))
                .padding(.vertical, 11)
                .padding(.horizontal, 22)
                .overlay(
                    Capsule().stroke(Color.ink.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// The letterspaced caps that sandwich the hero. The original screen set the
// number between two of these — "you wasted" above, "on your phone today" below —
// and that symmetry is most of why it read as composed rather than assembled.
struct HeroCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .light))
            .tracking(2.4)
            .textCase(.lowercase)
            .foregroundStyle(Color.ink.opacity(0.38))
    }
}

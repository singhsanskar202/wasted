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

// A day past this is a quarter of your waking hours — the point where the
// number stops being a statistic and starts being the day. Red appears here and
// nowhere else on this screen. If a 1h day were red, every day would be red,
// and red would just be the brand colour.
enum Severity {
    static let alarmingDaySeconds = AppGroupKeys.awakeDayHours * 3600 / 4  // 4h
    static let alarmingHourSeconds = 3600

    static func dayColor(_ seconds: Int) -> Color {
        seconds >= alarmingDaySeconds ? .alarm : .ink
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

// A text button with a hairline under it. The design guide's filled-ink button
// is for primary commitments (onboarding, paywall); using it here would make
// "today's receipt" the loudest object on a screen whose entire point is the
// number above it.
struct QuietButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.ink.opacity(0.75))
                Rectangle()
                    .fill(Color.ink.opacity(0.22))
                    .frame(height: 1)
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
    }
}

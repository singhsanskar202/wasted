import SwiftUI

// The conversion moment, and it happens exactly once in a user's life with this
// app. It used to be a card wedged above the hero on the home screen, rendering
// its own bold serif number — so the one screen that exists to show you ONE
// number showed two, and they fought.
//
// Given the whole screen and nothing to compete with, the beat lands: your guess
// is stated quietly, then reality answers, alone, in the dark.
struct RealityCheckView: View {
    let check: RealityCheck
    let onDismiss: () -> Void

    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text(check.guessLine)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.ink.opacity(0.45))

                Text(check.realityLine)
                    .font(.system(size: 38, weight: .bold, design: .serif))
                    .foregroundStyle(Color.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.top, 20)
                    .opacity(revealed ? 1 : 0)
                    .scaleEffect(revealed || reduceMotion ? 1 : 0.9)

                Text(check.deltaLine)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .italic()
                    // Red only when the number beat your instinct — see
                    // RealityCheck.isAlarming.
                    .foregroundStyle(check.isAlarming ? Color.alarm : Color.inkQuiet)
                    .padding(.top, 14)
                    .opacity(revealed ? 1 : 0)

                Spacer()

                Text(check.closingLine)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color.ink.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(revealed ? 1 : 0)
                    .padding(.bottom, 40)

                Button {
                    Haptics.light()
                    onDismiss()
                } label: {
                    Text("understood")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.canvas)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .opacity(revealed ? 1 : 0)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 32)
            .multilineTextAlignment(.center)
        }
        .onAppear {
            // A beat before reality answers — the pause is the product.
            withAnimation(reduceMotion ? nil : .spring(duration: 0.7, bounce: 0.25).delay(0.45)) {
                revealed = true
            }
            Haptics.medium()
        }
    }
}

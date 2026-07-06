import SwiftUI

struct DoneView: View {
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("no hiding\nnow.")
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .foregroundStyle(Color.ink)
                        .lineSpacing(4)
                        .opacity(visible ? 1 : 0)
                        .offset(y: visible || reduceMotion ? 0 : 16)
                        .animation(entrance(delay: 0), value: visible)

                    Text("every minute tracked.\nshown in your island.\nnudged when it matters.")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Color.inkFaint)
                        .lineSpacing(6)
                        .opacity(visible ? 1 : 0)
                        .animation(entrance(delay: 0.4), value: visible)
                }
                .padding(.horizontal, 32)

                Spacer()

                Button(action: onDone) {
                    Text("let's go")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
                .opacity(visible ? 1 : 0)
                .animation(entrance(delay: 0.9), value: visible)
            }
        }
        .onAppear {
            visible = true
            // The one heavy haptic in the whole app.
            Haptics.heavy()
        }
    }

    private func entrance(delay: Double) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.6).delay(delay)
    }
}

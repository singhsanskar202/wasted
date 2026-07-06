import SwiftUI

struct HookView: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    private let lines: [(String, Double)] = [
        ("the average person", 0.0),
        ("spends 4 hours", 0.3),
        ("on their phone.", 0.6),
        ("every. single. day.", 1.1),
        ("that's 60 days a year.", 1.8),
        ("gone.", 2.6),
    ]

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(lines.indices, id: \.self) { i in
                        let (text, delay) = lines[i]
                        Text(text)
                            .font(.system(size: text == "gone." ? 42 : 28, weight: text == "gone." ? .bold : .light, design: .serif))
                            .italic(text == "gone.")
                            .foregroundStyle(text == "gone." ? Color.ink : Color.ink.opacity(0.85))
                            .opacity(visible ? 1 : 0)
                            .offset(y: visible || reduceMotion ? 0 : 12)
                            .animation(entrance(delay: delay), value: visible)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()

                Button(action: advance) {
                    Text("i want to change this")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.inkFaint)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 52)
                }
                .opacity(visible ? 1 : 0)
                .animation(entrance(delay: 3.2), value: visible)
            }
        }
        .onAppear { visible = true }
        .onTapGesture { advance() }
    }

    private func advance() {
        Haptics.light()
        onContinue()
    }

    private func entrance(delay: Double) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.6).delay(delay)
    }
}

import SwiftUI
import UserNotifications

struct NotificationPermissionView: View {
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    private let blocks: [(String, Double)] = [
        ("you're going to tap\n\"don't allow\"\naren't you.", 0.0),
        ("that's literally why\nyou need this app.", 0.8),
        ("a nudge every 30 minutes\nyou keep scrolling.\none receipt at night.\nnothing else.", 1.6),
    ]

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 28) {
                    ForEach(blocks.indices, id: \.self) { i in
                        let (text, delay) = blocks[i]
                        Text(text)
                            .font(.system(size: i == 0 ? 26 : 18, weight: i == 0 ? .semibold : .light))
                            .foregroundStyle(i == 0 ? Color.ink : Color.ink.opacity(0.75))
                            .lineSpacing(6)
                            .opacity(visible ? 1 : 0)
                            .offset(y: visible || reduceMotion ? 0 : 10)
                            .animation(entrance(delay: delay), value: visible)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        requestNotificationPermission()
                    } label: {
                        Text("allow notifications")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: onDone) {
                        Text("(prove me wrong)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.ink.opacity(0.3))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
                .opacity(visible ? 1 : 0)
                .animation(entrance(delay: 2.4), value: visible)
            }
        }
        .onAppear { visible = true }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                granted ? Haptics.success() : Haptics.warning()
                onDone()
            }
        }
    }

    private func entrance(delay: Double) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.5).delay(delay)
    }
}

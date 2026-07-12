import SwiftUI
import UserNotifications

// The last screen. Asks for notifications AND closes the loop — DoneView ("no
// hiding now. / every minute tracked. / let's go.") used to do the closing in a
// screen of its own, which confirmed something the user had just done and then
// charged them a tap to see the thing they came for. The home screen showing 0m,
// and the island lighting up the first time they open Instagram, IS the
// confirmation. So this screen does both and drops them home.
//
// The priming copy stays deliberately: notification permission is one-shot on
// iOS — deny it and the app can never ask again — so explaining the cadence
// BEFORE the system dialog is what protects the grant rate. This is the one
// place in onboarding where an extra beat of copy pays for itself.
struct NotificationPermissionView: View {
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    private let blocks: [(String, Double)] = [
        ("you're going to tap\n\"don't allow\"\naren't you.", 0.0),
        ("that's literally why\nyou need this app.", 0.8),
        // Was "a nudge every 30 minutes" — the app now nudges every 15
        // (NudgeGate.stepMinutes), so onboarding was promising a cadence the
        // product broke on day one.
        ("a nudge every 15 minutes\nyou keep scrolling.\none receipt at night.\nnothing else.", 1.6),
    ]

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 28) {
                    ForEach(blocks.indices, id: \.self) { index in
                        let (text, delay) = blocks[index]
                        Text(text)
                            .font(.system(size: index == 0 ? 26 : 18, weight: index == 0 ? .semibold : .light))
                            .foregroundStyle(index == 0 ? Color.ink : Color.ink.opacity(0.75))
                            .lineSpacing(6)
                            .opacity(visible ? 1 : 0)
                            .offset(y: visible || reduceMotion ? 0 : 10)
                            .animation(entrance(delay: delay), value: visible)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 16) {
                    Button(action: requestNotificationPermission) {
                        Text("allow notifications")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        Haptics.light()
                        onDone()
                    } label: {
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                // One-shot on iOS: if this is denied the app can never ask again,
                // and every nudge and receipt silently goes nowhere for the
                // lifetime of the install. Worth knowing which users that is.
                if granted {
                    EventLog.log(.onboarding, "notifications GRANTED")
                } else {
                    EventLog.error(.onboarding, "notifications DENIED — nudges and receipts will never be seen. \(error?.localizedDescription ?? "")")
                }
                // The heaviest haptic in the app used to land on DoneView. It
                // lands here instead — this is the moment the mirror switches on.
                granted ? Haptics.heavy() : Haptics.warning()
                onDone()
            }
        }
    }

    private func entrance(delay: Double) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.5).delay(delay)
    }
}

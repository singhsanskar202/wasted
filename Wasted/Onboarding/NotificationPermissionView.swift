import SwiftUI
import UserNotifications

struct NotificationPermissionView: View {
    let onDone: () -> Void

    @State private var visible = false

    private let blocks: [(String, Double)] = [
        ("you're going to tap\n\"don't allow\"\naren't you.", 0.0),
        ("that's literally why\nyou need this app.", 0.8),
        ("awareness doesn't\nhappen inside an app.", 1.6),
        ("it happens when your\nphone buzzes at 10pm\nand you realise you've\nbeen scrolling for an hour.", 2.2),
        ("that's all we do.\ntwice a day.\nnothing else.", 3.2),
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        Spacer().frame(height: 80)

                        ForEach(blocks.indices, id: \.self) { i in
                            let (text, delay) = blocks[i]
                            Text(text)
                                .font(.system(
                                    size: i == 0 ? 26 : (i == 4 ? 20 : 18),
                                    weight: i == 0 ? .semibold : .light
                                ))
                                .foregroundStyle(i == 0 ? Color.white : Color.white.opacity(0.75))
                                .lineSpacing(6)
                                .opacity(visible ? 1 : 0)
                                .offset(y: visible ? 0 : 10)
                                .animation(.easeOut(duration: 0.5).delay(delay), value: visible)
                        }

                        Spacer().frame(height: 120)
                    }
                    .padding(.horizontal, 32)
                }

                VStack(spacing: 16) {
                    Button {
                        requestNotificationPermission()
                    } label: {
                        Text("allow notifications")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: onDone) {
                        Text("(prove me wrong)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
                .opacity(visible ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(3.8), value: visible)
            }
        }
        .onAppear { visible = true }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.async { onDone() }
        }
    }
}

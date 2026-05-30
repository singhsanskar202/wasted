import FamilyControls
import SwiftUI

struct AppGridView: View {
    struct AppInfo {
        let id: String
        let name: String
        let symbol: String
        let color: Color
        let lightIcon: Bool
    }

    @State private var visuallySelected: Set<String> = []
    @State private var showingPicker = false
    @State private var selection = FamilyActivitySelection()

    let onSelected: (FamilyActivitySelection) -> Void

    private let apps: [AppInfo] = [
        AppInfo(id: "instagram",  name: "Instagram",  symbol: "camera.fill",              color: Color(red: 0.88, green: 0.19, blue: 0.42), lightIcon: false),
        AppInfo(id: "tiktok",     name: "TikTok",     symbol: "music.note",               color: Color(red: 0.10, green: 0.10, blue: 0.10), lightIcon: false),
        AppInfo(id: "youtube",    name: "YouTube",    symbol: "play.rectangle.fill",      color: Color(red: 1.00, green: 0.00, blue: 0.00), lightIcon: false),
        AppInfo(id: "x",          name: "X",          symbol: "xmark",                    color: Color(red: 0.10, green: 0.10, blue: 0.10), lightIcon: false),
        AppInfo(id: "snapchat",   name: "Snapchat",   symbol: "camera.viewfinder",        color: Color(red: 1.00, green: 0.98, blue: 0.00), lightIcon: true),
        AppInfo(id: "facebook",   name: "Facebook",   symbol: "person.2.fill",            color: Color(red: 0.09, green: 0.46, blue: 0.95), lightIcon: false),
        AppInfo(id: "whatsapp",   name: "WhatsApp",   symbol: "message.fill",             color: Color(red: 0.15, green: 0.73, blue: 0.37), lightIcon: false),
        AppInfo(id: "reddit",     name: "Reddit",     symbol: "arrow.up.circle.fill",     color: Color(red: 1.00, green: 0.27, blue: 0.00), lightIcon: false),
        AppInfo(id: "telegram",   name: "Telegram",   symbol: "paperplane.fill",          color: Color(red: 0.15, green: 0.65, blue: 0.90), lightIcon: false),
        AppInfo(id: "discord",    name: "Discord",    symbol: "headphones",               color: Color(red: 0.35, green: 0.40, blue: 0.95), lightIcon: false),
        AppInfo(id: "threads",    name: "Threads",    symbol: "at",                       color: Color(red: 0.10, green: 0.10, blue: 0.10), lightIcon: false),
        AppInfo(id: "linkedin",   name: "LinkedIn",   symbol: "briefcase.fill",           color: Color(red: 0.04, green: 0.40, blue: 0.76), lightIcon: false),
        AppInfo(id: "twitch",     name: "Twitch",     symbol: "play.tv.fill",             color: Color(red: 0.57, green: 0.27, blue: 1.00), lightIcon: false),
        AppInfo(id: "pinterest",  name: "Pinterest",  symbol: "pin.fill",                 color: Color(red: 0.90, green: 0.00, blue: 0.14), lightIcon: false),
        AppInfo(id: "bereal",     name: "BeReal",     symbol: "camera.on.rectangle.fill", color: Color(red: 0.12, green: 0.12, blue: 0.12), lightIcon: false),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Text("Which of these\nown your attention?")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.horizontal, 24)

            Text("BE HONEST.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(white: 0.25))
                .tracking(2)
                .padding(.top, 8)
                .padding(.bottom, 24)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                spacing: 16
            ) {
                ForEach(apps, id: \.id) { app in
                    AppCell(app: app, isSelected: visuallySelected.contains(app.id))
                        .onTapGesture { toggle(app.id) }
                }
            }
            .padding(.horizontal, 24)

            Text(visuallySelected.isEmpty ? " " : "\(visuallySelected.count) selected")
                .font(.caption)
                .foregroundStyle(Color(white: 0.3))
                .padding(.top, 14)

            Spacer()

            Button {
                Task {
                    await ActivityScheduler.shared.requestAuthorization()
                    showingPicker = true
                }
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(visuallySelected.isEmpty ? Color(white: 0.25) : .black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(visuallySelected.isEmpty ? Color(white: 0.1) : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(visuallySelected.isEmpty)
            .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
            .onChange(of: selection) { _, newValue in
                guard !newValue.applications.isEmpty else { return }
                onSelected(newValue)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private func toggle(_ id: String) {
        if visuallySelected.contains(id) {
            visuallySelected.remove(id)
        } else {
            visuallySelected.insert(id)
        }
    }
}

private struct AppCell: View {
    let app: AppGridView.AppInfo
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(app.color)
                    .frame(width: 56, height: 56)

                Image(systemName: app.symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(app.lightIcon ? Color.black : Color.white)
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white, lineWidth: 2.5)
                        .frame(width: 56, height: 56)
                }
            }

            Text(app.name)
                .font(.system(size: 9))
                .foregroundStyle(Color(white: 0.5))
                .lineLimit(1)
        }
        .opacity(isSelected ? 1.0 : 0.25)
    }
}

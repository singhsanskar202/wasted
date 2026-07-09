import SwiftUI

struct GuessView: View {
    let onContinue: () -> Void

    private struct Choice: Identifiable {
        let id = UUID()
        let label: String
        let seconds: Int
    }

    private let choices: [Choice] = [
        Choice(label: "under 1h", seconds: 3600),
        Choice(label: "2h", seconds: 7200),
        Choice(label: "3h", seconds: 10800),
        Choice(label: "4h", seconds: 14400),
        Choice(label: "5h or more", seconds: 18000),
    ]

    @State private var selected: Int? = nil

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("how much do you\nscroll a day?")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .lineSpacing(4)

                    Text("be honest. nobody's watching.")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Color.inkFaint)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 36)

                VStack(spacing: 10) {
                    ForEach(choices) { choice in
                        Button {
                            Haptics.selection()
                            selected = choice.seconds
                        } label: {
                            Text(choice.label)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(selected == choice.seconds ? .black : Color.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 18)
                                .background(selected == choice.seconds ? Color.ink : Color.ink.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                Button {
                    Haptics.light()
                    saveGuess()
                    onContinue()
                } label: {
                    Text("lock it in")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(selected == nil ? .gray : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(selected == nil ? Color.ink.opacity(0.1) : Color.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(selected == nil)
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }

    private func saveGuess() {
        guard
            let seconds = selected,
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID)
        else { return }
        defaults.set(seconds, forKey: AppGroupKeys.dailyGuessKey)
    }
}

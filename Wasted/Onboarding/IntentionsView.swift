import SwiftUI

// "i keep meaning to: …" — the one sentence the user finishes, and the source
// of the sharpest nudge copy in the app (see NudgeCopy.personalLines). The
// screen earns its onboarding slot the same way Guess does: it produces state
// nothing else can produce, in the user's own words, before any data exists
// to contaminate it.
//
// No advice is promised and none is given. The copy tells the user exactly
// what the mirror will do with their words: repeat them.
struct IntentionsView: View {
    let onContinue: () -> Void
    private let store = UsageStore()

    var body: some View {
        IntentionsEditor(
            initial: store.intentions(),
            ctaTitle: "hold me to it",
            allowsSkip: true
        ) { intentions in
            store.setIntentions(intentions)
            EventLog.log(.onboarding, "intentions saved: \(intentions.count)")
            onContinue()
        }
    }
}

// The editor itself — reused by the home footer's "you said" row, so the
// sentence can be rewritten as life changes.
struct IntentionsEditor: View {
    let initial: [String]
    let ctaTitle: String
    let allowsSkip: Bool
    let onDone: ([String]) -> Void

    @State private var chosen: [String] = []
    @State private var custom: String = ""

    private let maxIntentions = 3

    // Broad enough that most lives find themselves in one tap; the field
    // catches the ukuleles and the shayari.
    private let suggestions = [
        "read more",
        "play an instrument",
        "work out",
        "write",
        "learn something new",
        "sleep earlier",
    ]

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("i keep meaning to…")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .lineSpacing(4)

                    Text("finish the sentence. pick up to three.\nthe mirror will only ever repeat your own words.")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Color.inkFaint)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 30)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        // Custom entries first — the user's exact words outrank
                        // our suggestions.
                        ForEach(chosen.filter { !suggestions.contains($0) }, id: \.self) { phrase in
                            row(phrase, isOn: true) { toggle(phrase) }
                        }
                        ForEach(suggestions, id: \.self) { phrase in
                            row(phrase, isOn: chosen.contains(phrase)) { toggle(phrase) }
                        }

                        TextField("or say it your way — “play the ukulele”", text: $custom)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Color.ink)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 18)
                            .background(Color.ink.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .submitLabel(.done)
                            .onSubmit(addCustom)
                    }
                    .padding(.horizontal, 32)
                }
                .frame(maxHeight: 380)

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        Haptics.light()
                        addCustom()
                        onDone(chosen)
                    } label: {
                        Text(ctaTitle)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(chosen.isEmpty && custom.isEmpty ? .gray : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(chosen.isEmpty && custom.isEmpty ? Color.ink.opacity(0.1) : Color.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    // Onboarding: an empty sentence takes the skip path, so
                    // the CTA waits for words. The editor has no skip — there,
                    // saving empty IS the way to clear the sentence.
                    .disabled(chosen.isEmpty && custom.isEmpty && allowsSkip)

                    if allowsSkip {
                        Button {
                            Haptics.light()
                            onDone(chosen)
                        } label: {
                            Text("skip")
                                .font(.system(size: 14, weight: .light))
                                .foregroundStyle(Color.ink.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 44)
            }
        }
        .onAppear { chosen = initial }
    }

    private func row(_ phrase: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(phrase)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isOn ? .black : Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .padding(.horizontal, 18)
                .background(isOn ? Color.ink : Color.ink.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isOn && chosen.count >= maxIntentions)
        .opacity(!isOn && chosen.count >= maxIntentions ? 0.4 : 1)
    }

    private func toggle(_ phrase: String) {
        if let index = chosen.firstIndex(of: phrase) {
            chosen.remove(at: index)
        } else if chosen.count < maxIntentions {
            chosen.append(phrase)
        }
    }

    private func addCustom() {
        guard
            let phrase = NudgeCopy.canonicalIntention(custom),
            !chosen.contains(phrase),
            chosen.count < maxIntentions
        else { return }
        chosen.append(phrase)
        custom = ""
    }
}

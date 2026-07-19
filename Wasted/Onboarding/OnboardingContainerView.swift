import FamilyControls
import SwiftUI

// Four screens. It was seven.
//
// Three of the seven produced no state at all — they existed only to persuade:
//   · DifferentiationView ("this won't block anything") — a full screen, placed
//     TWO screens before the fear it answers. Folded into AppPickerView's
//     subhead, where someone is actually being asked to hand over Screen Time
//     access and is wondering whether their phone is about to be locked.
//   · DoneView ("no hiding now") — confirmed what the user had just done, then
//     charged a tap for the privilege. The home screen at 0m, and the island
//     lighting up on the first scroll, are the real confirmation.
//   · PermissionView — split from the picker only because familyActivityPicker
//     can't list apps before auth. That's a technical dependency, not a reason
//     to spend a screen. AppPickerView now does auth and picking in one tap.
//
// The five that remain each earn their place:
//   0. Hook       — the argument. Nobody grants Screen Time access to an app
//                   they don't yet care about.
//   1. Guess      — the ONLY input to the Reality Check. Asked before any data
//                   is shown, so the guess stays uncontaminated.
//   2. Intentions — "i keep meaning to: …", the only input to the personal
//                   nudge lines ("you said: play the ukulele."). Earns its slot
//                   the same way Guess does: state nothing else can produce, in
//                   the user's own words. Skippable.
//   3. Picker     — FamilyControls auth + the tracked selection. Without these
//                   the app cannot function at all.
//   4. Nudges     — notification auth. One-shot on iOS (deny once and the app
//                   can never ask again), so the priming copy protects the
//                   grant rate — and it lands stronger two taps after the user
//                   wrote the words the nudges will carry.
struct OnboardingContainerView: View {
    @State private var step = 0
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            switch step {
            case 0:
                HookView { advance() }
                    .transition(.opacity)
            case 1:
                GuessView { advance() }
                    .transition(.opacity)
            case 2:
                IntentionsView { advance() }
                    .transition(.opacity)
            case 3:
                AppPickerView { selection in
                    EventLog.log(.onboarding, "apps selected: \(selection.applications.count)")
                    ActivityScheduler.shared.startMonitoring(selection: selection)
                    advance()
                }
                .transition(.opacity)
            default:
                NotificationPermissionView {
                    EventLog.log(.onboarding, "onboarding COMPLETE")
                    onComplete()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: step)
        .onAppear { EventLog.log(.onboarding, "onboarding started") }
    }

    private func advance() {
        step += 1
        EventLog.log(.onboarding, "step \(step)")
    }
}

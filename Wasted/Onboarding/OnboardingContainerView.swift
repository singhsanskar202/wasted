import FamilyControls
import SwiftUI

// Screen Time permission sits before the app picker by necessity:
// familyActivityPicker can't list apps until FamilyControls auth is granted.
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
                DifferentiationView { advance() }
                    .transition(.opacity)
            case 3:
                PermissionView { advance() }
                    .transition(.opacity)
            case 4:
                AppPickerView { selection in
                    ActivityScheduler.shared.startMonitoring(selection: selection)
                    advance()
                }
                .transition(.opacity)
            case 5:
                NotificationPermissionView { advance() }
                    .transition(.opacity)
            default:
                DoneView { onComplete() }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: step)
    }

    private func advance() {
        step += 1
    }
}

import FamilyControls
import SwiftUI

struct OnboardingContainerView: View {
    @State private var step = 0
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch step {
            case 0:
                HookView { advance() }
                    .transition(.opacity)
            case 1:
                PermissionView { advance() }
                    .transition(.opacity)
            case 2:
                NotificationPermissionView { advance() }
                    .transition(.opacity)
            case 3:
                AppPickerView { selection in
                    ActivityScheduler.shared.startMonitoring(selection: selection)
                    advance()
                }
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

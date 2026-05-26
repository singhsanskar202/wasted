import FamilyControls
import SwiftUI

struct OnboardingContainerView: View {
    @State private var step = 0
    let onComplete: () -> Void

    var body: some View {
        switch step {
        case 0:
            PermissionView { step = 1 }
        case 1:
            AppPickerView { selection in
                ActivityScheduler.shared.startMonitoring(selection: selection)
                step = 2
            }
        default:
            DoneView { onComplete() }
        }
    }
}

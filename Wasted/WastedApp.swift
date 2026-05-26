import SwiftUI

@main
struct WastedApp: App {
    @AppStorage("onboarding_complete") private var onboardingComplete = false

    var body: some Scene {
        WindowGroup {
            #if targetEnvironment(simulator)
            HomeView()
            #else
            if onboardingComplete {
                HomeView()
            } else {
                OnboardingContainerView {
                    onboardingComplete = true
                }
            }
            #endif
        }
    }
}

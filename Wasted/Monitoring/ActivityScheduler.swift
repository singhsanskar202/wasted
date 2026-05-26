import Combine
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

@MainActor
final class ActivityScheduler: ObservableObject {
    static let shared = ActivityScheduler()

    private let center = DeviceActivityCenter()

    @Published var isAuthorized = false

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    // Call this whenever the user's FamilyActivitySelection changes.
    // ApplicationToken.bundleIdentifier is private in Apple's API —
    // we use a stable sequential index as the event key instead.
    func startMonitoring(selection: FamilyActivitySelection) {
        center.stopMonitoring()
        guard !selection.applications.isEmpty else { return }

        let tokens = selection.applications.sorted {
            $0.localizedDisplayName ?? "" < $1.localizedDisplayName ?? ""
        }

        var displayNames: [String: String] = [:]
        for (index, token) in tokens.enumerated() {
            displayNames["\(index)"] = token.localizedDisplayName ?? "App \(index)"
        }
        storeDisplayNames(displayNames)

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        let thresholds = Array(stride(from: 5, through: 480, by: 5))

        for (index, app) in tokens.enumerated() {
            guard let appToken = app.token else { continue }
            for minutes in thresholds {
                let name = DeviceActivityEvent.Name("\(index):\(minutes)")
                events[name] = DeviceActivityEvent(
                    applications: [appToken],
                    threshold: DateComponents(minute: minutes)
                )
            }
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        try? center.startMonitoring(.wastedDaily, during: schedule, events: events)
    }

    func stopMonitoring() {
        center.stopMonitoring()
    }

    // MARK: - Private

    private func storeDisplayNames(_ names: [String: String]) {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = try? JSONEncoder().encode(names)
        else { return }
        defaults.set(data, forKey: "display_names")
    }
}

extension DeviceActivityName {
    static let wastedDaily = DeviceActivityName("wasted.daily")
}

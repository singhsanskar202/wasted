import Combine
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import SwiftUI

@MainActor
final class ActivityScheduler: ObservableObject {
    static let shared = ActivityScheduler()

    private let center = DeviceActivityCenter()

    @Published var isAuthorized = false

    // Fidelity tapers as the day goes on: 1-min steps for the first 5 minutes
    // (the Island should react fast — that's the whole product), 5-min steps
    // through 2h, widening to 15-min steps past 4h, since a diminishing-fidelity
    // tail keeps the per-app event count off DeviceActivity's undocumented cap.
    static let thresholdMinutes: [Int] =
        Array(stride(from: 1, through: 5, by: 1)) +
        Array(stride(from: 10, through: 120, by: 5)) +
        Array(stride(from: 130, through: 240, by: 10)) +
        Array(stride(from: 255, through: 480, by: 15))

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
    // Tracked-app count is deliberately unbounded; a future paywall would gate
    // selection size here.
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
        saveIcons(for: tokens)

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        for (index, app) in tokens.enumerated() {
            guard let appToken = app.token else { continue }
            for minutes in Self.thresholdMinutes {
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

    private func saveIcons(for apps: [Application]) {
        guard let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID) else { return }
        for app in apps {
            guard let token = app.token,
                  let name = app.localizedDisplayName,
                  !name.isEmpty else { continue }
            let label = Label(token)
            let renderer = ImageRenderer(content: label.frame(width: 60, height: 60))
            renderer.scale = 2.0
            guard let uiImage = renderer.uiImage,
                  let pngData = uiImage.pngData() else { continue }
            defaults.set(pngData, forKey: AppGroupKeys.appIconKey(for: name))
        }
    }

    private func storeDisplayNames(_ names: [String: String]) {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = try? JSONEncoder().encode(names)
        else { return }
        defaults.set(data, forKey: AppGroupKeys.displayNamesKey)
    }
}

extension DeviceActivityName {
    static let wastedDaily = DeviceActivityName("wasted.daily")
}

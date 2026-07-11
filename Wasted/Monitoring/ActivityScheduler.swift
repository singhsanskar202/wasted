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

    // Bump whenever the shape of the event registration changes (threshold
    // series, event flags…). Installed devices keep running the OLD schedule
    // until startMonitoring re-runs — this re-registers on next foreground so
    // an update takes effect without the user re-picking their apps.
    static let registrationSchemaVersion = 2
    private static let registrationVersionKey = "monitoring_schema_version"

    func refreshRegistrationIfNeeded() {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            defaults.integer(forKey: Self.registrationVersionKey) != Self.registrationSchemaVersion,
            let data = defaults.data(forKey: AppGroupKeys.trackedSelectionKey),
            let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data),
            !selection.applications.isEmpty
        else { return }
        startMonitoring(selection: selection)
    }

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

        // Deterministic order: localizedDisplayName is nil on-device, so a
        // name sort is unstable and the index↔app mapping would drift between
        // launches. Sort by encoded token bytes instead — same set always
        // yields the same indices, keeping events, display names, and the
        // token map in agreement.
        let tokens = selection.applications.sorted { a, b in
            Self.tokenSortKey(a) < Self.tokenSortKey(b)
        }

        var displayNames: [String: String] = [:]
        var tokensByIndex: [String: ApplicationToken] = [:]
        for (index, app) in tokens.enumerated() {
            displayNames["\(index)"] = app.localizedDisplayName ?? "App \(index)"
            if let token = app.token { tokensByIndex["\(index)"] = token }
        }
        persistSelection(selection)
        storeDisplayNames(displayNames)
        storeTokens(tokensByIndex)

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        // includesPastActivity everywhere: startMonitoring can re-run mid-day
        // (selection edit, schema refresh) and thresholds must keep counting
        // the whole day's usage, not restart from zero. Replayed events are
        // deduped downstream (delta/high-water-mark checks in the extension).
        for (index, app) in tokens.enumerated() {
            guard let appToken = app.token else { continue }
            for minutes in Self.thresholdMinutes {
                let name = DeviceActivityEvent.Name("\(index):\(minutes)")
                events[name] = DeviceActivityEvent(
                    applications: [appToken],
                    threshold: DateComponents(minute: minutes),
                    includesPastActivity: true
                )
            }
        }

        // Combined series over ALL tracked apps — the island's minute-level
        // heartbeat (see AppGroupKeys.totalThresholdMinutes).
        let allTokens = Set(tokens.compactMap(\.token))
        for minutes in AppGroupKeys.totalThresholdMinutes {
            let name = DeviceActivityEvent.Name("\(AppGroupKeys.totalEventPrefix):\(minutes)")
            events[name] = DeviceActivityEvent(
                applications: allTokens,
                threshold: DateComponents(minute: minutes),
                includesPastActivity: true
            )
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        // DeviceActivity has an undocumented cap on registered events and
        // startMonitoring fails as a whole — never swallow that silently or
        // the app records nothing all day.
        do {
            try center.startMonitoring(.wastedDaily, during: schedule, events: events)
            LiveActivityManager.log("monitoring started, \(events.count) events")
            // Only a successful registration is current — on failure the
            // version stays stale so the next foreground retries.
            UserDefaults(suiteName: AppGroupKeys.appGroupID)?
                .set(Self.registrationSchemaVersion, forKey: Self.registrationVersionKey)
        } catch {
            LiveActivityManager.log("startMonitoring FAILED (\(events.count) events): \(error)")
        }
    }

    func stopMonitoring() {
        center.stopMonitoring()
    }

    // MARK: - Private

    // Persist the raw selection so tracked apps survive relaunches and can be
    // rebuilt/re-picked. Previously onboarding's one-time startMonitoring was
    // the only place it was handled and nothing was saved.
    private func persistSelection(_ selection: FamilyActivitySelection) {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = try? JSONEncoder().encode(selection)
        else { return }
        defaults.set(data, forKey: AppGroupKeys.trackedSelectionKey)
    }

    private func storeTokens(_ tokensByIndex: [String: ApplicationToken]) {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = try? JSONEncoder().encode(tokensByIndex)
        else { return }
        defaults.set(data, forKey: AppGroupKeys.appTokensKey)
    }

    private static func tokenSortKey(_ app: Application) -> String {
        guard let token = app.token, let data = try? JSONEncoder().encode(token) else { return "" }
        return data.base64EncodedString()
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

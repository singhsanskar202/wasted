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

    // Bump whenever the shape of the event registration changes (threshold
    // series, event flags…). Installed devices keep running the OLD schedule
    // until startMonitoring re-runs — this re-registers on next foreground so
    // an update takes effect without the user re-picking their apps.
    static let registrationSchemaVersion = 3

    // Which plan actually registered, for diagnostics — the cap is undocumented,
    // so the only way to know where it bites is to look at what survived.
    static let activePlanKey = "monitoring_active_plan"
    private static let registrationVersionKey = "monitoring_schema_version"

    func refreshRegistrationIfNeeded() {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = defaults.data(forKey: AppGroupKeys.trackedSelectionKey),
            let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data),
            !selection.applications.isEmpty
        else { return }

        let schemaStale = defaults.integer(forKey: Self.registrationVersionKey) != Self.registrationSchemaVersion

        // REVIVE A DEAD MONITOR. A repeating DeviceActivity interval can end
        // mid-day — a device reboot, or iOS evicting the monitor under memory
        // pressure — and iOS will NOT restart it until the next midnight. The
        // whole day then freezes: no thresholds fire, the number sits still.
        // (Device log 2026-07-27: intervalDidEnd fired at 06:46, and the count
        // stuck at 1m for the rest of the day. The user opened the app three
        // times afterward and nothing recovered, because we only re-registered
        // on a schema change.) So whenever our activity is no longer among the
        // ones being monitored, re-register on foreground. Because every event
        // uses includesPastActivity, this also BACKFILLS the usage missed while
        // the monitor was down — the day heals instead of staying lost.
        let monitoringDown = !center.activities.contains(.wastedDaily)

        guard schemaStale || monitoringDown else { return }

        if monitoringDown && !schemaStale {
            EventLog.error(.monitor, "monitor was DOWN on foreground — interval ended early (reboot/eviction); re-registering to revive + backfill the day")
        }
        startMonitoring(selection: selection)
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
            EventLog.log(.onboarding, "FamilyControls authorization GRANTED (.individual)")
        } catch {
            isAuthorized = false
            // Without this the app records nothing, ever. It deserves a loud line.
            EventLog.error(.onboarding, "FamilyControls authorization DENIED: \(error)")
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

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        // Finest grid first, stepping down until one registers. startMonitoring
        // throws as a WHOLE if the event set exceeds DeviceActivity's
        // undocumented cap, and a throw means the day records nothing — so the
        // fallback isn't defensive padding, it's the difference between a
        // slightly coarser number and no number at all.
        let defaults = UserDefaults.wastedShared

        for plan in ThresholdPlan.ladder {
            let events = Self.events(for: plan, tokens: tokens)
            do {
                try center.startMonitoring(.wastedDaily, during: schedule, events: events)
                EventLog.log(.monitor, "monitoring STARTED plan=\(plan.name) events=\(events.count) apps=\(tokens.count)")

                // Only a successful registration is current — on failure the
                // version stays stale so the next foreground retries.
                defaults.set(Self.registrationSchemaVersion, forKey: Self.registrationVersionKey)
                defaults.set(plan.name, forKey: Self.activePlanKey)
                defaults.set(false, forKey: AppGroupKeys.trackingFailedKey)

                // The last-resort plan keeps the headline number alive by giving
                // up the per-app series — so nudges and the receipt breakdown are
                // gone. That's a real loss and the user is told, not left to
                // wonder why the nudges stopped.
                let degraded = !plan.tracksIndividualApps
                defaults.set(degraded, forKey: AppGroupKeys.trackingDegradedKey)
                if degraded {
                    EventLog.error(.monitor, "DEGRADED — per-app series dropped to fit the cap. no nudges, no receipt breakdown.")
                }
                return
            } catch {
                EventLog.error(.monitor, "plan=\(plan.name) REJECTED at \(events.count) events — DeviceActivity cap: \(error)")
                center.stopMonitoring()
            }
        }

        // Every plan rejected. Nothing is being recorded — and a number that
        // never moves is worse than an error, because the user might BELIEVE it.
        defaults.set(true, forKey: AppGroupKeys.trackingFailedKey)
        defaults.set(false, forKey: AppGroupKeys.trackingDegradedKey)
        EventLog.error(.monitor, "startMonitoring FAILED — every plan rejected. NOTHING IS BEING RECORDED.")
    }

    // includesPastActivity everywhere: startMonitoring can re-run mid-day
    // (selection edit, schema refresh) and thresholds must keep counting the
    // whole day's usage, not restart from zero. Replayed events are deduped
    // downstream (delta / high-water-mark checks in the extension).
    private static func events(
        for plan: ThresholdPlan,
        tokens: [Application]
    ) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        for (index, app) in tokens.enumerated() {
            guard let appToken = app.token else { continue }
            for minutes in plan.perApp {
                events[DeviceActivityEvent.Name("\(index):\(minutes)")] = DeviceActivityEvent(
                    applications: [appToken],
                    threshold: DateComponents(minute: minutes),
                    includesPastActivity: true
                )
            }
        }

        // Combined series over ALL tracked apps — the heartbeat behind the
        // widget, the island, and the home number.
        let allTokens = Set(tokens.compactMap(\.token))
        for minutes in plan.combined {
            events[DeviceActivityEvent.Name("\(AppGroupKeys.totalEventPrefix):\(minutes)")] = DeviceActivityEvent(
                applications: allTokens,
                threshold: DateComponents(minute: minutes),
                includesPastActivity: true
            )
        }

        return events
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

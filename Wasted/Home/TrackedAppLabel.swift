import FamilyControls
import ManagedSettings
import SwiftUI

// Renders a tracked app's real name inside the app's own UI. Label(token) is
// the only API that resolves the real name, and it only works live in the
// authorized foreground app — not as a String, not in a rasterized image, and
// not in the Live Activity's system renderer. Falls back to the stored generic
// "App N" when the token can't be loaded.
//
// Label(ApplicationToken) is greedy vertically; fixedSize on the vertical axis
// only pins it to its natural text height while still taking full width, so it
// lays out like a plain Text in a row (fixing both axes truncates the name).
//
// showsIcon renders the real app icon too (.titleAndIcon) — icons only resolve
// in-app, same as names; the fallback Text has no icon to show.
struct TrackedAppLabel: View {
    let index: String
    var fallback: String? = nil
    var showsIcon: Bool = false

    var body: some View {
        if let token = Self.token(for: index) {
            if showsIcon {
                Label(token)
                    .labelStyle(.titleAndIcon)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Label(token)
                    .labelStyle(.titleOnly)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(fallback ?? "App \(index)")
        }
    }

    static func token(for index: String) -> ApplicationToken? {
        guard
            let defaults = UserDefaults(suiteName: AppGroupKeys.appGroupID),
            let data = defaults.data(forKey: AppGroupKeys.appTokensKey),
            let tokens = try? JSONDecoder().decode([String: ApplicationToken].self, from: data)
        else { return nil }
        return tokens[index]
    }
}

import ActivityKit
import Foundation

// KEEPING THE ISLAND ALIVE WITHOUT THE APP BEING OPENED.
//
// A Live Activity can only be *started* from the foreground, and iOS kills it
// 8 hours after creation — so for a user who never opens Wasted (most users,
// most of the day, and everyone overnight), the island dies and stays dark.
// The island is the product's whole promise, so that is not acceptable.
//
// The one iOS mechanism that starts a Live Activity while the app is closed is
// PUSH-TO-START (iOS 17.2+): the app hands ActivityKit's push-to-start token to
// our server, and the server sends an APNs `start` push on a schedule (each
// morning, and every few hours) to (re)create the island. Each push resets the
// 8-hour clock, so the island is effectively always up.
//
// WHAT LEAVES THE DEVICE: only this opaque token. The start push carries a
// PLACEHOLDER total (0); the island's own view then pulls the real number from
// the App Group at render time (confirmedSeconds' max(pushed, pulled)). So the
// server never learns a second of the user's usage — it only knows an address
// to deliver an empty envelope to.
enum PushToStartRegistrar {

    // The server that stores tokens and sends the scheduled start pushes.
    // Empty = push-to-start disabled (the app still works; the island just
    // can't self-revive). Set this to the deployed Worker URL before shipping.
    static let serverBase = ""   // e.g. "https://wasted-push.<subdomain>.workers.dev"

    /// A stable per-install id so the server replaces a device's old token
    /// instead of hoarding duplicates. Not tied to any Apple identifier.
    private static var installID: String {
        let defaults = UserDefaults.wastedShared
        if let existing = defaults.string(forKey: "push_install_id") { return existing }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: "push_install_id")
        return fresh
    }

    /// APNs sandbox for Xcode builds, production for TestFlight/App Store — the
    /// server must hit the matching APNs host or every push 400s.
    private static var apnsEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    /// Long-lived: consumes the push-to-start token stream for the app's whole
    /// lifetime, uploading each new token. Launch once at startup.
    static func start() {
        guard !serverBase.isEmpty else {
            EventLog.log(.background, "push-to-start: no server configured — island cannot self-revive")
            return
        }
        guard #available(iOS 17.2, *) else {
            EventLog.log(.background, "push-to-start: needs iOS 17.2+ — unavailable here")
            return
        }
        Task {
            for await tokenData in Activity<TimeTrackerAttributes>.pushToStartTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                await upload(token: token)
            }
        }
    }

    private static func upload(token: String) async {
        guard let url = URL(string: serverBase + "/register") else { return }
        // Send the token only if it changed — the stream can re-emit the same one.
        let defaults = UserDefaults.wastedShared
        guard defaults.string(forKey: "push_last_token") != token else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "token": token,
            "install": installID,
            "env": apnsEnvironment,
        ])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200..<300).contains(code) {
                defaults.set(token, forKey: "push_last_token")
                EventLog.log(.background, "push-to-start token registered (env=\(apnsEnvironment))")
            } else {
                EventLog.error(.background, "push-to-start register FAILED http=\(code)")
            }
        } catch {
            EventLog.error(.background, "push-to-start register error: \(error.localizedDescription)")
        }
    }
}

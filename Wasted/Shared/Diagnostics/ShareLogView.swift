import SwiftUI
import UIKit

// The only way a tester's log ever reaches the developer.
//
// It is deliberately a share SHEET and not an upload. The app makes exactly one
// promise — "your data. your device. nobody else sees it." — and a diagnostics
// pipeline that quietly posts a person's screen-time history to a server would
// break that promise in the most literal way available. It would also make the
// "Data Not Collected" privacy label a lie.
//
// So the tester taps, reads the file if they want to, and chooses who receives
// it. Nothing leaves the phone that they didn't hand over themselves.
struct ShareLogSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// A URL that a `.sheet(item:)` can present.
struct ExportedLog: Identifiable {
    let id = UUID()
    let url: URL
}

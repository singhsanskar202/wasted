import SwiftUI
import UIKit

// Palette (§2): near-monochrome. `alarm` is reserved for "this number is bad" —
// never decorative.
extension Color {
    static let canvas   = Color(red: 0.039, green: 0.039, blue: 0.039)  // #0A0A0A
    static let ink      = Color(red: 0.961, green: 0.953, blue: 0.933)  // #F5F3EE
    static let inkFaint = ink.opacity(0.5)
    static let alarm    = Color(red: 1.0, green: 0.23, blue: 0.19)
}

// One haptic per meaningful moment, per the design table — no others.
enum Haptics {
    static func light()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()    { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy()     { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success()   { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning()   { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

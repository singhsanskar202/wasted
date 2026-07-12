import FamilyControls
import SwiftUI

// Screen Time authorisation AND app selection, in one screen.
//
// These used to be two: PermissionView ("first, we need to see the damage")
// then AppPickerView. That split existed for a technical reason —
// familyActivityPicker cannot list apps until FamilyControls auth is granted —
// but a technical dependency is not a reason to spend two screens and two taps
// on it. One button now requests auth and, the moment it lands, presents the
// picker. Same two grants, half the flow.
//
// The DifferentiationView ("this won't block anything. blockers get deleted.")
// was folded in here as the subhead rather than deleted. It was a full screen of
// its own, two screens BEFORE the moment it matters. The fear it answers — "is
// this app about to lock my phone?" — peaks exactly when someone is handing over
// Screen Time access. Reassurance belongs next to the fear, not two taps early.
struct AppPickerView: View {
    let onSelected: (FamilyActivitySelection) -> Void

    @State private var selection = FamilyActivitySelection()
    @State private var showingPicker = false
    @State private var wasDenied = false

    private var hasApps: Bool { !selection.applications.isEmpty }

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("which apps\nare stealing\nyour time?")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .lineSpacing(4)

                    Text(subhead)
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Color.inkFaint)
                        .lineSpacing(6)
                        .animation(.easeInOut, value: selection.applications.count)
                        .animation(.easeInOut, value: wasDenied)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 16) {
                    Button(action: choose) {
                        Text(hasApps ? "change selection" : "choose apps")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .familyActivityPicker(isPresented: $showingPicker, selection: $selection)
                    .onChange(of: selection.applications.count) { _, _ in
                        Haptics.selection()
                    }

                    Button {
                        Haptics.medium()
                        onSelected(selection)
                    } label: {
                        Text("i'm ready")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(hasApps ? .black : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(hasApps ? Color.ink : Color.ink.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!hasApps)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }

    private var subhead: String {
        if wasDenied {
            return "wasted can't see anything without\nscreen time access."
        }
        if hasApps {
            let count = selection.applications.count
            return "\(count) app\(count == 1 ? "" : "s") selected."
        }
        // The positioning line, at the moment it's actually load-bearing.
        return "this won't block them.\nwasted just keeps count —\na number you can't unsee."
    }

    // Auth first (the picker is empty without it), then straight into the picker
    // so the user never sees the seam.
    private func choose() {
        if ActivityScheduler.shared.isAuthorized {
            showingPicker = true
            return
        }
        Task {
            await ActivityScheduler.shared.requestAuthorization()
            if ActivityScheduler.shared.isAuthorized {
                Haptics.success()
                wasDenied = false
                showingPicker = true
            } else {
                Haptics.warning()
                wasDenied = true
            }
        }
    }
}

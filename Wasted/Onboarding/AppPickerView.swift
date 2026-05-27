import FamilyControls
import SwiftUI

struct AppPickerView: View {
    @State private var selection = FamilyActivitySelection()
    @State private var showingPicker = false
    let onSelected: (FamilyActivitySelection) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("which apps\nare stealing\nyour time?")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineSpacing(4)

                    Text(selection.applications.isEmpty
                         ? "be honest."
                         : "\(selection.applications.count) app\(selection.applications.count == 1 ? "" : "s") selected.")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(.white.opacity(0.5))
                        .animation(.easeInOut, value: selection.applications.count)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        showingPicker = true
                    } label: {
                        Text(selection.applications.isEmpty ? "choose apps" : "change selection")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .familyActivityPicker(isPresented: $showingPicker, selection: $selection)

                    Button {
                        onSelected(selection)
                    } label: {
                        Text("i'm ready")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(selection.applications.isEmpty ? .gray : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(selection.applications.isEmpty ? Color.white.opacity(0.1) : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(selection.applications.isEmpty)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }
}

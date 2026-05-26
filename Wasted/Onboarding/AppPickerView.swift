import FamilyControls
import SwiftUI

struct AppPickerView: View {
    @State private var selection = FamilyActivitySelection()
    @State private var showingPicker = false
    let onSelected: (FamilyActivitySelection) -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("Which apps do you\nwaste time on?")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text("\(selection.applications.count) app\(selection.applications.count == 1 ? "" : "s") selected")
                .font(.body)
                .foregroundStyle(.gray)

            Button {
                showingPicker = true
            } label: {
                Text(selection.applications.isEmpty ? "Choose Apps" : "Change Apps")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .familyActivityPicker(isPresented: $showingPicker, selection: $selection)

            Spacer()

            Button {
                onSelected(selection)
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(selection.applications.isEmpty ? .gray : .black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selection.applications.isEmpty ? Color.gray.opacity(0.3) : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(selection.applications.isEmpty)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

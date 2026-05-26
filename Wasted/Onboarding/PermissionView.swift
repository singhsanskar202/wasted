import SwiftUI

struct PermissionView: View {
    let onGranted: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("Wasted needs access\nto Screen Time.")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text("This lets the app see which apps you use\nand for how long — on your device only.")
                .font(.body)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                Task {
                    await ActivityScheduler.shared.requestAuthorization()
                    if ActivityScheduler.shared.isAuthorized { onGranted() }
                }
            } label: {
                Text("Allow Access")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

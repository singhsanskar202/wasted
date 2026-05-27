import SwiftUI

struct PermissionView: View {
    let onGranted: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("first,\nwe need to\nsee the damage.")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineSpacing(4)

                    Text("screen time access.\nyour data. your device.\nnobody else sees it.")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineSpacing(6)
                }
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        Task {
                            await ActivityScheduler.shared.requestAuthorization()
                            if ActivityScheduler.shared.isAuthorized { onGranted() }
                        }
                    } label: {
                        Text("allow access")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }
}

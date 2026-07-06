import SwiftUI

struct DifferentiationView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("this won't\nblock anything.")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .lineSpacing(4)

                    Text("blockers get deleted.\nstreaks get abandoned.\nwasted just keeps count —\na number you can't unsee.")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Color.inkFaint)
                        .lineSpacing(6)
                }
                .padding(.horizontal, 32)

                Spacer()

                Button {
                    Haptics.light()
                    onContinue()
                } label: {
                    Text("understood")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }
}

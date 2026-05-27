import SwiftUI

struct DoneView: View {
    let onDone: () -> Void

    @State private var visible = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 20) {
                    Text("no hiding\nnow.")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white)
                        .lineSpacing(4)
                        .opacity(visible ? 1 : 0)
                        .offset(y: visible ? 0 : 16)
                        .animation(.easeOut(duration: 0.6), value: visible)

                    Text("every minute tracked.\nshown in your island.\nnudged when it matters.")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineSpacing(6)
                        .opacity(visible ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.4), value: visible)
                }
                .padding(.horizontal, 32)

                Spacer()

                Button(action: onDone) {
                    Text("let's go")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
                .opacity(visible ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.9), value: visible)
            }
        }
        .onAppear { visible = true }
    }
}

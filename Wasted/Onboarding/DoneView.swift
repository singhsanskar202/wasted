import SwiftUI

struct DoneView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("You're set.")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("The Dynamic Island will show how long\nyou've been in each app today.\nNo hiding from it now.")
                .font(.body)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)

            Spacer()

            Button(action: onDone) {
                Text("Let's go")
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

import SwiftUI

struct SpineImageFullScreenView: View {
    let cgImage: CGImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            Image(decorative: cgImage, scale: 1.0)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.3))
            }
            .padding()
        }
    }
}

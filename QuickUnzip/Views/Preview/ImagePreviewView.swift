import SwiftUI

struct ImagePreviewView: View {
    let url: URL
    @State private var scale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                if let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width * scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1.0, min(value, 5.0))
                                }
                                .onEnded { value in
                                    withAnimation { scale = max(1.0, min(value, 5.0)) }
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation { scale = scale > 1 ? 1 : 2 }
                        }
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Unable to load image")
                            .foregroundColor(.secondary)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
    }
}

import SwiftUI

struct TextPreviewView: View {
    let url: URL
    @State private var content: String = ""
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                ScrollView {
                    Text(content)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
        .task {
            content = FileService.readTextFile(at: url) ?? "Unable to read file"
            isLoading = false
        }
    }
}

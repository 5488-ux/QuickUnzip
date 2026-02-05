import SwiftUI

struct FileDetailView: View {
    @EnvironmentObject var store: FileStore
    let item: FileItem
    @State private var showShareSheet = false

    var body: some View {
        VStack {
            if item.isImage {
                ImagePreviewView(url: item.url)
            } else if item.isText {
                TextPreviewView(url: item.url)
            } else if item.isPDF {
                PDFPreviewView(url: item.url)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: item.icon)
                        .font(.system(size: 64))
                        .foregroundColor(item.iconColor)
                    Text(item.name)
                        .font(.headline)
                    Text(item.formattedSize)
                        .foregroundColor(.secondary)
                    Text("Preview not available for this file type")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { store.toggleFavorite(item.url) }) {
                    Image(systemName: store.isFavorite(item.url) ? "star.fill" : "star")
                        .foregroundColor(store.isFavorite(item.url) ? .yellow : .gray)
                }
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [item.url])
        }
    }
}

import SwiftUI

struct FileDetailView: View {
    @EnvironmentObject var store: FileStore
    @Environment(\.dismiss) private var dismiss
    let item: FileItem
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false

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
                    Text("此文件类型暂不支持预览")
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
                Button(action: { showDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [item.url])
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                try? FileManager.default.removeItem(at: item.url)
                dismiss()
            }
        } message: {
            Text("确定要删除「\(item.name)」吗？此操作不可撤销。")
        }
    }
}

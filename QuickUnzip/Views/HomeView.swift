import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject var store: FileStore
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Import Card
                        importCard

                        // Recent Archives
                        if !store.archives.isEmpty {
                            sectionHeader("压缩包", icon: "doc.zipper")
                            ForEach(store.archives) { item in
                                ArchiveRow(item: item) {
                                    vm.extract(item.url, store: store)
                                } onDelete: {
                                    store.deleteArchive(item)
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Recent Extractions
                        if !store.recentExtractions.isEmpty {
                            sectionHeader("最近解压", icon: "clock")
                            ForEach(store.recentExtractions, id: \.self) { url in
                                NavigationLink(destination: FileListView(url: url)) {
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundColor(.blue)
                                            .font(.title3)
                                        Text(url.lastPathComponent)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Browse Extracted
                        NavigationLink(destination: FileListView(url: store.extractedURL, title: "全部文件")) {
                            HStack {
                                Image(systemName: "folder.badge.gearshape")
                                    .foregroundColor(Color(hex: "667eea"))
                                Text("浏览全部已解压文件")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 40)
                    }
                    .padding(.top)
                }

                // Extraction overlay
                if vm.isExtracting {
                    extractionOverlay
                }
            }
            .navigationTitle("快速解压")
            .sheet(isPresented: $vm.showFilePicker) {
                DocumentPicker { url in
                    vm.importAndExtract(url: url, store: store)
                }
            }
            .navigationDestination(isPresented: $vm.showExtractedFiles) {
                if let url = vm.extractedURL {
                    FileListView(url: url)
                }
            }
            .alert("错误", isPresented: $vm.showError) {
                Button("确定") {}
            } message: {
                Text(vm.errorMessage)
            }
        }
    }

    var importCard: some View {
        Button(action: { vm.showFilePicker = true }) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 72, height: 72)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                Text("导入压缩包")
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("支持 ZIP 格式文件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
        .padding(.horizontal)
    }

    var extractionOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView(value: vm.extractionProgress)
                    .progressViewStyle(.linear)
                    .tint(Color(hex: "667eea"))
                Text("解压中... \(Int(vm.extractionProgress * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .padding(40)
        }
    }

    func sectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "667eea"))
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

struct ArchiveRow: View {
    let item: FileItem
    let onExtract: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.zipper")
                .font(.title2)
                .foregroundColor(Color(hex: "667eea"))
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(item.formattedSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onExtract) {
                Text("解压")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

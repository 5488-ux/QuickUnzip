import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: FileStore
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirm = false
    @State private var clearTarget: ClearTarget = .none
    @State private var storageInfo: StorageInfo = StorageInfo()

    enum ClearTarget {
        case none, archives, extracted, all, cache
    }

    struct StorageInfo {
        var archiveSize: String = "计算中..."
        var extractedSize: String = "计算中..."
        var totalSize: String = "计算中..."
        var cacheSize: String = "计算中..."
    }

    var body: some View {
        NavigationStack {
            List {
                // Storage Section
                Section {
                    StorageRow(icon: "doc.zipper", title: "压缩包", size: storageInfo.archiveSize, color: Color(hex: "667eea"))
                    StorageRow(icon: "folder.fill", title: "已解压文件", size: storageInfo.extractedSize, color: Color(hex: "764ba2"))
                    StorageRow(icon: "internaldrive", title: "总占用", size: storageInfo.totalSize, color: Color(hex: "f093fb"))
                } header: {
                    Text("存储空间")
                }

                // Clear Data Section
                Section {
                    ClearButton(title: "清除所有压缩包", icon: "doc.zipper", color: .orange) {
                        clearTarget = .archives
                        showClearConfirm = true
                    }
                    .disabled(store.archives.isEmpty)

                    ClearButton(title: "清除已解压文件", icon: "folder.badge.minus", color: .orange) {
                        clearTarget = .extracted
                        showClearConfirm = true
                    }
                    .disabled(store.recentExtractions.isEmpty)

                    ClearButton(title: "清除所有数据", icon: "trash", color: .red) {
                        clearTarget = .all
                        showClearConfirm = true
                    }
                    .disabled(store.archives.isEmpty && store.recentExtractions.isEmpty)
                } header: {
                    Text("清理")
                } footer: {
                    Text("清除的文件无法恢复，请谨慎操作")
                }

                // Supported Formats Section
                Section {
                    FormatRow(format: "ZIP", description: "标准压缩格式", supported: true)
                    FormatRow(format: "7Z", description: "高压缩比格式", supported: true)
                    FormatRow(format: "RAR", description: "流行压缩格式", supported: true)
                    FormatRow(format: "TAR/GZ", description: "Unix 归档格式", supported: true)
                    FormatRow(format: "分卷压缩", description: ".001, .002 等", supported: true)
                } header: {
                    Text("支持的格式")
                }

                // Help & Support Section
                Section {
                    CustomerServiceRow()
                } header: {
                    Text("帮助与支持")
                }

                // About Section
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("3.1.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("构建")
                        Spacer()
                        Text("34")
                            .foregroundColor(.secondary)
                    }

                    NavigationLink {
                        UpdateLogView()
                    } label: {
                        HStack {
                            Text("更新日志")
                            Spacer()
                            Text("NEW")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "ff6b6b"))
                                .cornerRadius(4)
                        }
                    }

                    Link(destination: URL(string: "https://github.com/5488-ux/QuickUnzip")!) {
                        HStack {
                            Text("GitHub 仓库")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("确认清除", isPresented: $showClearConfirm) {
                Button("取消", role: .cancel) {}
                Button("清除", role: .destructive) {
                    performClear()
                }
            } message: {
                Text(clearMessage)
            }
            .onAppear {
                calculateStorage()
            }
        }
    }

    var clearMessage: String {
        switch clearTarget {
        case .archives:
            return "确定要删除所有压缩包吗？此操作不可撤销。"
        case .extracted:
            return "确定要删除所有已解压的文件吗？此操作不可撤销。"
        case .all:
            return "确定要删除所有数据吗？这将清除所有压缩包和已解压的文件。"
        case .cache:
            return "确定要清除缓存吗？"
        case .none:
            return ""
        }
    }

    func performClear() {
        switch clearTarget {
        case .archives:
            store.deleteAllArchives()
        case .extracted:
            store.deleteAllExtracted()
        case .all:
            store.deleteAllArchives()
            store.deleteAllExtracted()
        case .cache:
            store.clearCache()
        case .none:
            break
        }
        clearTarget = .none
        calculateStorage()
    }

    func calculateStorage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let (archives, extracted, total) = store.calculateStorageUsed()
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file

            DispatchQueue.main.async {
                storageInfo.archiveSize = formatter.string(fromByteCount: archives)
                storageInfo.extractedSize = formatter.string(fromByteCount: extracted)
                storageInfo.totalSize = formatter.string(fromByteCount: total)
                storageInfo.cacheSize = "0 B"
            }
        }
    }
}

struct StorageRow: View {
    let icon: String
    let title: String
    let size: String
    let color: Color

    var body: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .foregroundColor(color)
            }

            Text(title)
                .padding(.leading, 8)

            Spacer()

            Text(size)
                .foregroundColor(.secondary)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

struct ClearButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isEnabled ? color : .gray)
                Text(title)
                    .foregroundColor(isEnabled ? color : .gray)
                Spacer()
            }
        }
    }
}

struct FormatRow: View {
    let format: String
    let description: String
    let supported: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(format)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: supported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(supported ? .green : .red)
        }
        .padding(.vertical, 2)
    }
}

struct CustomerServiceRow: View {
    @StateObject private var api = CustomerServiceAPI.shared
    @State private var showCustomerService = false

    var body: some View {
        Button(action: {
            showCustomerService = true
        }) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)

                    Image(systemName: "headphones")
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("在线客服")
                        .foregroundColor(.primary)
                    Text("有问题随时咨询")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 8)

                Spacer()

                // 未读消息角标
                if api.unreadCount > 0 {
                    Text("\(api.unreadCount)")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(10)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showCustomerService) {
            CustomerServiceView()
        }
        .onAppear {
            Task {
                await api.checkUnreadCount()
            }
        }
    }
}

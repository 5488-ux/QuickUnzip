import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject var store: FileStore
    @StateObject private var vm = HomeViewModel()
    @State private var showSettings = false
    @State private var showDeleteConfirm = false
    @State private var deleteTarget: DeleteTarget = .none

    enum DeleteTarget {
        case none
        case allArchives
        case allExtracted
        case selected
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(hex: "f8f9ff"), Color(hex: "e8eeff")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header Stats Card
                        statsCard

                        // Import Card
                        importCard

                        // Quick Actions
                        quickActionsSection

                        // Archives Section
                        if !store.archives.isEmpty {
                            archivesSection
                        }

                        // Recent Extractions Section
                        if !store.recentExtractions.isEmpty {
                            recentExtractionsSection
                        }

                        // Browse All
                        browseAllCard

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                }

                // Extraction overlay
                if vm.isExtracting {
                    extractionOverlay
                }
            }
            .navigationTitle("快速解压")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if store.isSelectionMode {
                        Button("取消") {
                            store.isSelectionMode = false
                            store.deselectAll()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if store.isSelectionMode {
                            Button(action: { store.selectAll() }) {
                                Text("全选")
                            }
                            Button(role: .destructive, action: {
                                deleteTarget = .selected
                                showDeleteConfirm = true
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .disabled(store.selectedArchives.isEmpty)
                        } else {
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(Color(hex: "667eea"))
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $vm.showFilePicker) {
                DocumentPicker { url in
                    vm.importAndExtract(url: url, store: store)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(store)
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
            .alert("输入密码", isPresented: $vm.showPasswordPrompt) {
                SecureField("密码", text: $vm.password)
                Button("取消", role: .cancel) {
                    vm.password = ""
                    vm.pendingArchiveURL = nil
                }
                Button("解压") {
                    vm.extractWithPassword(store: store)
                }
            } message: {
                Text("此压缩包需要密码才能解压")
            }
            .alert("确认删除", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    performDelete()
                }
            } message: {
                Text(deleteMessage)
            }
            .onAppear {
                vm.updateStatistics(store: store)
            }
        }
    }

    // MARK: - Stats Card

    var statsCard: some View {
        HStack(spacing: 0) {
            StatItem(
                icon: "doc.zipper",
                value: "\(store.archives.count)",
                label: "压缩包",
                color: Color(hex: "667eea")
            )

            Divider()
                .frame(height: 40)

            StatItem(
                icon: "folder.fill",
                value: "\(store.recentExtractions.count)",
                label: "已解压",
                color: Color(hex: "764ba2")
            )

            Divider()
                .frame(height: 40)

            StatItem(
                icon: "externaldrive.fill",
                value: vm.storageUsed.isEmpty ? "0 B" : vm.storageUsed,
                label: "已使用",
                color: Color(hex: "f093fb")
            )
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
        .padding(.horizontal)
    }

    // MARK: - Import Card

    var importCard: some View {
        Button(action: { vm.showFilePicker = true }) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: Color(hex: "667eea").opacity(0.4), radius: 12, y: 6)

                    Image(systemName: "plus")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white)
                }

                VStack(spacing: 6) {
                    Text("导入压缩包")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("支持 ZIP · RAR · 7Z · TAR.GZ · 分卷压缩")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Quick Actions

    var quickActionsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                QuickActionButton(
                    icon: "trash",
                    title: "清空压缩包",
                    color: Color(hex: "ff6b6b")
                ) {
                    deleteTarget = .allArchives
                    showDeleteConfirm = true
                }
                .disabled(store.archives.isEmpty)

                QuickActionButton(
                    icon: "folder.badge.minus",
                    title: "清空已解压",
                    color: Color(hex: "ffa502")
                ) {
                    deleteTarget = .allExtracted
                    showDeleteConfirm = true
                }
                .disabled(store.recentExtractions.isEmpty)

                QuickActionButton(
                    icon: "checkmark.circle",
                    title: "批量选择",
                    color: Color(hex: "2ed573")
                ) {
                    store.isSelectionMode = true
                }
                .disabled(store.archives.isEmpty)

                QuickActionButton(
                    icon: "arrow.clockwise",
                    title: "刷新列表",
                    color: Color(hex: "54a0ff")
                ) {
                    store.loadArchives()
                    vm.updateStatistics(store: store)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Archives Section

    var archivesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("压缩包", icon: "doc.zipper", count: store.archives.count)

            ForEach(store.archives) { item in
                ArchiveRow(
                    item: item,
                    isSelected: store.selectedArchives.contains(item.url),
                    isSelectionMode: store.isSelectionMode,
                    onExtract: {
                        vm.extract(item.url, store: store)
                    },
                    onDelete: {
                        store.deleteArchive(item)
                        vm.updateStatistics(store: store)
                    },
                    onSelect: {
                        store.toggleSelection(item.url)
                    }
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Recent Extractions Section

    var recentExtractionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("最近解压", icon: "clock.fill", count: store.recentExtractions.count)
                Spacer()
                Button(action: {
                    store.clearRecentExtractions()
                    vm.updateStatistics(store: store)
                }) {
                    Text("清空")
                        .font(.caption)
                        .foregroundColor(Color(hex: "667eea"))
                }
                .padding(.trailing)
            }

            ForEach(store.recentExtractions, id: \.self) { url in
                NavigationLink(destination: FileListView(url: url)) {
                    ExtractionRow(url: url) {
                        store.deleteExtractedFolder(url)
                        vm.updateStatistics(store: store)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Browse All Card

    var browseAllCard: some View {
        NavigationLink(destination: FileListView(url: store.extractedURL, title: "全部文件")) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "667eea").opacity(0.2), Color(hex: "764ba2").opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "667eea"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("浏览全部已解压文件")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    Text("查看和管理所有解压后的文件")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Extraction Overlay

    var extractionOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated icon
                ZStack {
                    Circle()
                        .stroke(Color(hex: "667eea").opacity(0.3), lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: vm.extractionProgress)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "doc.zipper")
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: "667eea"))
                }

                VStack(spacing: 8) {
                    Text("\(Int(vm.extractionProgress * 100))%")
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)

                    Text(vm.extractionStatus)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
        }
    }

    // MARK: - Helpers

    func sectionHeader(_ title: String, icon: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "667eea"))
            Text(title)
                .font(.headline)
            Text("(\(count))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
    }

    var deleteMessage: String {
        switch deleteTarget {
        case .allArchives:
            return "确定要删除所有压缩包吗？此操作不可撤销。"
        case .allExtracted:
            return "确定要删除所有已解压的文件吗？此操作不可撤销。"
        case .selected:
            return "确定要删除选中的 \(store.selectedArchives.count) 个压缩包吗？"
        case .none:
            return ""
        }
    }

    func performDelete() {
        switch deleteTarget {
        case .allArchives:
            store.deleteAllArchives()
        case .allExtracted:
            store.deleteAllExtracted()
        case .selected:
            store.deleteSelectedArchives()
        case .none:
            break
        }
        vm.updateStatistics(store: store)
        deleteTarget = .none
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(isEnabled ? 0.15 : 0.05))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isEnabled ? color : color.opacity(0.3))
                }

                Text(title)
                    .font(.caption2)
                    .foregroundColor(isEnabled ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ArchiveRow: View {
    let item: FileItem
    let isSelected: Bool
    let isSelectionMode: Bool
    let onExtract: () -> Void
    let onDelete: () -> Void
    let onSelect: () -> Void

    var archiveFormat: ArchiveFormat? {
        ArchiveFormat.detect(from: item.url)
    }

    var body: some View {
        HStack(spacing: 14) {
            if isSelectionMode {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? Color(hex: "667eea") : .gray)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "667eea").opacity(0.15), Color(hex: "764ba2").opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: archiveFormat?.icon ?? "doc.zipper")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "667eea"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let format = archiveFormat {
                        Text(format.displayName)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "667eea"))
                            .cornerRadius(4)
                    }
                    Text(item.formattedSize)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !isSelectionMode {
                Button(action: onExtract) {
                    Text("解压")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color(hex: "667eea") : .clear, lineWidth: 2)
        )
        .contextMenu {
            Button(action: onExtract) {
                Label("解压", systemImage: "archivebox")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

struct ExtractionRow: View {
    let url: URL
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: "folder.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(folderInfo)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }

    var folderInfo: String {
        let fm = FileManager.default
        if let items = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
            return "\(items.count) 个项目"
        }
        return ""
    }
}

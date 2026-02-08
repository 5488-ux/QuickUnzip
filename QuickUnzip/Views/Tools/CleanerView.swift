import SwiftUI

struct CleanerView: View {
    @EnvironmentObject var store: FileStore
    @Environment(\.dismiss) var dismiss
    @State private var selectedArchive: FileItem?
    @State private var showFilePicker = false
    @State private var analysis: CleanAnalysis?
    @State private var isAnalyzing = false
    @State private var isCleaning = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var removeEmptyFolders = true

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "f0fdfa"), Color(hex: "ccfbf1")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        infoCard

                        selectArchiveSection

                        if let analysis = analysis {
                            analysisSection(analysis: analysis)
                            settingsSection
                            cleanButton
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                }

                if isAnalyzing || isCleaning {
                    loadingOverlay
                }
            }
            .navigationTitle("压缩包瘦身")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker { url in
                    handleArchiveSelection(url)
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定") {}
            } message: {
                Text(errorMessage)
            }
            .alert("清理成功", isPresented: $showSuccess) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                if let analysis = analysis {
                    Text("已删除 \(analysis.junkFileCount) 个垃圾文件，节省 \(analysis.formattedJunkSize)")
                }
            }
        }
    }

    // MARK: - Info Card

    var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "trash.slash.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "00d2d3"))

                Text("功能说明")
                    .font(.headline)
            }

            Text("自动清理压缩包中的系统垃圾文件，包括 .DS_Store、Thumbs.db、__MACOSX 等，减小体积。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .padding(.horizontal)
    }

    // MARK: - Select Archive Section

    var selectArchiveSection: some View {
        VStack(spacing: 16) {
            if let archive = selectedArchive {
                HStack(spacing: 14) {
                    Image(systemName: "doc.zipper")
                        .font(.title2)
                        .foregroundColor(Color(hex: "00d2d3"))
                        .frame(width: 48, height: 48)
                        .background(Color(hex: "00d2d3").opacity(0.1))
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(archive.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)

                        Text(archive.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: { selectedArchive = nil; analysis = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                )

                if analysis == nil && !isAnalyzing {
                    Button(action: analyzeArchive) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("扫描垃圾")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "00d2d3"))
                        .cornerRadius(12)
                    }
                }
            } else {
                Button(action: { showFilePicker = true }) {
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "00d2d3").opacity(0.6))

                        Text("选择压缩包")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("仅支持 ZIP 格式")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Analysis Section

    func analysisSection(analysis: CleanAnalysis) -> some View {
        VStack(spacing: 16) {
            // Summary Card
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("垃圾文件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(analysis.junkFileCount)")
                            .font(.title.bold())
                            .foregroundColor(Color(hex: "00d2d3"))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("可节省空间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(analysis.formattedJunkSize)
                            .font(.title2.bold())
                            .foregroundColor(.orange)
                    }
                }

                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "00d2d3"), Color(hex: "00a896")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(analysis.savedPercentage / 100), height: 12)
                    }
                }
                .frame(height: 12)

                HStack {
                    Text("原始大小: \(analysis.formattedOriginalSize)")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(String(format: "%.1f", analysis.savedPercentage))%")
                        .font(.caption.bold())
                        .foregroundColor(Color(hex: "00d2d3"))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            )
            .padding(.horizontal)

            // Junk Files List
            if !analysis.junkFiles.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("垃圾文件详情")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(analysis.junkFiles.prefix(10)) { junk in
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                                .foregroundColor(.orange)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(junk.name)
                                    .font(.caption)
                                    .lineLimit(1)

                                Text(junk.reason)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(junk.formattedSize)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                        )
                        .padding(.horizontal)
                    }

                    if analysis.junkFiles.count > 10 {
                        Text("... 还有 \(analysis.junkFiles.count - 10) 个文件")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Settings Section

    var settingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "folder.badge.minus")
                    .foregroundColor(.gray)
                    .frame(width: 24)

                Text("删除空文件夹")
                    .foregroundColor(.primary)

                Spacer()

                Toggle("", isOn: $removeEmptyFolders)
                    .tint(Color(hex: "00d2d3"))
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .padding(.horizontal)
    }

    // MARK: - Clean Button

    var cleanButton: some View {
        Button(action: cleanArchive) {
            HStack {
                Image(systemName: "sparkles")
                Text("开始清理")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "00d2d3"), Color(hex: "00a896")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: Color(hex: "00d2d3").opacity(0.3), radius: 8, y: 4)
        }
        .padding(.horizontal)
    }

    // MARK: - Loading Overlay

    var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text(isAnalyzing ? "正在扫描..." : "正在清理...")
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }

    // MARK: - Actions

    func handleArchiveSelection(_ url: URL) {
        do {
            let localURL = try store.importFile(from: url)
            if let item = store.archives.first(where: { $0.url == localURL }) {
                selectedArchive = item
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func analyzeArchive() {
        guard let archive = selectedArchive else { return }

        isAnalyzing = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try ArchiveCleaner.analyzeJunkFiles(zipURL: archive.url)
                DispatchQueue.main.async {
                    isAnalyzing = false
                    analysis = result

                    if result.junkFileCount == 0 {
                        errorMessage = "未发现垃圾文件"
                        showError = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isAnalyzing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    func cleanArchive() {
        guard let archive = selectedArchive else { return }

        isCleaning = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let outputName = archive.name.replacingOccurrences(of: ".zip", with: "_cleaned.zip")
                let outputURL = store.documentsURL.appendingPathComponent(outputName)

                try ArchiveCleaner.cleanArchive(zipURL: archive.url, to: outputURL, removeEmptyFolders: removeEmptyFolders)

                DispatchQueue.main.async {
                    isCleaning = false
                    store.loadArchives()
                    showSuccess = true
                }
            } catch {
                DispatchQueue.main.async {
                    isCleaning = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

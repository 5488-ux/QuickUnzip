import SwiftUI
import Charts

struct AnalyzerView: View {
    @EnvironmentObject var store: FileStore
    @Environment(\.dismiss) var dismiss
    @State private var selectedArchive: FileItem?
    @State private var showFilePicker = false
    @State private var report: CompressionReport?
    @State private var isAnalyzing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "fff0f6"), Color(hex: "ffe0f0")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        infoCard

                        selectArchiveSection

                        if let report = report {
                            reportSection(report: report)
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                }

                if isAnalyzing {
                    loadingOverlay
                }
            }
            .navigationTitle("压缩率分析")
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
        }
    }

    // MARK: - Info Card

    var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "ff9ff3"))

                Text("功能说明")
                    .font(.headline)
            }

            Text("分析压缩包的压缩效果，显示文件类型分布、压缩率统计、空间节省等详细信息。")
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
                        .foregroundColor(Color(hex: "ff9ff3"))
                        .frame(width: 48, height: 48)
                        .background(Color(hex: "ff9ff3").opacity(0.1))
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

                    Button(action: { selectedArchive = nil; report = nil }) {
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

                if report == nil && !isAnalyzing {
                    Button(action: analyzeArchive) {
                        HStack {
                            Image(systemName: "chart.pie")
                            Text("开始分析")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "ff9ff3"))
                        .cornerRadius(12)
                    }
                }
            } else {
                Button(action: { showFilePicker = true }) {
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "ff9ff3").opacity(0.6))

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

    // MARK: - Report Section

    func reportSection(report: CompressionReport) -> some View {
        VStack(spacing: 20) {
            // Overall Statistics
            overallStatsCard(report: report)

            // Type Distribution
            typeDistributionCard(report: report)

            // Best/Worst Files
            if let best = report.bestCompressedFile, let worst = report.worstCompressedFile {
                extremeFilesCard(best: best, worst: worst)
            }

            // Top Files by Compression
            topFilesSection(report: report)
        }
    }

    // MARK: - Overall Stats Card

    func overallStatsCard(report: CompressionReport) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("整体统计")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 16) {
                StatBubble(
                    title: "文件数",
                    value: "\(report.totalFiles)",
                    icon: "doc",
                    color: .blue
                )

                StatBubble(
                    title: "压缩率",
                    value: String(format: "%.1f%%", report.overallSavedPercentage),
                    icon: "chart.bar.fill",
                    color: .green
                )
            }

            Divider()

            VStack(spacing: 8) {
                HStack {
                    Text("原始大小")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(report.formattedTotalUncompressed)
                        .font(.subheadline.bold())
                }

                HStack {
                    Text("压缩后")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(report.formattedTotalCompressed)
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                }

                HStack {
                    Text("节省空间")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(report.formattedSpaceSaved)
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .padding(.horizontal)
    }

    // MARK: - Type Distribution Card

    func typeDistributionCard(report: CompressionReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("文件类型分布")
                .font(.headline)
                .padding(.horizontal)

            ForEach(report.typeStats.prefix(5)) { stat in
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: stat.icon)
                            .foregroundColor(stat.color)
                            .frame(width: 24)

                        Text(stat.type)
                            .font(.subheadline.bold())

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(stat.fileCount) 个文件")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", stat.savedPercentage))
                                .font(.caption.bold())
                                .foregroundColor(stat.color)
                        }
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(stat.color)
                                .frame(width: geometry.size.width * CGFloat(stat.savedPercentage / 100), height: 8)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text(stat.formattedTotalUncompressed)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(stat.formattedTotalCompressed)
                            .font(.caption2)
                            .foregroundColor(stat.color)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                )
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Extreme Files Card

    func extremeFilesCard(best: FileCompressionStat, worst: FileCompressionStat) -> some View {
        VStack(spacing: 12) {
            Text("压缩效果对比")
                .font(.headline)

            // Best
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.green)
                    Text("最佳压缩")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(String(format: "%.1f%%", best.savedPercentage))
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                }

                Text(best.fileName)
                    .font(.caption)
                    .lineLimit(1)

                HStack {
                    Text(best.formattedUncompressedSize)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(best.formattedCompressedSize)
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.1))
            )

            // Worst
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("压缩效果差")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(String(format: "%.1f%%", worst.savedPercentage))
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)
                }

                Text(worst.fileName)
                    .font(.caption)
                    .lineLimit(1)

                HStack {
                    Text(worst.formattedUncompressedSize)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(worst.formattedCompressedSize)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .padding(.horizontal)
    }

    // MARK: - Top Files Section

    func topFilesSection(report: CompressionReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("压缩效果排行")
                .font(.headline)
                .padding(.horizontal)

            ForEach(report.fileStats.prefix(10)) { file in
                HStack(spacing: 12) {
                    Circle()
                        .fill(file.compressionEfficiency.color)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.fileName)
                            .font(.caption)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Text(file.fileType)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(file.compressionEfficiency.color.opacity(0.2))
                                .cornerRadius(3)

                            Text(file.compressionEfficiency.rawValue)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f%%", file.savedPercentage))
                            .font(.caption.bold())
                            .foregroundColor(file.compressionEfficiency.color)

                        Text(file.formattedCompressedSize)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                )
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Loading Overlay

    var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("正在分析...")
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
                let result = try CompressionAnalyzer.analyze(archiveURL: archive.url)
                DispatchQueue.main.async {
                    isAnalyzing = false
                    report = result
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
}

// MARK: - Supporting Views

struct StatBubble: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

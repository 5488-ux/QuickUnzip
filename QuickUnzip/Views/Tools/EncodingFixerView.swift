import SwiftUI

struct EncodingFixerView: View {
    @EnvironmentObject var store: FileStore
    @Environment(\.dismiss) var dismiss
    @State private var selectedArchive: FileItem?
    @State private var showFilePicker = false
    @State private var issues: [EncodingIssue] = []
    @State private var isAnalyzing = false
    @State private var isFixing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "f8f9ff"), Color(hex: "e8eeff")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        infoCard

                        selectArchiveSection

                        if !issues.isEmpty {
                            issuesSection
                            fixButton
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                }

                if isAnalyzing || isFixing {
                    loadingOverlay
                }
            }
            .navigationTitle("乱码修复")
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
            .alert("修复成功", isPresented: $showSuccess) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("已创建修复后的压缩包")
            }
        }
    }

    // MARK: - Info Card

    var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "5f27cd"))

                Text("功能说明")
                    .font(.headline)
            }

            Text("修复在 Windows 系统创建的 ZIP 压缩包中的中文文件名乱码问题。自动检测 GBK 编码并转换为 UTF-8。")
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
                        .foregroundColor(Color(hex: "5f27cd"))
                        .frame(width: 48, height: 48)
                        .background(Color(hex: "5f27cd").opacity(0.1))
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

                    Button(action: { selectedArchive = nil; issues = [] }) {
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

                if issues.isEmpty && !isAnalyzing {
                    Button(action: analyzeArchive) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("检测乱码")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "5f27cd"))
                        .cornerRadius(12)
                    }
                }
            } else {
                Button(action: { showFilePicker = true }) {
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "5f27cd").opacity(0.6))

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

    // MARK: - Issues Section

    var issuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("检测到 \(issues.count) 个乱码文件")
                    .font(.headline)
            }
            .padding(.horizontal)

            ForEach(issues) { issue in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("原始:")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text(issue.originalName)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    HStack {
                        Text("修复:")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text(issue.fixedName)
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    HStack {
                        Text(issue.originalEncoding)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)

                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.gray)

                        Text(issue.detectedEncoding)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
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

    // MARK: - Fix Button

    var fixButton: some View {
        Button(action: fixEncoding) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                Text("立即修复")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "5f27cd"), Color(hex: "833ab4")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: Color(hex: "5f27cd").opacity(0.3), radius: 8, y: 4)
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

                Text(isAnalyzing ? "正在检测..." : "正在修复...")
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
                let detectedIssues = try EncodingFixer.detectEncodingIssues(zipURL: archive.url)
                DispatchQueue.main.async {
                    isAnalyzing = false
                    issues = detectedIssues

                    if detectedIssues.isEmpty {
                        errorMessage = "未检测到乱码文件"
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

    func fixEncoding() {
        guard let archive = selectedArchive else { return }

        isFixing = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let outputName = archive.name.replacingOccurrences(of: ".zip", with: "_fixed.zip")
                let outputURL = store.documentsURL.appendingPathComponent(outputName)

                try EncodingFixer.fixEncoding(zipURL: archive.url, to: outputURL)

                DispatchQueue.main.async {
                    isFixing = false
                    store.loadArchives()
                    showSuccess = true
                }
            } catch {
                DispatchQueue.main.async {
                    isFixing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

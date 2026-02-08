import SwiftUI
import UniformTypeIdentifiers

struct FileHashView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hashResult: FileHashService.HashResult?
    @State private var compareHash = ""
    @State private var compareResult: Bool?
    @State private var showDocumentPicker = false
    @State private var isCalculating = false
    @State private var selectedAlgorithm = 0

    private let service = FileHashService.shared
    private let algorithms = ["MD5", "SHA-1", "SHA-256"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    fileSelectionSection
                    if let result = hashResult {
                        hashResultSection(result)
                        fingerprintSection(result)
                        compareSection(result)
                    }
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(hex: "f8f9ff").ignoresSafeArea())
            .navigationTitle("文件哈希校验")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                HashDocumentPicker { url in
                    calculateHash(for: url)
                }
            }
        }
    }

    // MARK: - Header

    var headerView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "fc4a1a").opacity(0.2), Color(hex: "f7b733").opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Color(hex: "fc4a1a"))
            }

            Text("验证文件完整性，确保未被篡改")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - File Selection

    var fileSelectionSection: some View {
        Button(action: { showDocumentPicker = true }) {
            HStack {
                if isCalculating {
                    ProgressView()
                        .tint(Color(hex: "fc4a1a"))
                } else {
                    Image(systemName: "doc.badge.plus")
                }
                Text(hashResult == nil ? "选择文件" : "更换文件")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "fc4a1a"), Color(hex: "f7b733")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(14)
        }
    }

    // MARK: - Hash Result

    func hashResultSection(_ result: FileHashService.HashResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(Color(hex: "fc4a1a"))
                Text(result.fileName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(formatSize(result.fileSize))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            hashRow(label: "MD5", value: result.md5, color: Color(hex: "667eea"))
            hashRow(label: "SHA-1", value: result.sha1, color: Color(hex: "11998e"))
            hashRow(label: "SHA-256", value: result.sha256, color: Color(hex: "fc4a1a"))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    func hashRow(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.1))
                    .cornerRadius(4)

                Spacer()

                Button(action: { UIPasteboard.general.string = value }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("复制")
                    }
                    .font(.caption)
                    .foregroundColor(color)
                }
            }

            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }

    // MARK: - Fingerprint Section

    func fingerprintSection(_ result: FileHashService.HashResult) -> some View {
        VStack(spacing: 12) {
            Text("可视化指纹")
                .font(.headline)

            HStack(spacing: 20) {
                fingerprintGrid(hash: result.md5, label: "MD5", color: Color(hex: "667eea"))
                fingerprintGrid(hash: result.sha256, label: "SHA-256", color: Color(hex: "fc4a1a"))
            }

            Text("每个文件的指纹都是唯一的，方便快速目视比对")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    func fingerprintGrid(hash: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            let grid = service.generateFingerprint(hash)
            VStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<8, id: \.self) { col in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(grid[row][col] ? color : color.opacity(0.1))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color(hex: "f8f9ff"))
            .cornerRadius(12)

            Text(label)
                .font(.caption.bold())
                .foregroundColor(color)
        }
    }

    // MARK: - Compare Section

    func compareSection(_ result: FileHashService.HashResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("哈希比对")
                .font(.headline)

            Picker("算法", selection: $selectedAlgorithm) {
                ForEach(0..<algorithms.count, id: \.self) { i in
                    Text(algorithms[i]).tag(i)
                }
            }
            .pickerStyle(.segmented)

            TextField("粘贴待比对的哈希值", text: $compareHash)
                .font(.system(size: 12, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)

            Button(action: {
                let currentHash: String
                switch selectedAlgorithm {
                case 0: currentHash = result.md5
                case 1: currentHash = result.sha1
                default: currentHash = result.sha256
                }
                compareResult = service.compareHashes(currentHash, compareHash)
            }) {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("比对")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "fc4a1a").opacity(0.1))
                .foregroundColor(Color(hex: "fc4a1a"))
                .cornerRadius(12)
            }
            .disabled(compareHash.isEmpty)

            if let match = compareResult {
                HStack {
                    Image(systemName: match ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(match ? .green : .red)
                    Text(match ? "哈希一致 - 文件完整" : "哈希不一致 - 文件可能被修改")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(match ? .green : .red)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background((match ? Color.green : Color.red).opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    // MARK: - Actions

    func calculateHash(for url: URL) {
        isCalculating = true
        compareResult = nil
        compareHash = ""

        DispatchQueue.global(qos: .userInitiated).async {
            guard url.startAccessingSecurityScopedResource() else {
                DispatchQueue.main.async { isCalculating = false }
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let result = try? service.calculateHashes(for: url)
            DispatchQueue.main.async {
                hashResult = result
                isCalculating = false
            }
        }
    }

    func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Document Picker

struct HashDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

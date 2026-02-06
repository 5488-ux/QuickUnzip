import Foundation
import SwiftUI
import PhotosUI

class CompressViewModel: ObservableObject {
    @Published var selectedFiles: [SelectedFile] = []
    @Published var archiveName: String = ""
    @Published var selectedFormat: CompressionFormat = .zip
    @Published var password: String = ""
    @Published var usePassword: Bool = false

    @Published var isCompressing: Bool = false
    @Published var compressionProgress: Double = 0
    @Published var compressionStatus: String = ""

    @Published var showFilePicker: Bool = false
    @Published var showImagePicker: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var showSuccess: Bool = false
    @Published var createdArchiveURL: URL?

    struct SelectedFile: Identifiable {
        let id = UUID()
        let url: URL
        let name: String
        let size: Int64
        let type: FileType
        let thumbnail: UIImage?

        enum FileType {
            case image
            case video
            case document
            case other

            var icon: String {
                switch self {
                case .image: return "photo"
                case .video: return "film"
                case .document: return "doc"
                case .other: return "doc.fill"
                }
            }

            var color: Color {
                switch self {
                case .image: return .green
                case .video: return .purple
                case .document: return .orange
                case .other: return .gray
                }
            }
        }

        var formattedSize: String {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: size)
        }
    }

    var totalSize: Int64 {
        selectedFiles.reduce(0) { $0 + $1.size }
    }

    var formattedTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }

    var canCompress: Bool {
        !selectedFiles.isEmpty && !archiveName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - File Management

    func addFile(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: url.path) else { return }

        let size = (attrs[.size] as? Int64) ?? 0
        let ext = url.pathExtension.lowercased()

        let fileType: SelectedFile.FileType
        var thumbnail: UIImage? = nil

        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "bmp":
            fileType = .image
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                thumbnail = image
            }
        case "mp4", "mov", "avi", "mkv", "m4v":
            fileType = .video
        case "pdf", "doc", "docx", "txt", "xls", "xlsx", "ppt", "pptx":
            fileType = .document
        default:
            fileType = .other
        }

        // Copy to temp location for persistent access
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("compress_temp")
        try? fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
        try? fm.removeItem(at: tempURL)
        try? fm.copyItem(at: url, to: tempURL)

        let file = SelectedFile(
            url: tempURL,
            name: url.lastPathComponent,
            size: size,
            type: fileType,
            thumbnail: thumbnail
        )

        DispatchQueue.main.async {
            // Check for duplicate
            if !self.selectedFiles.contains(where: { $0.name == file.name }) {
                self.selectedFiles.append(file)
            }

            // Set default archive name from first file
            if self.archiveName.isEmpty {
                self.archiveName = url.deletingPathExtension().lastPathComponent
            }
        }
    }

    func addImages(from results: [PHPickerResult]) {
        for result in results {
            if result.itemProvider.hasItemConformingToTypeIdentifier("public.image") {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.image") { url, error in
                    if let url = url {
                        self.addFile(url: url)
                    }
                }
            } else if result.itemProvider.hasItemConformingToTypeIdentifier("public.movie") {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
                    if let url = url {
                        self.addFile(url: url)
                    }
                }
            }
        }
    }

    func removeFile(_ file: SelectedFile) {
        selectedFiles.removeAll { $0.id == file.id }
        try? FileManager.default.removeItem(at: file.url)
    }

    func clearAll() {
        for file in selectedFiles {
            try? FileManager.default.removeItem(at: file.url)
        }
        selectedFiles.removeAll()
        archiveName = ""
        password = ""
        usePassword = false
    }

    // MARK: - Compression

    func compress(store: FileStore) {
        guard canCompress else { return }
        guard selectedFormat.isSupported else {
            errorMessage = "\(selectedFormat.rawValue) 格式压缩暂不支持"
            showError = true
            return
        }

        isCompressing = true
        compressionProgress = 0
        compressionStatus = "准备中..."

        let fileName = archiveName.trimmingCharacters(in: .whitespaces) + "." + selectedFormat.fileExtension
        let destinationURL = store.documentsURL.appendingPathComponent(fileName)

        // Remove existing file
        try? FileManager.default.removeItem(at: destinationURL)

        let files = selectedFiles.map { $0.url }
        let pwd = usePassword ? password : nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try ArchiveCompressor.compress(
                    files: files,
                    to: destinationURL,
                    format: self?.selectedFormat ?? .zip,
                    password: pwd
                ) { progress, status in
                    DispatchQueue.main.async {
                        self?.compressionProgress = progress
                        self?.compressionStatus = status
                    }
                }

                DispatchQueue.main.async {
                    self?.isCompressing = false
                    self?.createdArchiveURL = destinationURL
                    self?.showSuccess = true
                    store.loadArchives()

                    // Clear files after successful compression
                    self?.clearAll()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isCompressing = false
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                }
            }
        }
    }
}

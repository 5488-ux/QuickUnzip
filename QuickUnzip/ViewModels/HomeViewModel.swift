import Foundation
import SwiftUI
import UniformTypeIdentifiers

class HomeViewModel: ObservableObject {
    @Published var isExtracting = false
    @Published var extractionProgress: Double = 0
    @Published var extractionStatus: String = ""
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var extractedURL: URL?
    @Published var showFilePicker = false
    @Published var showExtractedFiles = false
    @Published var showPasswordPrompt = false
    @Published var pendingArchiveURL: URL?
    @Published var password: String = ""

    // Statistics
    @Published var totalArchives: Int = 0
    @Published var totalExtracted: Int = 0
    @Published var storageUsed: String = ""

    func importAndExtract(url: URL, store: FileStore) {
        do {
            let localURL = try store.importFile(from: url)
            extract(localURL, store: store)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func extract(_ archiveURL: URL, store: FileStore, password: String? = nil) {
        isExtracting = true
        extractionProgress = 0
        extractionStatus = "准备中..."

        // Get base name without all extensions
        var baseName = archiveURL.deletingPathExtension().lastPathComponent
        // Handle .tar.gz and split archives
        if baseName.hasSuffix(".tar") {
            baseName = String(baseName.dropLast(4))
        }
        if baseName.contains(".7z") {
            baseName = baseName.replacingOccurrences(of: ".7z", with: "")
        }

        let destURL = store.extractedURL.appendingPathComponent(baseName)

        // Remove existing extraction
        try? FileManager.default.removeItem(at: destURL)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try ArchiveExtractor.extract(archiveURL: archiveURL, to: destURL, password: password) { progress, status in
                    DispatchQueue.main.async {
                        self?.extractionProgress = progress
                        self?.extractionStatus = status
                    }
                }
                DispatchQueue.main.async {
                    self?.isExtracting = false
                    self?.extractedURL = destURL
                    self?.showExtractedFiles = true
                    store.addRecentExtraction(destURL)
                    store.loadArchives()
                    self?.updateStatistics(store: store)
                }
            } catch ArchiveExtractor.ExtractError.passwordProtected {
                DispatchQueue.main.async {
                    self?.isExtracting = false
                    self?.pendingArchiveURL = archiveURL
                    self?.showPasswordPrompt = true
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isExtracting = false
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }

    func extractWithPassword(store: FileStore) {
        guard let url = pendingArchiveURL else { return }
        showPasswordPrompt = false
        extract(url, store: store, password: password)
        password = ""
        pendingArchiveURL = nil
    }

    func updateStatistics(store: FileStore) {
        totalArchives = store.archives.count
        totalExtracted = store.recentExtractions.count

        // Calculate storage used
        let fm = FileManager.default
        var totalSize: Int64 = 0

        if let enumerator = fm.enumerator(at: store.documentsURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let url as URL in enumerator {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        storageUsed = formatter.string(fromByteCount: totalSize)
    }

    private func showError(_ msg: String) {
        errorMessage = msg
        showError = true
    }
}

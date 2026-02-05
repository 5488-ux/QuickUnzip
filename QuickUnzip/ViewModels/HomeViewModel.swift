import Foundation
import SwiftUI
import UniformTypeIdentifiers

class HomeViewModel: ObservableObject {
    @Published var isExtracting = false
    @Published var extractionProgress: Double = 0
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var extractedURL: URL?
    @Published var showFilePicker = false
    @Published var showExtractedFiles = false

    func importAndExtract(url: URL, store: FileStore) {
        do {
            let localURL = try store.importFile(from: url)
            extract(localURL, store: store)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func extract(_ archiveURL: URL, store: FileStore) {
        isExtracting = true
        extractionProgress = 0

        let folderName = archiveURL.deletingPathExtension().lastPathComponent
        let destURL = store.extractedURL.appendingPathComponent(folderName)

        // Remove existing extraction
        try? FileManager.default.removeItem(at: destURL)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try ZIPExtractor.extract(archiveURL: archiveURL, to: destURL) { progress in
                    DispatchQueue.main.async {
                        self?.extractionProgress = progress
                    }
                }
                DispatchQueue.main.async {
                    self?.isExtracting = false
                    self?.extractedURL = destURL
                    self?.showExtractedFiles = true
                    store.recentExtractions.insert(destURL, at: 0)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isExtracting = false
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }

    private func showError(_ msg: String) {
        errorMessage = msg
        showError = true
    }
}

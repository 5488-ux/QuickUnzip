import Foundation
import SwiftUI

class FileStore: ObservableObject {
    @Published var archives: [FileItem] = []
    @Published var favorites: Set<URL> = []
    @Published var recentExtractions: [URL] = []
    @Published var selectedArchives: Set<URL> = []
    @Published var isSelectionMode = false

    private let favoritesKey = "favoriteFiles"
    private let recentExtractionsKey = "recentExtractions"
    private let maxRecentExtractions = 20

    init() {
        loadFavorites()
        loadRecentExtractions()
        loadArchives()
    }

    var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var extractedURL: URL {
        let url = documentsURL.appendingPathComponent("Extracted")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    var cacheURL: URL {
        let url = documentsURL.appendingPathComponent("Cache")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Archives

    func loadArchives() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { return }

        let supportedExtensions = ["zip", "rar", "7z", "tar", "gz", "tgz", "001", "002", "003"]

        archives = items.compactMap { url -> FileItem? in
            let ext = url.pathExtension.lowercased()
            let name = url.lastPathComponent.lowercased()

            // Check for supported extensions or split archives
            guard supportedExtensions.contains(ext) || name.contains(".tar.gz") else { return nil }

            // Skip non-first parts of split archives
            if ext == "002" || ext == "003" { return nil }

            let attrs = try? fm.attributesOfItem(atPath: url.path)
            return FileItem(
                name: url.lastPathComponent,
                url: url,
                isDirectory: false,
                size: (attrs?[.size] as? Int64) ?? 0,
                modDate: (attrs?[.modificationDate] as? Date) ?? Date()
            )
        }.sorted { $0.modDate > $1.modDate }
    }

    // MARK: - Recent Extractions

    func addRecentExtraction(_ url: URL) {
        // Remove if already exists
        recentExtractions.removeAll { $0 == url }
        // Add to beginning
        recentExtractions.insert(url, at: 0)
        // Limit count
        if recentExtractions.count > maxRecentExtractions {
            recentExtractions = Array(recentExtractions.prefix(maxRecentExtractions))
        }
        saveRecentExtractions()
    }

    func removeRecentExtraction(_ url: URL) {
        recentExtractions.removeAll { $0 == url }
        saveRecentExtractions()
    }

    func clearRecentExtractions() {
        recentExtractions.removeAll()
        saveRecentExtractions()
    }

    private func saveRecentExtractions() {
        let paths = recentExtractions.map { $0.path }
        UserDefaults.standard.set(paths, forKey: recentExtractionsKey)
    }

    private func loadRecentExtractions() {
        if let paths = UserDefaults.standard.stringArray(forKey: recentExtractionsKey) {
            let fm = FileManager.default
            recentExtractions = paths.compactMap { path in
                let url = URL(fileURLWithPath: path)
                return fm.fileExists(atPath: path) ? url : nil
            }
        }
    }

    // MARK: - Favorites

    func toggleFavorite(_ url: URL) {
        if favorites.contains(url) {
            favorites.remove(url)
        } else {
            favorites.insert(url)
        }
        saveFavorites()
    }

    func isFavorite(_ url: URL) -> Bool {
        favorites.contains(url)
    }

    private func saveFavorites() {
        let paths = favorites.map { $0.path }
        UserDefaults.standard.set(paths, forKey: favoritesKey)
    }

    private func loadFavorites() {
        if let paths = UserDefaults.standard.stringArray(forKey: favoritesKey) {
            favorites = Set(paths.map { URL(fileURLWithPath: $0) })
        }
    }

    // MARK: - File Operations

    func importFile(from sourceURL: URL) throws -> URL {
        let destURL = documentsURL.appendingPathComponent(sourceURL.lastPathComponent)
        let fm = FileManager.default
        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }
        if sourceURL.startAccessingSecurityScopedResource() {
            defer { sourceURL.stopAccessingSecurityScopedResource() }
            try fm.copyItem(at: sourceURL, to: destURL)
        } else {
            try fm.copyItem(at: sourceURL, to: destURL)
        }
        loadArchives()
        return destURL
    }

    func deleteArchive(_ item: FileItem) {
        try? FileManager.default.removeItem(at: item.url)
        loadArchives()
    }

    func deleteArchives(_ items: [FileItem]) {
        let fm = FileManager.default
        for item in items {
            try? fm.removeItem(at: item.url)
        }
        loadArchives()
    }

    func deleteSelectedArchives() {
        let fm = FileManager.default
        for url in selectedArchives {
            try? fm.removeItem(at: url)
        }
        selectedArchives.removeAll()
        isSelectionMode = false
        loadArchives()
    }

    func deleteExtractedFolder(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        removeRecentExtraction(url)
    }

    func deleteAllExtracted() {
        let fm = FileManager.default
        try? fm.removeItem(at: extractedURL)
        try? fm.createDirectory(at: extractedURL, withIntermediateDirectories: true)
        recentExtractions.removeAll()
        saveRecentExtractions()
    }

    func deleteAllArchives() {
        let fm = FileManager.default
        for archive in archives {
            try? fm.removeItem(at: archive.url)
        }
        archives.removeAll()
    }

    // MARK: - Storage Statistics

    func calculateStorageUsed() -> (archives: Int64, extracted: Int64, total: Int64) {
        let fm = FileManager.default

        var archiveSize: Int64 = 0
        for archive in archives {
            archiveSize += archive.size
        }

        var extractedSize: Int64 = 0
        if let enumerator = fm.enumerator(at: extractedURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let url as URL in enumerator {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    extractedSize += Int64(size)
                }
            }
        }

        return (archiveSize, extractedSize, archiveSize + extractedSize)
    }

    func clearCache() {
        let fm = FileManager.default
        try? fm.removeItem(at: cacheURL)
        try? fm.createDirectory(at: cacheURL, withIntermediateDirectories: true)
    }

    // MARK: - Selection

    func toggleSelection(_ url: URL) {
        if selectedArchives.contains(url) {
            selectedArchives.remove(url)
        } else {
            selectedArchives.insert(url)
        }
    }

    func selectAll() {
        selectedArchives = Set(archives.map { $0.url })
    }

    func deselectAll() {
        selectedArchives.removeAll()
    }
}

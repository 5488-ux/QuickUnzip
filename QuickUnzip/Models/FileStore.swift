import Foundation
import SwiftUI

class FileStore: ObservableObject {
    @Published var archives: [FileItem] = []
    @Published var favorites: Set<URL> = []
    @Published var recentExtractions: [URL] = []

    private let favoritesKey = "favoriteFiles"

    init() {
        loadFavorites()
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

    func loadArchives() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { return }
        archives = items.compactMap { url -> FileItem? in
            let ext = url.pathExtension.lowercased()
            guard ["zip", "rar", "7z", "tar", "gz"].contains(ext) else { return nil }
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
}

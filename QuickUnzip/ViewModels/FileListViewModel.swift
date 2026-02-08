import Foundation
import SwiftUI

class FileListViewModel: ObservableObject {
    @Published var files: [FileItem] = []
    @Published var searchText = ""
    @Published var sortOption: SortOption = .name
    @Published var sortAscending = true

    let directoryURL: URL
    let title: String

    init(url: URL, title: String? = nil) {
        self.directoryURL = url
        self.title = title ?? url.lastPathComponent
        loadFiles()
    }

    func loadFiles() {
        files = FileService.listFiles(at: directoryURL)
        sortFiles()
    }

    var filteredFiles: [FileItem] {
        let sorted = sortedFiles
        if searchText.isEmpty { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var sortedFiles: [FileItem] {
        files.sorted { a, b in
            // Directories first
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            let result: Bool
            switch sortOption {
            case .name:
                result = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .size:
                result = a.size < b.size
            case .date:
                result = a.modDate < b.modDate
            case .type:
                result = a.fileExtension < b.fileExtension
            }
            return sortAscending ? result : !result
        }
    }

    func sortFiles() {
        objectWillChange.send()
    }

    func deleteFile(_ item: FileItem) {
        try? FileService.deleteItem(at: item.url)
        loadFiles()
    }
}

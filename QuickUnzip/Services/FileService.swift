import Foundation

class FileService {
    static func listFiles(at url: URL) -> [FileItem] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [
            .isDirectoryKey, .fileSizeKey, .contentModificationDateKey
        ]) else { return [] }

        return urls.compactMap { fileURL -> FileItem? in
            guard let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]) else { return nil }
            return FileItem(
                name: fileURL.lastPathComponent,
                url: fileURL,
                isDirectory: values.isDirectory ?? false,
                size: Int64(values.fileSize ?? 0),
                modDate: values.contentModificationDate ?? Date()
            )
        }
    }

    static func readTextFile(at url: URL, maxSize: Int = 1_000_000) -> String? {
        guard let data = try? Data(contentsOf: url), data.count <= maxSize else { return nil }
        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
    }

    static func deleteItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    static func folderSize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}

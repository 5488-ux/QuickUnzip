import Foundation

// MARK: - Archive Cleaner Service

class ArchiveCleaner {

    enum CleanError: LocalizedError {
        case notAZipFile
        case cleanFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAZipFile: return "不是有效的 ZIP 文件"
            case .cleanFailed(let msg): return "清理失败: \(msg)"
            }
        }
    }

    // MARK: - Junk File Patterns

    private static let junkPatterns = [
        "__MACOSX/",           // macOS resource forks
        ".DS_Store",           // macOS folder settings
        "Thumbs.db",           // Windows thumbnails
        "desktop.ini",         // Windows folder settings
        ".Spotlight-V100",     // macOS Spotlight
        ".Trashes",            // macOS trash
        ".fseventsd",          // macOS FSEvents
        ".TemporaryItems",     // macOS temp files
        ".AppleDouble",        // macOS AppleDouble
        "._",                  // macOS AppleDouble prefix
        ".DS_STORE",           // Case variation
        "thumbs.db",           // Case variation
        "~$",                  // Office temp files
        ".tmp",                // Temp files
        ".bak",                // Backup files
    ]

    // MARK: - Analyze Junk Files

    static func analyzeJunkFiles(zipURL: URL) throws -> CleanAnalysis {
        let data = try Data(contentsOf: zipURL)
        guard data.count > 22, let eocd = findEOCD(in: data) else {
            throw CleanError.notAZipFile
        }

        let totalEntries = Int(readUInt16(data, eocd + 10))
        let centralDirOffset = Int(readUInt32(data, eocd + 16))

        var junkFiles: [JunkFileInfo] = []
        var totalJunkSize: Int64 = 0
        var offset = centralDirOffset

        for _ in 0..<totalEntries {
            guard offset + 46 <= data.count else { break }
            guard readUInt32(data, offset) == 0x02014b50 else { break }

            let uncompressedSize = Int64(readUInt32(data, offset + 24))
            let nameLen = Int(readUInt16(data, offset + 28))
            let extraLen = Int(readUInt16(data, offset + 30))
            let commentLen = Int(readUInt16(data, offset + 32))

            let nameData = data[offset + 46 ..< offset + 46 + nameLen]
            if let fileName = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) {
                if isJunkFile(fileName) {
                    junkFiles.append(JunkFileInfo(
                        name: fileName,
                        size: uncompressedSize,
                        reason: detectJunkReason(fileName)
                    ))
                    totalJunkSize += uncompressedSize
                }
            }

            offset += 46 + nameLen + extraLen + commentLen
        }

        let originalSize = Int64((try? FileManager.default.attributesOfItem(atPath: zipURL.path)[.size] as? Int64) ?? 0)

        return CleanAnalysis(
            junkFiles: junkFiles,
            totalJunkSize: totalJunkSize,
            originalSize: originalSize,
            estimatedSavedSize: totalJunkSize
        )
    }

    // MARK: - Clean Archive

    static func cleanArchive(zipURL: URL, to outputURL: URL, removeEmptyFolders: Bool = true) throws {
        let data = try Data(contentsOf: zipURL)
        guard data.count > 22, let eocd = findEOCD(in: data) else {
            throw CleanError.notAZipFile
        }

        let totalEntries = Int(readUInt16(data, eocd + 10))
        let centralDirOffset = Int(readUInt32(data, eocd + 16))

        // First pass: collect non-junk files
        var validEntries: [(localOffset: Int, cdOffset: Int, cdSize: Int)] = []
        var offset = centralDirOffset

        for _ in 0..<totalEntries {
            guard offset + 46 <= data.count else { break }
            guard readUInt32(data, offset) == 0x02014b50 else { break }

            let nameLen = Int(readUInt16(data, offset + 28))
            let extraLen = Int(readUInt16(data, offset + 30))
            let commentLen = Int(readUInt16(data, offset + 32))
            let localHeaderOffset = Int(readUInt32(data, offset + 42))

            let nameData = data[offset + 46 ..< offset + 46 + nameLen]
            let fileName = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) ?? ""

            let cdEntrySize = 46 + nameLen + extraLen + commentLen

            // Keep non-junk files and non-empty folders (if keeping folders)
            if !isJunkFile(fileName) {
                if fileName.hasSuffix("/") {
                    if !removeEmptyFolders {
                        validEntries.append((localOffset: localHeaderOffset, cdOffset: offset, cdSize: cdEntrySize))
                    }
                } else {
                    validEntries.append((localOffset: localHeaderOffset, cdOffset: offset, cdSize: cdEntrySize))
                }
            }

            offset += cdEntrySize
        }

        // Second pass: write new archive
        var newData = Data()
        var newCentralDir = Data()
        var offsetMapping: [Int: Int] = [:] // old offset -> new offset

        for entry in validEntries {
            let oldLocalOffset = entry.localOffset
            let newLocalOffset = newData.count

            offsetMapping[oldLocalOffset] = newLocalOffset

            // Read local file header
            guard oldLocalOffset + 30 <= data.count else { continue }
            let localSig = readUInt32(data, oldLocalOffset)
            guard localSig == 0x04034b50 else { continue }

            let compressedSize = Int(readUInt32(data, oldLocalOffset + 18))
            let nameLen = Int(readUInt16(data, oldLocalOffset + 26))
            let extraLen = Int(readUInt16(data, oldLocalOffset + 28))

            let localHeaderSize = 30 + nameLen + extraLen
            let totalSize = localHeaderSize + compressedSize

            guard oldLocalOffset + totalSize <= data.count else { continue }

            // Copy entire local file entry (header + data)
            newData.append(data[oldLocalOffset..<oldLocalOffset + totalSize])

            // Copy central directory entry and update offset
            guard entry.cdOffset + entry.cdSize <= data.count else { continue }
            var cdEntry = data[entry.cdOffset..<entry.cdOffset + entry.cdSize]

            // Update local header offset in central directory (bytes 42-45)
            let offsetInCD = 42
            var newOffsetValue = UInt32(newLocalOffset).littleEndian
            cdEntry.replaceSubrange(offsetInCD..<offsetInCD + 4, with: withUnsafeBytes(of: &newOffsetValue) { Data($0) })

            newCentralDir.append(cdEntry)
        }

        let centralDirStart = newData.count
        newData.append(newCentralDir)
        let centralDirSize = newCentralDir.count

        // Write EOCD
        var eocdData = Data()
        eocdData.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
        appendUInt16(&eocdData, 0) // Disk number
        appendUInt16(&eocdData, 0) // Central dir start disk
        appendUInt16(&eocdData, UInt16(validEntries.count))
        appendUInt16(&eocdData, UInt16(validEntries.count))
        appendUInt32(&eocdData, UInt32(centralDirSize))
        appendUInt32(&eocdData, UInt32(centralDirStart))
        appendUInt16(&eocdData, 0) // Comment length

        newData.append(eocdData)

        try newData.write(to: outputURL)
    }

    // MARK: - Helpers

    private static func isJunkFile(_ fileName: String) -> Bool {
        for pattern in junkPatterns {
            if pattern.hasSuffix("/") {
                if fileName.hasPrefix(pattern) {
                    return true
                }
            } else if pattern.hasPrefix("._") {
                if fileName.contains("/._") || fileName.hasPrefix("._") {
                    return true
                }
            } else if pattern.hasPrefix("~$") {
                if fileName.contains("~$") {
                    return true
                }
            } else {
                if fileName.hasSuffix(pattern) || fileName.contains("/\(pattern)") {
                    return true
                }
            }
        }
        return false
    }

    private static func detectJunkReason(_ fileName: String) -> String {
        if fileName.contains("__MACOSX") { return "macOS 资源文件" }
        if fileName.contains(".DS_Store") { return "macOS 文件夹设置" }
        if fileName.contains("Thumbs.db") { return "Windows 缩略图" }
        if fileName.contains("desktop.ini") { return "Windows 设置文件" }
        if fileName.contains("._") { return "macOS AppleDouble" }
        if fileName.contains("~$") { return "Office 临时文件" }
        if fileName.hasSuffix(".tmp") { return "临时文件" }
        if fileName.hasSuffix(".bak") { return "备份文件" }
        return "系统垃圾文件"
    }

    private static func findEOCD(in data: Data) -> Int? {
        let minSize = 22
        let maxCommentSize = min(65535, data.count - minSize)
        for i in 0...maxCommentSize {
            let pos = data.count - minSize - i
            if pos >= 0 && readUInt32(data, pos) == 0x06054b50 {
                return pos
            }
        }
        return nil
    }

    private static func readUInt16(_ data: Data, _ offset: Int) -> UInt16 {
        data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
    }

    private static func readUInt32(_ data: Data, _ offset: Int) -> UInt32 {
        data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
    }

    private static func appendUInt16(_ data: inout Data, _ value: UInt16) {
        var v = value.littleEndian
        data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
    }

    private static func appendUInt32(_ data: inout Data, _ value: UInt32) {
        var v = value.littleEndian
        data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
    }
}

// MARK: - Models

struct CleanAnalysis {
    let junkFiles: [JunkFileInfo]
    let totalJunkSize: Int64
    let originalSize: Int64
    let estimatedSavedSize: Int64

    var junkFileCount: Int { junkFiles.count }

    var savedPercentage: Double {
        guard originalSize > 0 else { return 0 }
        return Double(estimatedSavedSize) / Double(originalSize) * 100
    }

    var formattedOriginalSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }

    var formattedJunkSize: String {
        ByteCountFormatter.string(fromByteCount: totalJunkSize, countStyle: .file)
    }

    var formattedSavedSize: String {
        ByteCountFormatter.string(fromByteCount: estimatedSavedSize, countStyle: .file)
    }
}

struct JunkFileInfo: Identifiable {
    let id = UUID()
    let name: String
    let size: Int64
    let reason: String

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

import Foundation
import Compression

// MARK: - Archive Format Detection

enum ArchiveFormat: String, CaseIterable {
    case zip = "zip"
    case sevenZip = "7z"
    case rar = "rar"
    case splitSevenZip = "7z.001"
    case tar = "tar"
    case tarGz = "tar.gz"
    case gzip = "gz"

    var displayName: String {
        switch self {
        case .zip: return "ZIP"
        case .sevenZip: return "7Z"
        case .rar: return "RAR"
        case .splitSevenZip: return "7Z 分卷"
        case .tar: return "TAR"
        case .tarGz: return "TAR.GZ"
        case .gzip: return "GZIP"
        }
    }

    var icon: String {
        switch self {
        case .zip: return "doc.zipper"
        case .sevenZip: return "archivebox"
        case .rar: return "archivebox.fill"
        case .splitSevenZip: return "square.stack.3d.up"
        case .tar, .tarGz, .gzip: return "shippingbox"
        }
    }

    static func detect(from url: URL) -> ArchiveFormat? {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent.lowercased()

        // Check for split archives first
        if ext.hasPrefix("0") && ext.count == 3 {
            // Could be .001, .002, etc.
            if name.contains(".7z.") { return .splitSevenZip }
        }

        if name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz") { return .tarGz }

        switch ext {
        case "zip": return .zip
        case "7z": return .sevenZip
        case "rar": return .rar
        case "tar": return .tar
        case "gz", "gzip": return .gzip
        case "001": return .splitSevenZip
        default: return nil
        }
    }

    static var supportedExtensions: [String] {
        ["zip", "7z", "rar", "tar", "gz", "tgz", "001", "002", "003"]
    }
}

// MARK: - Archive Extractor

class ArchiveExtractor {

    enum ExtractError: LocalizedError {
        case unsupportedFormat(String)
        case invalidArchive
        case extractionFailed(String)
        case splitArchiveIncomplete(String)
        case corruptedData
        case passwordProtected

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let fmt): return "不支持的格式: \(fmt)"
            case .invalidArchive: return "无效或损坏的压缩包"
            case .extractionFailed(let msg): return "解压失败: \(msg)"
            case .splitArchiveIncomplete(let msg): return "分卷不完整: \(msg)"
            case .corruptedData: return "数据损坏"
            case .passwordProtected: return "压缩包有密码保护"
            }
        }
    }

    // MARK: - Public API

    static func extract(archiveURL: URL, to destination: URL, password: String? = nil, progress: ((Double, String) -> Void)? = nil) throws {
        guard let format = ArchiveFormat.detect(from: archiveURL) else {
            let ext = archiveURL.pathExtension
            throw ExtractError.unsupportedFormat(ext)
        }

        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)

        progress?(0, "正在分析压缩包...")

        switch format {
        case .zip:
            try extractZIP(archiveURL: archiveURL, to: destination, password: password, progress: progress)
        case .sevenZip:
            try extract7z(archiveURL: archiveURL, to: destination, password: password, progress: progress)
        case .splitSevenZip:
            try extractSplit7z(firstPartURL: archiveURL, to: destination, password: password, progress: progress)
        case .rar:
            try extractRAR(archiveURL: archiveURL, to: destination, password: password, progress: progress)
        case .tar:
            try extractTAR(archiveURL: archiveURL, to: destination, progress: progress)
        case .tarGz, .gzip:
            try extractGzip(archiveURL: archiveURL, to: destination, progress: progress)
        }
    }

    static func listContents(archiveURL: URL) throws -> [String] {
        guard let format = ArchiveFormat.detect(from: archiveURL) else {
            return []
        }

        switch format {
        case .zip:
            return try listZIPContents(archiveURL: archiveURL)
        default:
            return []
        }
    }

    // MARK: - ZIP Extraction

    private static func extractZIP(archiveURL: URL, to destination: URL, password: String?, progress: ((Double, String) -> Void)?) throws {
        let fm = FileManager.default
        let data = try Data(contentsOf: archiveURL)
        guard data.count > 22 else { throw ExtractError.invalidArchive }

        guard let eocd = findEOCD(in: data) else { throw ExtractError.invalidArchive }

        let totalEntries = Int(readUInt16(data, eocd + 10))
        let centralDirOffset = Int(readUInt32(data, eocd + 16))

        var offset = centralDirOffset
        var extractedCount = 0

        for i in 0..<totalEntries {
            guard offset + 46 <= data.count else { break }

            let sig = readUInt32(data, offset)
            guard sig == 0x02014b50 else { break }

            let generalPurpose = readUInt16(data, offset + 8)
            let isEncrypted = (generalPurpose & 0x01) != 0

            if isEncrypted && password == nil {
                throw ExtractError.passwordProtected
            }

            let compressionMethod = readUInt16(data, offset + 10)
            let compressedSize = Int(readUInt32(data, offset + 20))
            let uncompressedSize = Int(readUInt32(data, offset + 24))
            let nameLen = Int(readUInt16(data, offset + 28))
            let extraLen = Int(readUInt16(data, offset + 30))
            let commentLen = Int(readUInt16(data, offset + 32))
            let localHeaderOffset = Int(readUInt32(data, offset + 42))

            let nameData = data[offset + 46 ..< offset + 46 + nameLen]
            let fileName = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) ?? "unknown"

            offset += 46 + nameLen + extraLen + commentLen

            progress?(Double(i) / Double(totalEntries), fileName)

            guard localHeaderOffset + 30 <= data.count else { continue }
            let localSig = readUInt32(data, localHeaderOffset)
            guard localSig == 0x04034b50 else { continue }

            let localNameLen = Int(readUInt16(data, localHeaderOffset + 26))
            let localExtraLen = Int(readUInt16(data, localHeaderOffset + 28))
            let dataOffset = localHeaderOffset + 30 + localNameLen + localExtraLen

            let filePath = destination.appendingPathComponent(fileName)

            if fileName.hasSuffix("/") {
                try fm.createDirectory(at: filePath, withIntermediateDirectories: true)
            } else {
                let dir = filePath.deletingLastPathComponent()
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)

                if compressionMethod == 0 {
                    let end = min(dataOffset + uncompressedSize, data.count)
                    let fileData = data[dataOffset..<end]
                    try Data(fileData).write(to: filePath)
                } else if compressionMethod == 8 {
                    let end = min(dataOffset + compressedSize, data.count)
                    let compressedData = Data(data[dataOffset..<end])
                    if let decompressed = decompressDeflate(compressedData, expectedSize: uncompressedSize) {
                        try decompressed.write(to: filePath)
                    } else {
                        try compressedData.write(to: filePath)
                    }
                } else {
                    continue
                }
            }

            extractedCount += 1
        }

        progress?(1.0, "完成")

        if extractedCount == 0 {
            throw ExtractError.extractionFailed("未能解压任何文件")
        }
    }

    private static func listZIPContents(archiveURL: URL) throws -> [String] {
        let data = try Data(contentsOf: archiveURL)
        guard data.count > 22, let eocd = findEOCD(in: data) else { return [] }

        let totalEntries = Int(readUInt16(data, eocd + 10))
        let centralDirOffset = Int(readUInt32(data, eocd + 16))

        var entries: [String] = []
        var offset = centralDirOffset

        for _ in 0..<totalEntries {
            guard offset + 46 <= data.count else { break }
            guard readUInt32(data, offset) == 0x02014b50 else { break }

            let nameLen = Int(readUInt16(data, offset + 28))
            let extraLen = Int(readUInt16(data, offset + 30))
            let commentLen = Int(readUInt16(data, offset + 32))

            let nameData = data[offset + 46 ..< offset + 46 + nameLen]
            if let name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) {
                entries.append(name)
            }

            offset += 46 + nameLen + extraLen + commentLen
        }

        return entries
    }

    // MARK: - 7z Extraction

    private static func extract7z(archiveURL: URL, to destination: URL, password: String?, progress: ((Double, String) -> Void)?) throws {
        let data = try Data(contentsOf: archiveURL)

        // 7z signature: 37 7A BC AF 27 1C
        guard data.count >= 32 else { throw ExtractError.invalidArchive }
        let signature: [UInt8] = [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]
        let header = Array(data.prefix(6))
        guard header == signature else { throw ExtractError.invalidArchive }

        progress?(0.1, "正在解析 7z 文件头...")

        // 7z format is complex - use LZMA decompression for the main stream
        // For full 7z support, we need to parse the header structure
        try extract7zSimple(data: data, to: destination, progress: progress)
    }

    private static func extract7zSimple(data: Data, to destination: URL, progress: ((Double, String) -> Void)?) throws {
        // Parse 7z header
        guard data.count > 32 else { throw ExtractError.invalidArchive }

        // Read start header (32 bytes)
        let majorVersion = data[6]
        let minorVersion = data[7]

        // Skip if version is too new
        guard majorVersion == 0 && minorVersion <= 4 else {
            throw ExtractError.unsupportedFormat("7z v\(majorVersion).\(minorVersion)")
        }

        let nextHeaderOffset = readUInt64(data, 12)
        let nextHeaderSize = readUInt64(data, 20)

        let headerStart = 32 + Int(nextHeaderOffset)
        let headerEnd = headerStart + Int(nextHeaderSize)

        guard headerEnd <= data.count else { throw ExtractError.invalidArchive }

        progress?(0.3, "正在解压 LZMA 数据...")

        // For now, try to extract as a single LZMA stream
        // This is a simplified approach - real 7z has multiple streams
        let compressedData = data[32..<headerStart]

        if let decompressed = decompressLZMA(Data(compressedData)) {
            // Try to parse as a file
            let outputPath = destination.appendingPathComponent("extracted_data")
            try decompressed.write(to: outputPath)
            progress?(1.0, "完成")
        } else {
            throw ExtractError.extractionFailed("LZMA 解压失败")
        }
    }

    // MARK: - Split 7z Extraction

    private static func extractSplit7z(firstPartURL: URL, to destination: URL, password: String?, progress: ((Double, String) -> Void)?) throws {
        let fm = FileManager.default
        let directory = firstPartURL.deletingLastPathComponent()
        let baseName = firstPartURL.lastPathComponent
            .replacingOccurrences(of: ".001", with: "")
            .replacingOccurrences(of: ".7z", with: "")

        progress?(0, "正在合并分卷文件...")

        // Find all parts
        var parts: [URL] = []
        var partNum = 1

        while true {
            let partName = String(format: "%@.7z.%03d", baseName, partNum)
            let partURL = directory.appendingPathComponent(partName)

            if fm.fileExists(atPath: partURL.path) {
                parts.append(partURL)
                partNum += 1
            } else {
                break
            }
        }

        guard !parts.isEmpty else {
            throw ExtractError.splitArchiveIncomplete("未找到分卷文件")
        }

        // Combine all parts
        var combinedData = Data()
        for (index, partURL) in parts.enumerated() {
            progress?(Double(index) / Double(parts.count) * 0.5, "合并第 \(index + 1)/\(parts.count) 卷...")
            let partData = try Data(contentsOf: partURL)
            combinedData.append(partData)
        }

        // Create temporary combined file
        let tempURL = fm.temporaryDirectory.appendingPathComponent("\(baseName).7z")
        try combinedData.write(to: tempURL)
        defer { try? fm.removeItem(at: tempURL) }

        progress?(0.5, "正在解压合并后的文件...")

        // Extract the combined 7z file
        try extract7z(archiveURL: tempURL, to: destination, password: password) { p, msg in
            progress?(0.5 + p * 0.5, msg)
        }
    }

    // MARK: - RAR Extraction

    private static func extractRAR(archiveURL: URL, to destination: URL, password: String?, progress: ((Double, String) -> Void)?) throws {
        let data = try Data(contentsOf: archiveURL)

        // RAR5 signature: 52 61 72 21 1A 07 01 00
        // RAR4 signature: 52 61 72 21 1A 07 00
        let rar5Sig: [UInt8] = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00]
        let rar4Sig: [UInt8] = [0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x00]

        guard data.count >= 8 else { throw ExtractError.invalidArchive }

        let header = Array(data.prefix(8))
        let isRAR5 = header == rar5Sig
        let isRAR4 = Array(header.prefix(7)) == rar4Sig

        guard isRAR5 || isRAR4 else { throw ExtractError.invalidArchive }

        progress?(0.1, "检测到 RAR\(isRAR5 ? "5" : "4") 格式...")

        if isRAR5 {
            try extractRAR5(data: data, to: destination, password: password, progress: progress)
        } else {
            try extractRAR4(data: data, to: destination, password: password, progress: progress)
        }
    }

    private static func extractRAR5(data: Data, to destination: URL, password: String?, progress: ((Double, String) -> Void)?) throws {
        // RAR5 format parsing
        var offset = 8 // Skip signature
        let fm = FileManager.default
        var extractedCount = 0

        while offset < data.count - 7 {
            // Read header CRC (4 bytes)
            let headerCRC = readUInt32(data, offset)
            offset += 4

            // Read header size (variable length integer)
            let (headerSize, headerSizeBytes) = readVarInt(data, offset)
            offset += headerSizeBytes

            guard offset + Int(headerSize) <= data.count else { break }

            // Read header type (variable length integer)
            let (headerType, headerTypeBytes) = readVarInt(data, offset)
            let headerDataOffset = offset + headerTypeBytes

            progress?(Double(offset) / Double(data.count), "正在解析文件...")

            switch headerType {
            case 1: // Main archive header
                break
            case 2: // File header
                let result = try parseRAR5FileHeader(data: data, offset: headerDataOffset, headerSize: Int(headerSize) - headerTypeBytes, destination: destination, password: password)
                if result { extractedCount += 1 }
            case 3: // Service header
                break
            case 4: // Encryption header
                if password == nil {
                    throw ExtractError.passwordProtected
                }
            case 5: // End of archive
                break
            default:
                break
            }

            offset += Int(headerSize)
        }

        progress?(1.0, "完成")

        if extractedCount == 0 {
            throw ExtractError.extractionFailed("RAR 格式解析需要更完整的实现")
        }
    }

    private static func parseRAR5FileHeader(data: Data, offset: Int, headerSize: Int, destination: URL, password: String?) throws -> Bool {
        // RAR5 file header is complex - this is a simplified version
        // Full implementation would require proper VarInt parsing and decompression
        return false
    }

    private static func extractRAR4(data: Data, to destination: URL, password: String?, progress: ((Double, String) -> Void)?) throws {
        // RAR4 format - simpler but still complex
        var offset = 7 // Skip signature
        let fm = FileManager.default

        while offset < data.count - 7 {
            guard offset + 7 <= data.count else { break }

            let headerCRC = readUInt16(data, offset)
            let headerType = data[offset + 2]
            let flags = readUInt16(data, offset + 3)
            let headerSize = Int(readUInt16(data, offset + 5))

            guard headerSize >= 7 else { break }
            guard offset + headerSize <= data.count else { break }

            progress?(Double(offset) / Double(data.count), "正在解析...")

            if headerType == 0x74 { // File header
                // Parse file header
                let compressedSize = Int(readUInt32(data, offset + 7))
                let uncompressedSize = Int(readUInt32(data, offset + 11))
                let nameSize = Int(readUInt16(data, offset + 25))

                if offset + 32 + nameSize <= data.count {
                    let nameData = data[offset + 32 ..< offset + 32 + nameSize]
                    if let fileName = String(data: nameData, encoding: .utf8) {
                        progress?(Double(offset) / Double(data.count), fileName)
                    }
                }

                offset += headerSize + compressedSize
            } else {
                offset += headerSize
            }
        }

        throw ExtractError.extractionFailed("RAR 解压需要专用解码器，请使用支持 RAR 的第三方库")
    }

    // MARK: - TAR Extraction

    private static func extractTAR(archiveURL: URL, to destination: URL, progress: ((Double, String) -> Void)?) throws {
        let data = try Data(contentsOf: archiveURL)
        let fm = FileManager.default
        var offset = 0
        var extractedCount = 0

        while offset + 512 <= data.count {
            // Read TAR header (512 bytes)
            let headerData = data[offset..<offset+512]

            // Check for empty block (end of archive)
            if headerData.allSatisfy({ $0 == 0 }) {
                break
            }

            // Parse file name (first 100 bytes)
            let nameData = headerData.prefix(100)
            guard let fileName = String(data: nameData, encoding: .utf8)?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0")) else {
                offset += 512
                continue
            }

            if fileName.isEmpty {
                break
            }

            // Parse file size (octal string at offset 124, 12 bytes)
            let sizeData = data[offset+124..<offset+136]
            let sizeString = String(data: sizeData, encoding: .ascii)?
                .trimmingCharacters(in: CharacterSet(charactersIn: " \0")) ?? "0"
            let fileSize = Int(sizeString, radix: 8) ?? 0

            // Parse file type (offset 156, 1 byte)
            let fileType = headerData[156]

            progress?(Double(offset) / Double(data.count), fileName)

            offset += 512 // Move past header

            let filePath = destination.appendingPathComponent(fileName)

            if fileType == 0x35 || fileName.hasSuffix("/") {
                // Directory
                try fm.createDirectory(at: filePath, withIntermediateDirectories: true)
            } else if fileType == 0x30 || fileType == 0 {
                // Regular file
                let dir = filePath.deletingLastPathComponent()
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)

                if fileSize > 0 && offset + fileSize <= data.count {
                    let fileData = data[offset..<offset+fileSize]
                    try Data(fileData).write(to: filePath)
                }

                extractedCount += 1
            }

            // Move to next file (512-byte aligned)
            let padding = (512 - (fileSize % 512)) % 512
            offset += fileSize + padding
        }

        progress?(1.0, "完成")

        if extractedCount == 0 {
            throw ExtractError.extractionFailed("未能解压任何文件")
        }
    }

    // MARK: - GZIP Extraction

    private static func extractGzip(archiveURL: URL, to destination: URL, progress: ((Double, String) -> Void)?) throws {
        let data = try Data(contentsOf: archiveURL)

        // GZIP signature: 1F 8B
        guard data.count >= 10 else { throw ExtractError.invalidArchive }
        guard data[0] == 0x1F && data[1] == 0x8B else { throw ExtractError.invalidArchive }

        let compressionMethod = data[2]
        guard compressionMethod == 8 else { // Deflate
            throw ExtractError.unsupportedFormat("GZIP compression method \(compressionMethod)")
        }

        let flags = data[3]
        var offset = 10

        // Skip optional fields based on flags
        if flags & 0x04 != 0 { // FEXTRA
            let extraLen = Int(readUInt16(data, offset))
            offset += 2 + extraLen
        }

        var originalName: String?
        if flags & 0x08 != 0 { // FNAME
            var nameBytes: [UInt8] = []
            while offset < data.count && data[offset] != 0 {
                nameBytes.append(data[offset])
                offset += 1
            }
            offset += 1 // Skip null terminator
            originalName = String(bytes: nameBytes, encoding: .utf8)
        }

        if flags & 0x10 != 0 { // FCOMMENT
            while offset < data.count && data[offset] != 0 {
                offset += 1
            }
            offset += 1
        }

        if flags & 0x02 != 0 { // FHCRC
            offset += 2
        }

        progress?(0.3, "正在解压 GZIP...")

        // Compressed data ends 8 bytes before end (CRC32 + original size)
        guard offset < data.count - 8 else { throw ExtractError.invalidArchive }
        let compressedData = data[offset..<data.count-8]

        // Get original size from last 4 bytes
        let originalSize = Int(readUInt32(data, data.count - 4))

        guard let decompressed = decompressDeflate(Data(compressedData), expectedSize: originalSize) else {
            throw ExtractError.extractionFailed("GZIP 解压失败")
        }

        // Determine output filename
        let outputName: String
        if let name = originalName, !name.isEmpty {
            outputName = name
        } else {
            let archiveName = archiveURL.deletingPathExtension().lastPathComponent
            outputName = archiveName.hasSuffix(".tar") ? archiveName : archiveName + "_extracted"
        }

        let outputPath = destination.appendingPathComponent(outputName)
        try decompressed.write(to: outputPath)

        // If it's a .tar.gz, extract the tar as well
        if outputName.hasSuffix(".tar") {
            progress?(0.7, "正在解压 TAR...")
            try extractTAR(archiveURL: outputPath, to: destination, progress: { p, msg in
                progress?(0.7 + p * 0.3, msg)
            })
            try? FileManager.default.removeItem(at: outputPath)
        }

        progress?(1.0, "完成")
    }

    // MARK: - Helpers

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

    private static func readUInt64(_ data: Data, _ offset: Int) -> UInt64 {
        data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt64.self).littleEndian
        }
    }

    private static func readVarInt(_ data: Data, _ offset: Int) -> (UInt64, Int) {
        var result: UInt64 = 0
        var shift = 0
        var bytesRead = 0
        var currentOffset = offset

        while currentOffset < data.count {
            let byte = data[currentOffset]
            result |= UInt64(byte & 0x7F) << shift
            bytesRead += 1
            currentOffset += 1

            if byte & 0x80 == 0 {
                break
            }
            shift += 7
        }

        return (result, bytesRead)
    }

    private static func decompressDeflate(_ data: Data, expectedSize: Int) -> Data? {
        let bufferSize = max(expectedSize, 1024)
        var decompressed = Data(count: bufferSize)
        let result = data.withUnsafeBytes { srcPtr -> Int in
            decompressed.withUnsafeMutableBytes { dstPtr -> Int in
                guard let src = srcPtr.baseAddress,
                      let dst = dstPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                let size = compression_decode_buffer(
                    dst, bufferSize,
                    src.assumingMemoryBound(to: UInt8.self), data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
                return size
            }
        }
        guard result > 0 else { return nil }
        decompressed.count = result
        return decompressed
    }

    private static func decompressLZMA(_ data: Data) -> Data? {
        // Try different buffer sizes
        for multiplier in [1, 2, 4, 8, 16] {
            let bufferSize = data.count * multiplier
            var decompressed = Data(count: bufferSize)
            let result = data.withUnsafeBytes { srcPtr -> Int in
                decompressed.withUnsafeMutableBytes { dstPtr -> Int in
                    guard let src = srcPtr.baseAddress,
                          let dst = dstPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                    let size = compression_decode_buffer(
                        dst, bufferSize,
                        src.assumingMemoryBound(to: UInt8.self), data.count,
                        nil,
                        COMPRESSION_LZMA
                    )
                    return size
                }
            }
            if result > 0 {
                decompressed.count = result
                return decompressed
            }
        }
        return nil
    }
}

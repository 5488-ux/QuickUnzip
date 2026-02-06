import Foundation
import Compression

// MARK: - Compression Format

enum CompressionFormat: String, CaseIterable, Identifiable {
    case zip = "ZIP"
    case sevenZip = "7Z"
    case rar = "RAR"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .zip: return "zip"
        case .sevenZip: return "7z"
        case .rar: return "rar"
        }
    }

    var icon: String {
        switch self {
        case .zip: return "doc.zipper"
        case .sevenZip: return "archivebox"
        case .rar: return "archivebox.fill"
        }
    }

    var isSupported: Bool {
        switch self {
        case .zip: return true
        case .sevenZip: return true
        case .rar: return false
        }
    }
}

// MARK: - Archive Compressor

class ArchiveCompressor {

    enum CompressError: LocalizedError {
        case unsupportedFormat(String)
        case noFilesToCompress
        case compressionFailed(String)
        case fileAccessDenied
        case formatNotSupported(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let fmt): return "不支持的格式: \(fmt)"
            case .noFilesToCompress: return "没有要压缩的文件"
            case .compressionFailed(let msg): return "压缩失败: \(msg)"
            case .fileAccessDenied: return "无法访问文件"
            case .formatNotSupported(let fmt): return "\(fmt) 格式压缩暂不支持"
            }
        }
    }

    // MARK: - File Entry for tracking

    private struct ZipFileEntry {
        let relativePath: String
        let fileData: Data
        let crc32: UInt32
        let localHeaderOffset: Int
    }

    // MARK: - Public API

    static func compress(
        files: [URL],
        to destinationURL: URL,
        format: CompressionFormat,
        password: String? = nil,
        progress: ((Double, String) -> Void)? = nil
    ) throws {
        guard !files.isEmpty else {
            throw CompressError.noFilesToCompress
        }

        switch format {
        case .zip:
            try compressToZIP(files: files, to: destinationURL, password: password, progress: progress)
        case .sevenZip:
            try compressTo7z(files: files, to: destinationURL, password: password, progress: progress)
        case .rar:
            throw CompressError.formatNotSupported("RAR")
        }
    }

    // MARK: - ZIP Compression (Fixed)

    private static func compressToZIP(
        files: [URL],
        to destinationURL: URL,
        password: String?,
        progress: ((Double, String) -> Void)?
    ) throws {
        // Collect all files (including files in directories)
        var allFiles: [(url: URL, relativePath: String)] = []

        for fileURL in files {
            let accessing = fileURL.startAccessingSecurityScopedResource()
            defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }

            let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if isDirectory {
                let baseName = fileURL.lastPathComponent
                if let enumerator = FileManager.default.enumerator(at: fileURL, includingPropertiesForKeys: [.isDirectoryKey]) {
                    while let subURL = enumerator.nextObject() as? URL {
                        let subIsDir = (try? subURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                        if !subIsDir {
                            let relativePath = baseName + "/" + subURL.path.replacingOccurrences(of: fileURL.path + "/", with: "")
                            allFiles.append((subURL, relativePath))
                        }
                    }
                }
            } else {
                allFiles.append((fileURL, fileURL.lastPathComponent))
            }
        }

        guard !allFiles.isEmpty else {
            throw CompressError.noFilesToCompress
        }

        var zipData = Data()
        var entries: [ZipFileEntry] = []

        // Write local file headers and data
        for (index, file) in allFiles.enumerated() {
            progress?(Double(index) / Double(allFiles.count) * 0.8, file.relativePath)

            let accessing = file.url.startAccessingSecurityScopedResource()
            defer { if accessing { file.url.stopAccessingSecurityScopedResource() } }

            guard let fileData = try? Data(contentsOf: file.url) else { continue }

            let fileName = file.relativePath
            guard let fileNameData = fileName.data(using: .utf8) else { continue }

            let crc32 = computeCRC32(fileData)
            let localHeaderOffset = zipData.count

            // Store uncompressed for reliability
            let storedData = fileData
            let compressionMethod: UInt16 = 0 // Stored (no compression)

            // Local file header
            var header = Data()

            // Signature: PK\x03\x04
            header.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])
            // Version needed to extract (2.0)
            appendUInt16(&header, 20)
            // General purpose bit flag
            appendUInt16(&header, 0)
            // Compression method (0 = stored)
            appendUInt16(&header, compressionMethod)
            // Last mod file time
            appendUInt16(&header, 0)
            // Last mod file date
            appendUInt16(&header, 0)
            // CRC-32
            appendUInt32(&header, crc32)
            // Compressed size
            appendUInt32(&header, UInt32(storedData.count))
            // Uncompressed size
            appendUInt32(&header, UInt32(fileData.count))
            // File name length
            appendUInt16(&header, UInt16(fileNameData.count))
            // Extra field length
            appendUInt16(&header, 0)
            // File name
            header.append(fileNameData)

            // Write header and data
            zipData.append(header)
            zipData.append(storedData)

            // Track entry for central directory
            entries.append(ZipFileEntry(
                relativePath: fileName,
                fileData: fileData,
                crc32: crc32,
                localHeaderOffset: localHeaderOffset
            ))
        }

        progress?(0.9, "正在写入目录...")

        // Write central directory
        let centralDirStart = zipData.count

        for entry in entries {
            guard let fileNameData = entry.relativePath.data(using: .utf8) else { continue }

            var cdHeader = Data()

            // Signature: PK\x01\x02
            cdHeader.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
            // Version made by (2.0, Unix)
            appendUInt16(&cdHeader, 0x0314)
            // Version needed to extract (2.0)
            appendUInt16(&cdHeader, 20)
            // General purpose bit flag
            appendUInt16(&cdHeader, 0)
            // Compression method (0 = stored)
            appendUInt16(&cdHeader, 0)
            // Last mod file time
            appendUInt16(&cdHeader, 0)
            // Last mod file date
            appendUInt16(&cdHeader, 0)
            // CRC-32
            appendUInt32(&cdHeader, entry.crc32)
            // Compressed size
            appendUInt32(&cdHeader, UInt32(entry.fileData.count))
            // Uncompressed size
            appendUInt32(&cdHeader, UInt32(entry.fileData.count))
            // File name length
            appendUInt16(&cdHeader, UInt16(fileNameData.count))
            // Extra field length
            appendUInt16(&cdHeader, 0)
            // File comment length
            appendUInt16(&cdHeader, 0)
            // Disk number start
            appendUInt16(&cdHeader, 0)
            // Internal file attributes
            appendUInt16(&cdHeader, 0)
            // External file attributes
            appendUInt32(&cdHeader, 0)
            // Relative offset of local header
            appendUInt32(&cdHeader, UInt32(entry.localHeaderOffset))
            // File name
            cdHeader.append(fileNameData)

            zipData.append(cdHeader)
        }

        let centralDirSize = zipData.count - centralDirStart

        // Write end of central directory record
        var eocd = Data()

        // Signature: PK\x05\x06
        eocd.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
        // Number of this disk
        appendUInt16(&eocd, 0)
        // Disk where central directory starts
        appendUInt16(&eocd, 0)
        // Number of central directory records on this disk
        appendUInt16(&eocd, UInt16(entries.count))
        // Total number of central directory records
        appendUInt16(&eocd, UInt16(entries.count))
        // Size of central directory
        appendUInt32(&eocd, UInt32(centralDirSize))
        // Offset of start of central directory
        appendUInt32(&eocd, UInt32(centralDirStart))
        // Comment length
        appendUInt16(&eocd, 0)

        zipData.append(eocd)

        // Write to file
        try zipData.write(to: destinationURL)

        progress?(1.0, "完成")
    }

    // MARK: - 7z Compression

    private static func compressTo7z(
        files: [URL],
        to destinationURL: URL,
        password: String?,
        progress: ((Double, String) -> Void)?
    ) throws {
        // For 7z, we'll create a simple tar-like concatenation and compress with LZMA
        var allData = Data()
        var fileIndex: [(name: String, offset: Int, size: Int)] = []

        for (index, fileURL) in files.enumerated() {
            progress?(Double(index) / Double(files.count) * 0.4, fileURL.lastPathComponent)

            let accessing = fileURL.startAccessingSecurityScopedResource()
            defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }

            if let fileData = try? Data(contentsOf: fileURL) {
                let name = fileURL.lastPathComponent
                fileIndex.append((name, allData.count, fileData.count))
                allData.append(fileData)
            }
        }

        progress?(0.5, "正在压缩...")

        // Compress using LZMA
        guard let compressedData = compressLZMA(allData) else {
            throw CompressError.compressionFailed("LZMA 压缩失败")
        }

        progress?(0.9, "正在写入文件...")

        // Build 7z file structure
        var sevenZipData = Data()

        // 7z Signature: 7z BC AF 27 1C
        sevenZipData.append(contentsOf: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])
        // Version (0.4)
        sevenZipData.append(contentsOf: [0x00, 0x04])
        // Start header CRC (placeholder)
        appendUInt32(&sevenZipData, 0)
        // Next header offset
        appendUInt64(&sevenZipData, UInt64(compressedData.count))
        // Next header size (placeholder)
        appendUInt64(&sevenZipData, 0)
        // Next header CRC (placeholder)
        appendUInt32(&sevenZipData, 0)

        // Compressed data
        sevenZipData.append(compressedData)

        try sevenZipData.write(to: destinationURL)

        progress?(1.0, "完成")
    }

    // MARK: - Helpers

    private static func appendUInt16(_ data: inout Data, _ value: UInt16) {
        var v = value.littleEndian
        data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
    }

    private static func appendUInt32(_ data: inout Data, _ value: UInt32) {
        var v = value.littleEndian
        data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
    }

    private static func appendUInt64(_ data: inout Data, _ value: UInt64) {
        var v = value.littleEndian
        data.append(contentsOf: withUnsafeBytes(of: &v) { Array($0) })
    }

    private static func compressLZMA(_ data: Data) -> Data? {
        let bufferSize = data.count + 1024
        var compressed = Data(count: bufferSize)

        let result = data.withUnsafeBytes { srcPtr -> Int in
            compressed.withUnsafeMutableBytes { dstPtr -> Int in
                guard let src = srcPtr.baseAddress,
                      let dst = dstPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return compression_encode_buffer(
                    dst, bufferSize,
                    src.assumingMemoryBound(to: UInt8.self), data.count,
                    nil,
                    COMPRESSION_LZMA
                )
            }
        }

        guard result > 0 else { return nil }
        compressed.count = result
        return compressed
    }

    private static func computeCRC32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF

        let table: [UInt32] = (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                if c & 1 != 0 {
                    c = 0xEDB88320 ^ (c >> 1)
                } else {
                    c = c >> 1
                }
            }
            return c
        }

        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[index] ^ (crc >> 8)
        }

        return crc ^ 0xFFFFFFFF
    }
}

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
        case .rar: return false // RAR compression requires license
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

    // MARK: - ZIP Compression

    private static func compressToZIP(
        files: [URL],
        to destinationURL: URL,
        password: String?,
        progress: ((Double, String) -> Void)?
    ) throws {
        var zipData = Data()

        // Collect all files (including files in directories)
        var allFiles: [(url: URL, relativePath: String)] = []

        for fileURL in files {
            let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if isDirectory {
                let baseName = fileURL.lastPathComponent
                let enumerator = FileManager.default.enumerator(at: fileURL, includingPropertiesForKeys: [.isDirectoryKey])

                while let subURL = enumerator?.nextObject() as? URL {
                    let subIsDir = (try? subURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    if !subIsDir {
                        let relativePath = baseName + "/" + subURL.path.replacingOccurrences(of: fileURL.path + "/", with: "")
                        allFiles.append((subURL, relativePath))
                    }
                }
            } else {
                allFiles.append((fileURL, fileURL.lastPathComponent))
            }
        }

        guard !allFiles.isEmpty else {
            throw CompressError.noFilesToCompress
        }

        var localFileHeaders: [(offset: Int, header: Data)] = []
        var currentOffset = 0

        // Write local file headers and data
        for (index, file) in allFiles.enumerated() {
            progress?(Double(index) / Double(allFiles.count), file.relativePath)

            guard file.url.startAccessingSecurityScopedResource() || FileManager.default.isReadableFile(atPath: file.url.path) else {
                continue
            }
            defer { file.url.stopAccessingSecurityScopedResource() }

            guard let fileData = try? Data(contentsOf: file.url) else { continue }

            let fileName = file.relativePath
            let fileNameData = fileName.data(using: .utf8) ?? Data()

            // Compress the data
            let (compressedData, compressionMethod) = compressData(fileData)

            // CRC32
            let crc32 = computeCRC32(fileData)

            // Local file header
            var header = Data()

            // Signature
            header.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])
            // Version needed
            header.append(contentsOf: [0x14, 0x00])
            // General purpose bit flag
            header.append(contentsOf: [0x00, 0x00])
            // Compression method (0 = stored, 8 = deflate)
            header.append(contentsOf: withUnsafeBytes(of: compressionMethod.littleEndian) { Array($0.prefix(2)) })
            // Mod time
            header.append(contentsOf: [0x00, 0x00])
            // Mod date
            header.append(contentsOf: [0x00, 0x00])
            // CRC32
            header.append(contentsOf: withUnsafeBytes(of: crc32.littleEndian) { Array($0) })
            // Compressed size
            header.append(contentsOf: withUnsafeBytes(of: UInt32(compressedData.count).littleEndian) { Array($0) })
            // Uncompressed size
            header.append(contentsOf: withUnsafeBytes(of: UInt32(fileData.count).littleEndian) { Array($0) })
            // File name length
            header.append(contentsOf: withUnsafeBytes(of: UInt16(fileNameData.count).littleEndian) { Array($0) })
            // Extra field length
            header.append(contentsOf: [0x00, 0x00])
            // File name
            header.append(fileNameData)

            localFileHeaders.append((currentOffset, header))

            zipData.append(header)
            zipData.append(compressedData)

            currentOffset = zipData.count
        }

        // Write central directory
        let centralDirStart = zipData.count
        var centralDirSize = 0

        for (index, file) in allFiles.enumerated() {
            guard let fileData = try? Data(contentsOf: file.url) else { continue }

            let fileName = file.relativePath
            let fileNameData = fileName.data(using: .utf8) ?? Data()

            let (compressedData, compressionMethod) = compressData(fileData)
            let crc32 = computeCRC32(fileData)

            var cdHeader = Data()

            // Signature
            cdHeader.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
            // Version made by
            cdHeader.append(contentsOf: [0x14, 0x00])
            // Version needed
            cdHeader.append(contentsOf: [0x14, 0x00])
            // General purpose bit flag
            cdHeader.append(contentsOf: [0x00, 0x00])
            // Compression method
            cdHeader.append(contentsOf: withUnsafeBytes(of: compressionMethod.littleEndian) { Array($0.prefix(2)) })
            // Mod time
            cdHeader.append(contentsOf: [0x00, 0x00])
            // Mod date
            cdHeader.append(contentsOf: [0x00, 0x00])
            // CRC32
            cdHeader.append(contentsOf: withUnsafeBytes(of: crc32.littleEndian) { Array($0) })
            // Compressed size
            cdHeader.append(contentsOf: withUnsafeBytes(of: UInt32(compressedData.count).littleEndian) { Array($0) })
            // Uncompressed size
            cdHeader.append(contentsOf: withUnsafeBytes(of: UInt32(fileData.count).littleEndian) { Array($0) })
            // File name length
            cdHeader.append(contentsOf: withUnsafeBytes(of: UInt16(fileNameData.count).littleEndian) { Array($0) })
            // Extra field length
            cdHeader.append(contentsOf: [0x00, 0x00])
            // Comment length
            cdHeader.append(contentsOf: [0x00, 0x00])
            // Disk number start
            cdHeader.append(contentsOf: [0x00, 0x00])
            // Internal file attributes
            cdHeader.append(contentsOf: [0x00, 0x00])
            // External file attributes
            cdHeader.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
            // Relative offset of local header
            let offset = index < localFileHeaders.count ? localFileHeaders[index].offset : 0
            cdHeader.append(contentsOf: withUnsafeBytes(of: UInt32(offset).littleEndian) { Array($0) })
            // File name
            cdHeader.append(fileNameData)

            zipData.append(cdHeader)
            centralDirSize += cdHeader.count
        }

        // Write end of central directory
        var eocd = Data()

        // Signature
        eocd.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])
        // Disk number
        eocd.append(contentsOf: [0x00, 0x00])
        // Disk number with CD
        eocd.append(contentsOf: [0x00, 0x00])
        // Number of entries on disk
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(allFiles.count).littleEndian) { Array($0) })
        // Total number of entries
        eocd.append(contentsOf: withUnsafeBytes(of: UInt16(allFiles.count).littleEndian) { Array($0) })
        // Size of central directory
        eocd.append(contentsOf: withUnsafeBytes(of: UInt32(centralDirSize).littleEndian) { Array($0) })
        // Offset of central directory
        eocd.append(contentsOf: withUnsafeBytes(of: UInt32(centralDirStart).littleEndian) { Array($0) })
        // Comment length
        eocd.append(contentsOf: [0x00, 0x00])

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
        // Collect all file data
        var allData = Data()

        for (index, fileURL) in files.enumerated() {
            progress?(Double(index) / Double(files.count) * 0.5, fileURL.lastPathComponent)

            guard fileURL.startAccessingSecurityScopedResource() || FileManager.default.isReadableFile(atPath: fileURL.path) else {
                continue
            }
            defer { fileURL.stopAccessingSecurityScopedResource() }

            if let fileData = try? Data(contentsOf: fileURL) {
                allData.append(fileData)
            }
        }

        progress?(0.6, "正在压缩...")

        // Compress using LZMA
        guard let compressedData = compressLZMA(allData) else {
            throw CompressError.compressionFailed("LZMA 压缩失败")
        }

        progress?(0.9, "正在写入文件...")

        // Build simple 7z file structure
        var sevenZipData = Data()

        // 7z Signature
        sevenZipData.append(contentsOf: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])
        // Version
        sevenZipData.append(contentsOf: [0x00, 0x04])
        // Start header CRC (placeholder)
        sevenZipData.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
        // Next header offset
        let nextHeaderOffset = UInt64(compressedData.count)
        sevenZipData.append(contentsOf: withUnsafeBytes(of: nextHeaderOffset.littleEndian) { Array($0) })
        // Next header size (placeholder)
        sevenZipData.append(contentsOf: withUnsafeBytes(of: UInt64(0).littleEndian) { Array($0) })
        // Next header CRC (placeholder)
        sevenZipData.append(contentsOf: [0x00, 0x00, 0x00, 0x00])

        // Compressed data
        sevenZipData.append(compressedData)

        try sevenZipData.write(to: destinationURL)

        progress?(1.0, "完成")
    }

    // MARK: - Helpers

    private static func compressData(_ data: Data) -> (Data, UInt16) {
        // Try to compress with deflate
        let bufferSize = data.count
        var compressed = Data(count: bufferSize)

        let result = data.withUnsafeBytes { srcPtr -> Int in
            compressed.withUnsafeMutableBytes { dstPtr -> Int in
                guard let src = srcPtr.baseAddress,
                      let dst = dstPtr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return compression_encode_buffer(
                    dst, bufferSize,
                    src.assumingMemoryBound(to: UInt8.self), data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        if result > 0 && result < data.count {
            compressed.count = result
            return (compressed, 8) // Deflate
        } else {
            return (data, 0) // Stored
        }
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

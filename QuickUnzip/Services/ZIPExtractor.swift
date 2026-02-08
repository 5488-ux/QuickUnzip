import Foundation
import Compression

class ZIPExtractor {

    enum ExtractError: LocalizedError {
        case unsupportedFormat(String)
        case invalidArchive
        case extractionFailed(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let fmt): return "Unsupported format: \(fmt)"
            case .invalidArchive: return "Invalid or corrupted archive"
            case .extractionFailed(let msg): return "Extraction failed: \(msg)"
            }
        }
    }

    static func extract(archiveURL: URL, to destination: URL, progress: ((Double) -> Void)? = nil) throws {
        let ext = archiveURL.pathExtension.lowercased()
        switch ext {
        case "zip":
            try extractZIP(archiveURL: archiveURL, to: destination, progress: progress)
        default:
            throw ExtractError.unsupportedFormat(ext)
        }
    }

    // MARK: - ZIP Extraction using built-in APIs

    private static func extractZIP(archiveURL: URL, to destination: URL, progress: ((Double) -> Void)?) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)

        let data = try Data(contentsOf: archiveURL)
        guard data.count > 22 else { throw ExtractError.invalidArchive }

        // Find End of Central Directory
        guard let eocd = findEOCD(in: data) else { throw ExtractError.invalidArchive }

        let totalEntries = Int(readUInt16(data, eocd + 10))
        let centralDirOffset = Int(readUInt32(data, eocd + 16))

        var offset = centralDirOffset
        var extractedCount = 0

        for _ in 0..<totalEntries {
            guard offset + 46 <= data.count else { break }

            // Central Directory signature: 0x02014b50
            let sig = readUInt32(data, offset)
            guard sig == 0x02014b50 else { break }

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

            // Read local file header to find data offset
            guard localHeaderOffset + 30 <= data.count else { continue }
            let localSig = readUInt32(data, localHeaderOffset)
            guard localSig == 0x04034b50 else { continue }

            let localNameLen = Int(readUInt16(data, localHeaderOffset + 26))
            let localExtraLen = Int(readUInt16(data, localHeaderOffset + 28))
            let dataOffset = localHeaderOffset + 30 + localNameLen + localExtraLen

            let filePath = destination.appendingPathComponent(fileName)

            if fileName.hasSuffix("/") {
                // Directory
                try fm.createDirectory(at: filePath, withIntermediateDirectories: true)
            } else {
                // File
                let dir = filePath.deletingLastPathComponent()
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)

                if compressionMethod == 0 {
                    // Stored (no compression)
                    let end = min(dataOffset + uncompressedSize, data.count)
                    let fileData = data[dataOffset..<end]
                    try Data(fileData).write(to: filePath)
                } else if compressionMethod == 8 {
                    // Deflate
                    let end = min(dataOffset + compressedSize, data.count)
                    let compressedData = Data(data[dataOffset..<end])
                    if let decompressed = decompress(compressedData, expectedSize: uncompressedSize) {
                        try decompressed.write(to: filePath)
                    } else {
                        // Try raw write as fallback
                        try compressedData.write(to: filePath)
                    }
                } else {
                    // Unsupported method, skip
                    continue
                }
            }

            extractedCount += 1
            progress?(Double(extractedCount) / Double(totalEntries))
        }

        if extractedCount == 0 {
            throw ExtractError.extractionFailed("No files were extracted")
        }
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

    private static func decompress(_ data: Data, expectedSize: Int) -> Data? {
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
}

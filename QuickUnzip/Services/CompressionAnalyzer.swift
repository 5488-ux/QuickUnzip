import Foundation
import SwiftUI

// MARK: - Compression Analyzer Service

class CompressionAnalyzer {

    enum AnalyzeError: LocalizedError {
        case unsupportedFormat
        case cannotReadArchive

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat: return "不支持的压缩格式"
            case .cannotReadArchive: return "无法读取压缩包"
            }
        }
    }

    // MARK: - Analyze Archive

    static func analyze(archiveURL: URL) throws -> CompressionReport {
        guard let format = ArchiveFormat.detect(from: archiveURL) else {
            throw AnalyzeError.unsupportedFormat
        }

        switch format {
        case .zip:
            return try analyzeZIP(archiveURL: archiveURL)
        default:
            throw AnalyzeError.unsupportedFormat
        }
    }

    // MARK: - ZIP Analysis

    private static func analyzeZIP(archiveURL: URL) throws -> CompressionReport {
        let data = try Data(contentsOf: archiveURL)
        guard data.count > 22, let eocd = findEOCD(in: data) else {
            throw AnalyzeError.cannotReadArchive
        }

        let totalEntries = Int(readUInt16(data, eocd + 10))
        let centralDirOffset = Int(readUInt32(data, eocd + 16))

        var fileStats: [FileCompressionStat] = []
        var totalCompressed: Int64 = 0
        var totalUncompressed: Int64 = 0
        var typeStats: [String: TypeStat] = [:]

        var offset = centralDirOffset

        for _ in 0..<totalEntries {
            guard offset + 46 <= data.count else { break }
            guard readUInt32(data, offset) == 0x02014b50 else { break }

            let compressionMethod = readUInt16(data, offset + 10)
            let compressedSize = Int64(readUInt32(data, offset + 20))
            let uncompressedSize = Int64(readUInt32(data, offset + 24))
            let nameLen = Int(readUInt16(data, offset + 28))
            let extraLen = Int(readUInt16(data, offset + 30))
            let commentLen = Int(readUInt16(data, offset + 32))

            let nameData = data[offset + 46 ..< offset + 46 + nameLen]
            if let fileName = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) {

                // Skip directories
                if !fileName.hasSuffix("/") && uncompressedSize > 0 {
                    let compressionRatio = Double(compressedSize) / Double(uncompressedSize)
                    let savedPercentage = (1.0 - compressionRatio) * 100
                    let fileExtension = (fileName as NSString).pathExtension.lowercased()
                    let fileType = detectFileType(fileName)

                    fileStats.append(FileCompressionStat(
                        fileName: fileName,
                        fileType: fileType,
                        fileExtension: fileExtension,
                        uncompressedSize: uncompressedSize,
                        compressedSize: compressedSize,
                        compressionRatio: compressionRatio,
                        savedPercentage: savedPercentage,
                        method: compressionMethodName(compressionMethod)
                    ))

                    totalCompressed += compressedSize
                    totalUncompressed += uncompressedSize

                    // Update type statistics
                    if typeStats[fileType] == nil {
                        typeStats[fileType] = TypeStat(
                            type: fileType,
                            fileCount: 0,
                            totalUncompressed: 0,
                            totalCompressed: 0
                        )
                    }
                    typeStats[fileType]!.fileCount += 1
                    typeStats[fileType]!.totalUncompressed += uncompressedSize
                    typeStats[fileType]!.totalCompressed += compressedSize
                }
            }

            offset += 46 + nameLen + extraLen + commentLen
        }

        let archiveSize = Int64((try? FileManager.default.attributesOfItem(atPath: archiveURL.path)[.size] as? Int64) ?? 0)

        // Sort stats
        let sortedFileStats = fileStats.sorted { $0.savedPercentage > $1.savedPercentage }
        let sortedTypeStats = Array(typeStats.values).sorted { $0.averageCompressionRatio < $1.averageCompressionRatio }

        // Find best and worst compressed files
        let bestCompressed = fileStats.max { $0.savedPercentage < $1.savedPercentage }
        let worstCompressed = fileStats.min { $0.savedPercentage < $1.savedPercentage }

        return CompressionReport(
            archiveName: archiveURL.lastPathComponent,
            archiveSize: archiveSize,
            totalFiles: fileStats.count,
            totalUncompressed: totalUncompressed,
            totalCompressed: totalCompressed,
            fileStats: sortedFileStats,
            typeStats: sortedTypeStats,
            bestCompressedFile: bestCompressed,
            worstCompressedFile: worstCompressed
        )
    }

    // MARK: - Helpers

    private static func detectFileType(_ fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()

        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp":
            return "图片"
        case "mp4", "mov", "avi", "mkv", "wmv", "flv":
            return "视频"
        case "mp3", "wav", "aac", "m4a", "flac", "ogg":
            return "音频"
        case "txt", "md", "log", "json", "xml", "yaml", "yml":
            return "文本"
        case "pdf":
            return "PDF"
        case "doc", "docx", "xls", "xlsx", "ppt", "pptx":
            return "文档"
        case "zip", "rar", "7z", "tar", "gz":
            return "压缩包"
        case "exe", "dll", "dmg", "app":
            return "可执行文件"
        case "html", "css", "js", "ts", "jsx", "tsx":
            return "网页"
        case "swift", "java", "py", "cpp", "c", "h", "go", "rs":
            return "代码"
        default:
            return "其他"
        }
    }

    private static func compressionMethodName(_ method: UInt16) -> String {
        switch method {
        case 0: return "存储"
        case 8: return "Deflate"
        case 12: return "Bzip2"
        case 14: return "LZMA"
        default: return "未知"
        }
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
}

// MARK: - Models

struct CompressionReport {
    let archiveName: String
    let archiveSize: Int64
    let totalFiles: Int
    let totalUncompressed: Int64
    let totalCompressed: Int64
    let fileStats: [FileCompressionStat]
    let typeStats: [TypeStat]
    let bestCompressedFile: FileCompressionStat?
    let worstCompressedFile: FileCompressionStat?

    var overallCompressionRatio: Double {
        guard totalUncompressed > 0 else { return 0 }
        return Double(totalCompressed) / Double(totalUncompressed)
    }

    var overallSavedPercentage: Double {
        (1.0 - overallCompressionRatio) * 100
    }

    var formattedArchiveSize: String {
        ByteCountFormatter.string(fromByteCount: archiveSize, countStyle: .file)
    }

    var formattedTotalUncompressed: String {
        ByteCountFormatter.string(fromByteCount: totalUncompressed, countStyle: .file)
    }

    var formattedTotalCompressed: String {
        ByteCountFormatter.string(fromByteCount: totalCompressed, countStyle: .file)
    }

    var formattedSpaceSaved: String {
        ByteCountFormatter.string(fromByteCount: totalUncompressed - totalCompressed, countStyle: .file)
    }
}

struct FileCompressionStat: Identifiable {
    let id = UUID()
    let fileName: String
    let fileType: String
    let fileExtension: String
    let uncompressedSize: Int64
    let compressedSize: Int64
    let compressionRatio: Double
    let savedPercentage: Double
    let method: String

    var formattedUncompressedSize: String {
        ByteCountFormatter.string(fromByteCount: uncompressedSize, countStyle: .file)
    }

    var formattedCompressedSize: String {
        ByteCountFormatter.string(fromByteCount: compressedSize, countStyle: .file)
    }

    var compressionEfficiency: CompressionEfficiency {
        if savedPercentage >= 70 { return .excellent }
        if savedPercentage >= 50 { return .good }
        if savedPercentage >= 30 { return .moderate }
        if savedPercentage >= 10 { return .low }
        return .none
    }
}

struct TypeStat: Identifiable {
    let id = UUID()
    var type: String
    var fileCount: Int
    var totalUncompressed: Int64
    var totalCompressed: Int64

    var averageCompressionRatio: Double {
        guard totalUncompressed > 0 else { return 0 }
        return Double(totalCompressed) / Double(totalUncompressed)
    }

    var savedPercentage: Double {
        (1.0 - averageCompressionRatio) * 100
    }

    var formattedTotalUncompressed: String {
        ByteCountFormatter.string(fromByteCount: totalUncompressed, countStyle: .file)
    }

    var formattedTotalCompressed: String {
        ByteCountFormatter.string(fromByteCount: totalCompressed, countStyle: .file)
    }

    var color: Color {
        switch type {
        case "图片": return .green
        case "视频": return .purple
        case "音频": return .pink
        case "文本": return .orange
        case "PDF": return .red
        case "文档": return .blue
        case "代码": return .cyan
        default: return .gray
        }
    }

    var icon: String {
        switch type {
        case "图片": return "photo"
        case "视频": return "film"
        case "音频": return "music.note"
        case "文本": return "doc.text"
        case "PDF": return "doc.richtext"
        case "文档": return "doc"
        case "压缩包": return "doc.zipper"
        case "代码": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }
}

enum CompressionEfficiency: String {
    case excellent = "极佳"
    case good = "良好"
    case moderate = "一般"
    case low = "较低"
    case none = "无压缩"

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .moderate: return .orange
        case .low: return .red
        case .none: return .gray
        }
    }
}

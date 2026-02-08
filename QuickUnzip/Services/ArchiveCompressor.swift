import Foundation
import Compression
import CommonCrypto

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
        let fileNameData: Data
        let fileData: Data
        let encryptedData: Data
        let crc32: UInt32
        let localHeaderOffset: Int
        let isEncrypted: Bool
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

    // MARK: - ZIP Compression with Password Support

    private static func compressToZIP(
        files: [URL],
        to destinationURL: URL,
        password: String?,
        progress: ((Double, String) -> Void)?
    ) throws {
        // Collect all files
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

        let useEncryption = password != nil && !password!.isEmpty
        var zipData = Data()
        var entries: [ZipFileEntry] = []

        // Generate encryption keys if password provided
        var keys: (UInt32, UInt32, UInt32)?
        if useEncryption, let pwd = password {
            keys = initializeKeys(password: pwd)
        }

        // Write local file headers and data
        for (index, file) in allFiles.enumerated() {
            progress?(Double(index) / Double(allFiles.count) * 0.8, file.relativePath)

            let accessing = file.url.startAccessingSecurityScopedResource()
            defer { if accessing { file.url.stopAccessingSecurityScopedResource() } }

            guard let fileData = try? Data(contentsOf: file.url) else { continue }

            let fileName = file.relativePath
            // Use UTF-8 encoding for file names
            guard let fileNameData = fileName.data(using: .utf8) else { continue }

            let crc32 = computeCRC32(fileData)
            let localHeaderOffset = zipData.count

            // Encrypt data if password provided
            var dataToWrite: Data
            var encryptionHeader = Data()

            if useEncryption, var currentKeys = keys {
                // Generate 12-byte encryption header
                encryptionHeader = generateEncryptionHeader(crc32: crc32, keys: &currentKeys)
                // Encrypt file data
                dataToWrite = encryptData(fileData, keys: &currentKeys)
                // Reset keys for next file
                keys = initializeKeys(password: password!)
            } else {
                dataToWrite = fileData
            }

            // General purpose bit flag
            // Bit 0: encrypted
            // Bit 11: UTF-8 encoding for filename
            var flags: UInt16 = 0x0800 // UTF-8 flag
            if useEncryption {
                flags |= 0x0001 // Encryption flag
            }

            let compressedSize = UInt32(encryptionHeader.count + dataToWrite.count)
            let uncompressedSize = UInt32(fileData.count)

            // Local file header
            var header = Data()

            // Signature: PK\x03\x04
            header.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])
            // Version needed to extract (2.0)
            appendUInt16(&header, 20)
            // General purpose bit flag
            appendUInt16(&header, flags)
            // Compression method (0 = stored)
            appendUInt16(&header, 0)
            // Last mod file time
            let (dosTime, dosDate) = getCurrentDosDateTime()
            appendUInt16(&header, dosTime)
            // Last mod file date
            appendUInt16(&header, dosDate)
            // CRC-32
            appendUInt32(&header, crc32)
            // Compressed size (includes encryption header)
            appendUInt32(&header, compressedSize)
            // Uncompressed size
            appendUInt32(&header, uncompressedSize)
            // File name length
            appendUInt16(&header, UInt16(fileNameData.count))
            // Extra field length
            appendUInt16(&header, 0)
            // File name
            header.append(fileNameData)

            // Write header
            zipData.append(header)
            // Write encryption header if encrypted
            if useEncryption {
                zipData.append(encryptionHeader)
            }
            // Write file data
            zipData.append(dataToWrite)

            // Track entry
            entries.append(ZipFileEntry(
                relativePath: fileName,
                fileNameData: fileNameData,
                fileData: fileData,
                encryptedData: dataToWrite,
                crc32: crc32,
                localHeaderOffset: localHeaderOffset,
                isEncrypted: useEncryption
            ))
        }

        progress?(0.9, "正在写入目录...")

        // Write central directory
        let centralDirStart = zipData.count

        for entry in entries {
            var flags: UInt16 = 0x0800 // UTF-8
            if entry.isEncrypted {
                flags |= 0x0001
            }

            let compressedSize = entry.isEncrypted ? UInt32(12 + entry.encryptedData.count) : UInt32(entry.fileData.count)

            var cdHeader = Data()

            // Signature: PK\x01\x02
            cdHeader.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])
            // Version made by (2.0, Unix)
            appendUInt16(&cdHeader, 0x0314)
            // Version needed to extract (2.0)
            appendUInt16(&cdHeader, 20)
            // General purpose bit flag
            appendUInt16(&cdHeader, flags)
            // Compression method (0 = stored)
            appendUInt16(&cdHeader, 0)
            // Last mod file time
            let (dosTime, dosDate) = getCurrentDosDateTime()
            appendUInt16(&cdHeader, dosTime)
            // Last mod file date
            appendUInt16(&cdHeader, dosDate)
            // CRC-32
            appendUInt32(&cdHeader, entry.crc32)
            // Compressed size
            appendUInt32(&cdHeader, compressedSize)
            // Uncompressed size
            appendUInt32(&cdHeader, UInt32(entry.fileData.count))
            // File name length
            appendUInt16(&cdHeader, UInt16(entry.fileNameData.count))
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
            cdHeader.append(entry.fileNameData)

            zipData.append(cdHeader)
        }

        let centralDirSize = zipData.count - centralDirStart

        // Write end of central directory
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

    // MARK: - ZIP Encryption (PKWARE Traditional)

    private static func initializeKeys(password: String) -> (UInt32, UInt32, UInt32) {
        var key0: UInt32 = 0x12345678
        var key1: UInt32 = 0x23456789
        var key2: UInt32 = 0x34567890

        for char in password.utf8 {
            updateKeys(byte: char, key0: &key0, key1: &key1, key2: &key2)
        }

        return (key0, key1, key2)
    }

    private static func updateKeys(byte: UInt8, key0: inout UInt32, key1: inout UInt32, key2: inout UInt32) {
        key0 = crc32Update(crc: key0, byte: byte)
        key1 = (key1 &+ (key0 & 0xFF)) &* 134775813 &+ 1
        key2 = crc32Update(crc: key2, byte: UInt8((key1 >> 24) & 0xFF))
    }

    private static func crc32Update(crc: UInt32, byte: UInt8) -> UInt32 {
        let table = getCRC32Table()
        let index = Int((crc ^ UInt32(byte)) & 0xFF)
        return table[index] ^ (crc >> 8)
    }

    private static func decryptByte(key2: UInt32) -> UInt8 {
        let temp = (key2 | 2) & 0xFFFF
        return UInt8(((temp &* (temp ^ 1)) >> 8) & 0xFF)
    }

    private static func generateEncryptionHeader(crc32: UInt32, keys: inout (UInt32, UInt32, UInt32)) -> Data {
        var header = Data(count: 12)

        // Generate 11 random bytes + 1 CRC check byte
        for i in 0..<11 {
            let randomByte = UInt8.random(in: 0...255)
            let encryptedByte = randomByte ^ decryptByte(key2: keys.2)
            updateKeys(byte: randomByte, key0: &keys.0, key1: &keys.1, key2: &keys.2)
            header[i] = encryptedByte
        }

        // Last byte is high byte of CRC for verification
        let crcHighByte = UInt8((crc32 >> 24) & 0xFF)
        let encryptedCRC = crcHighByte ^ decryptByte(key2: keys.2)
        updateKeys(byte: crcHighByte, key0: &keys.0, key1: &keys.1, key2: &keys.2)
        header[11] = encryptedCRC

        return header
    }

    private static func encryptData(_ data: Data, keys: inout (UInt32, UInt32, UInt32)) -> Data {
        var encrypted = Data(count: data.count)

        for (i, byte) in data.enumerated() {
            let encryptedByte = byte ^ decryptByte(key2: keys.2)
            updateKeys(byte: byte, key0: &keys.0, key1: &keys.1, key2: &keys.2)
            encrypted[i] = encryptedByte
        }

        return encrypted
    }

    // MARK: - 7z Compression

    private static func compressTo7z(
        files: [URL],
        to destinationURL: URL,
        password: String?,
        progress: ((Double, String) -> Void)?
    ) throws {
        var allData = Data()

        for (index, fileURL) in files.enumerated() {
            progress?(Double(index) / Double(files.count) * 0.4, fileURL.lastPathComponent)

            let accessing = fileURL.startAccessingSecurityScopedResource()
            defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }

            if let fileData = try? Data(contentsOf: fileURL) {
                allData.append(fileData)
            }
        }

        progress?(0.5, "正在压缩...")

        guard let compressedData = compressLZMA(allData) else {
            throw CompressError.compressionFailed("LZMA 压缩失败")
        }

        progress?(0.9, "正在写入文件...")

        var sevenZipData = Data()

        // 7z Signature
        sevenZipData.append(contentsOf: [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])
        sevenZipData.append(contentsOf: [0x00, 0x04])
        appendUInt32(&sevenZipData, 0)
        appendUInt64(&sevenZipData, UInt64(compressedData.count))
        appendUInt64(&sevenZipData, 0)
        appendUInt32(&sevenZipData, 0)

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

    private static func getCurrentDosDateTime() -> (UInt16, UInt16) {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)

        let year = (components.year ?? 2024) - 1980
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = (components.second ?? 0) / 2

        let dosDate = UInt16((year << 9) | (month << 5) | day)
        let dosTime = UInt16((hour << 11) | (minute << 5) | second)

        return (dosTime, dosDate)
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

    private static var crc32Table: [UInt32]?

    private static func getCRC32Table() -> [UInt32] {
        if let table = crc32Table {
            return table
        }

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

        crc32Table = table
        return table
    }

    private static func computeCRC32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        let table = getCRC32Table()

        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[index] ^ (crc >> 8)
        }

        return crc ^ 0xFFFFFFFF
    }
}

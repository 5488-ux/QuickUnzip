import Foundation

// MARK: - Encoding Fixer Service

class EncodingFixer {

    enum FixError: LocalizedError {
        case notAZipFile
        case cannotReadArchive
        case fixFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAZipFile: return "不是有效的 ZIP 文件"
            case .cannotReadArchive: return "无法读取压缩包"
            case .fixFailed(let msg): return "修复失败: \(msg)"
            }
        }
    }

    // MARK: - Detect Encoding Issues

    static func detectEncodingIssues(zipURL: URL) throws -> [EncodingIssue] {
        let data = try Data(contentsOf: zipURL)
        guard data.count > 22, let eocd = findEOCD(in: data) else {
            throw FixError.notAZipFile
        }

        let totalEntries = Int(readUInt16(data, eocd + 10))
        let centralDirOffset = Int(readUInt32(data, eocd + 16))

        var issues: [EncodingIssue] = []
        var offset = centralDirOffset

        for _ in 0..<totalEntries {
            guard offset + 46 <= data.count else { break }
            guard readUInt32(data, offset) == 0x02014b50 else { break }

            let flags = readUInt16(data, offset + 8)
            let hasUtf8Flag = (flags & 0x0800) != 0

            let nameLen = Int(readUInt16(data, offset + 28))
            let extraLen = Int(readUInt16(data, offset + 30))
            let commentLen = Int(readUInt16(data, offset + 32))

            let nameData = data[offset + 46 ..< offset + 46 + nameLen]

            // Try UTF-8 first
            var fileName = String(data: nameData, encoding: .utf8)
            var detectedEncoding = "UTF-8"
            var hasIssue = false

            // If UTF-8 fails or has garbled characters, try GBK
            if fileName == nil || containsGarbledCharacters(fileName!) {
                if let gbkName = decodeGBK(nameData) {
                    hasIssue = true
                    detectedEncoding = "GBK"
                    issues.append(EncodingIssue(
                        originalName: fileName ?? "???",
                        fixedName: gbkName,
                        originalEncoding: hasUtf8Flag ? "UTF-8" : "Unknown",
                        detectedEncoding: detectedEncoding
                    ))
                }
            }

            offset += 46 + nameLen + extraLen + commentLen
        }

        return issues
    }

    // MARK: - Fix Encoding

    static func fixEncoding(zipURL: URL, to outputURL: URL, fromEncoding: String = "GBK", toEncoding: String = "UTF-8") throws {
        let data = try Data(contentsOf: zipURL)
        guard data.count > 22, let eocd = findEOCD(in: data) else {
            throw FixError.notAZipFile
        }

        var newData = Data()
        let totalEntries = Int(readUInt16(data, eocd + 10))
        let centralDirOffset = Int(readUInt32(data, eocd + 16))

        // Process local file headers and data
        var offset = 0
        var localHeaders: [(offset: Int, nameData: Data, newNameData: Data)] = []

        while offset < centralDirOffset {
            guard offset + 30 <= data.count else { break }
            let sig = readUInt32(data, offset)

            if sig == 0x04034b50 { // Local file header
                let nameLen = Int(readUInt16(data, offset + 26))
                let extraLen = Int(readUInt16(data, offset + 28))

                let headerEnd = offset + 30
                let nameStart = headerEnd
                let nameEnd = nameStart + nameLen

                guard nameEnd <= data.count else { break }

                let oldNameData = data[nameStart..<nameEnd]
                let newNameData = convertEncoding(oldNameData, from: fromEncoding, to: toEncoding)

                // Write header up to filename
                newData.append(data[offset..<nameStart])
                // Write new filename
                newData.append(newNameData)
                // Write extra field
                let extraStart = nameEnd
                let extraEnd = extraStart + extraLen
                if extraEnd <= data.count {
                    newData.append(data[extraStart..<extraEnd])
                }

                // Calculate compressed data size
                let compressedSize = Int(readUInt32(data, offset + 18))
                let dataStart = extraEnd
                let dataEnd = min(dataStart + compressedSize, data.count)

                // Write file data
                if dataEnd <= data.count {
                    newData.append(data[dataStart..<dataEnd])
                }

                localHeaders.append((offset: offset, nameData: oldNameData, newNameData: newNameData))
                offset = dataEnd
            } else {
                break
            }
        }

        let newCentralDirStart = newData.count

        // Process central directory
        offset = centralDirOffset
        var entryCount = 0

        for _ in 0..<totalEntries {
            guard offset + 46 <= data.count else { break }
            guard readUInt32(data, offset) == 0x02014b50 else { break }

            let nameLen = Int(readUInt16(data, offset + 28))
            let extraLen = Int(readUInt16(data, offset + 30))
            let commentLen = Int(readUInt16(data, offset + 32))

            let nameStart = offset + 46
            let nameEnd = nameStart + nameLen

            guard nameEnd <= data.count else { break }

            let oldNameData = data[nameStart..<nameEnd]
            let newNameData = convertEncoding(oldNameData, from: fromEncoding, to: toEncoding)

            // Write central directory header up to filename
            var cdHeader = data[offset..<nameStart]

            // Update UTF-8 flag (bit 11)
            var flagsValue = readUInt16(data, offset + 8) | 0x0800
            cdHeader.replaceSubrange((offset + 8)..<(offset + 10), with: withUnsafeBytes(of: flagsValue.littleEndian) { Data($0) })

            newData.append(cdHeader)
            newData.append(newNameData)

            // Write extra and comment
            let extraStart = nameEnd
            let extraEnd = extraStart + extraLen
            let commentEnd = extraEnd + commentLen

            if commentEnd <= data.count {
                newData.append(data[extraStart..<commentEnd])
            }

            offset = commentEnd
            entryCount += 1
        }

        let newCentralDirSize = newData.count - newCentralDirStart

        // Write EOCD
        var eocdData = Data()
        eocdData.append(contentsOf: [0x50, 0x4B, 0x05, 0x06]) // Signature
        appendUInt16(&eocdData, 0) // Disk number
        appendUInt16(&eocdData, 0) // Central dir start disk
        appendUInt16(&eocdData, UInt16(entryCount)) // Entries on this disk
        appendUInt16(&eocdData, UInt16(entryCount)) // Total entries
        appendUInt32(&eocdData, UInt32(newCentralDirSize)) // Central dir size
        appendUInt32(&eocdData, UInt32(newCentralDirStart)) // Central dir offset
        appendUInt16(&eocdData, 0) // Comment length

        newData.append(eocdData)

        try newData.write(to: outputURL)
    }

    // MARK: - Helpers

    private static func containsGarbledCharacters(_ str: String) -> Bool {
        // Check for common garbled patterns
        let garbledPatterns = ["�", "锘�", "娴嬭瘯"]
        return garbledPatterns.contains { str.contains($0) }
    }

    private static func decodeGBK(_ data: Data) -> String? {
        let encoding = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        return String(data: data, encoding: String.Encoding(rawValue: encoding))
    }

    private static func convertEncoding(_ data: Data, from: String, to: String) -> Data {
        guard from == "GBK" else { return data }

        if let str = decodeGBK(data), let newData = str.data(using: .utf8) {
            return newData
        }
        return data
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

struct EncodingIssue: Identifiable {
    let id = UUID()
    let originalName: String
    let fixedName: String
    let originalEncoding: String
    let detectedEncoding: String
}

import Foundation
import CryptoKit
import CommonCrypto

class FileHashService {
    static let shared = FileHashService()

    struct HashResult {
        let md5: String
        let sha1: String
        let sha256: String
        let fileSize: Int64
        let fileName: String
    }

    // MARK: - Calculate Hashes

    func calculateHashes(for url: URL) throws -> HashResult {
        let data = try Data(contentsOf: url)
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs[.size] as? Int64 ?? Int64(data.count)

        let md5 = calculateMD5(data)
        let sha1 = calculateSHA1(data)
        let sha256 = calculateSHA256(data)

        return HashResult(
            md5: md5,
            sha1: sha1,
            sha256: sha256,
            fileSize: size,
            fileName: url.lastPathComponent
        )
    }

    func calculateHashesForData(_ data: Data, fileName: String) -> HashResult {
        return HashResult(
            md5: calculateMD5(data),
            sha1: calculateSHA1(data),
            sha256: calculateSHA256(data),
            fileSize: Int64(data.count),
            fileName: fileName
        )
    }

    // MARK: - Individual Hashes

    private func calculateMD5(_ data: Data) -> String {
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func calculateSHA1(_ data: Data) -> String {
        let digest = Insecure.SHA1.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func calculateSHA256(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Compare

    func compareHashes(_ hash1: String, _ hash2: String) -> Bool {
        hash1.lowercased() == hash2.lowercased()
    }

    // MARK: - Visual Fingerprint

    func generateFingerprint(_ hash: String) -> [[Bool]] {
        // Create a 8x8 symmetric grid from the hash
        let bytes = stride(from: 0, to: min(hash.count, 32), by: 2).compactMap { i -> UInt8? in
            let start = hash.index(hash.startIndex, offsetBy: i)
            let end = hash.index(start, offsetBy: 2)
            return UInt8(hash[start..<end], radix: 16)
        }

        var grid: [[Bool]] = Array(repeating: Array(repeating: false, count: 8), count: 8)
        for row in 0..<8 {
            for col in 0..<4 {
                let byteIndex = (row * 4 + col) % bytes.count
                let isOn = bytes[byteIndex] > 127
                grid[row][col] = isOn
                grid[row][7 - col] = isOn // Mirror for symmetry
            }
        }
        return grid
    }
}

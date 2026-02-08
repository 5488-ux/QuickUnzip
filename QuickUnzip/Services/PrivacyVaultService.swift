import Foundation
import LocalAuthentication
import UIKit

class PrivacyVaultService: ObservableObject {
    static let shared = PrivacyVaultService()

    @Published var isUnlocked = false
    @Published var vaultFiles: [VaultFile] = []

    private let vaultDirectory: URL
    private let metadataKey = "privacy_vault_metadata_v1"

    struct VaultFile: Identifiable, Codable {
        let id: UUID
        let originalName: String
        let storedName: String
        let fileType: FileType
        let addedDate: Date
        let fileSize: Int64

        enum FileType: String, Codable {
            case image, video, document, audio, other

            var icon: String {
                switch self {
                case .image: return "photo.fill"
                case .video: return "video.fill"
                case .document: return "doc.fill"
                case .audio: return "music.note"
                case .other: return "doc.fill"
                }
            }
        }
    }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        vaultDirectory = docs.appendingPathComponent(".private_vault", isDirectory: true)

        if !FileManager.default.fileExists(atPath: vaultDirectory.path) {
            try? FileManager.default.createDirectory(at: vaultDirectory, withIntermediateDirectories: true)
        }

        // Exclude from backup
        var url = vaultDirectory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    // MARK: - Authentication

    func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Fallback to passcode
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                return false
            }
            do {
                let result = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "解锁隐私保险箱")
                await MainActor.run { isUnlocked = result }
                if result { loadVaultFiles() }
                return result
            } catch {
                return false
            }
        }

        do {
            let result = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "使用 Face ID 解锁保险箱")
            await MainActor.run { isUnlocked = result }
            if result { loadVaultFiles() }
            return result
        } catch {
            return false
        }
    }

    func lock() {
        isUnlocked = false
        vaultFiles = []
    }

    // MARK: - File Operations

    func addFile(from sourceURL: URL) throws {
        let id = UUID()
        let ext = sourceURL.pathExtension
        let storedName = "\(id.uuidString).\(ext)"
        let destination = vaultDirectory.appendingPathComponent(storedName)

        try FileManager.default.copyItem(at: sourceURL, to: destination)

        let attrs = try FileManager.default.attributesOfItem(atPath: destination.path)
        let size = attrs[.size] as? Int64 ?? 0

        let file = VaultFile(
            id: id,
            originalName: sourceURL.lastPathComponent,
            storedName: storedName,
            fileType: detectFileType(ext),
            addedDate: Date(),
            fileSize: size
        )

        vaultFiles.append(file)
        saveMetadata()
    }

    func addImage(_ image: UIImage, name: String) throws {
        let id = UUID()
        let storedName = "\(id.uuidString).jpg"
        let destination = vaultDirectory.appendingPathComponent(storedName)

        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        try data.write(to: destination)

        let file = VaultFile(
            id: id,
            originalName: name,
            storedName: storedName,
            fileType: .image,
            addedDate: Date(),
            fileSize: Int64(data.count)
        )

        vaultFiles.append(file)
        saveMetadata()
    }

    func removeFile(_ file: VaultFile) {
        let filePath = vaultDirectory.appendingPathComponent(file.storedName)
        try? FileManager.default.removeItem(at: filePath)
        vaultFiles.removeAll { $0.id == file.id }
        saveMetadata()
    }

    func getFileURL(_ file: VaultFile) -> URL {
        vaultDirectory.appendingPathComponent(file.storedName)
    }

    func loadImage(_ file: VaultFile) -> UIImage? {
        let url = getFileURL(file)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Helpers

    private func detectFileType(_ ext: String) -> VaultFile.FileType {
        switch ext.lowercased() {
        case "jpg", "jpeg", "png", "heic", "gif", "bmp", "webp": return .image
        case "mp4", "mov", "avi", "mkv", "m4v": return .video
        case "mp3", "m4a", "wav", "aac", "flac": return .audio
        case "pdf", "doc", "docx", "txt", "rtf", "xls", "xlsx": return .document
        default: return .other
        }
    }

    private func saveMetadata() {
        if let data = try? JSONEncoder().encode(vaultFiles) {
            UserDefaults.standard.set(data, forKey: metadataKey)
        }
    }

    private func loadVaultFiles() {
        guard let data = UserDefaults.standard.data(forKey: metadataKey),
              let files = try? JSONDecoder().decode([VaultFile].self, from: data) else { return }

        DispatchQueue.main.async {
            // Only keep files that still exist on disk
            self.vaultFiles = files.filter { file in
                FileManager.default.fileExists(atPath: self.vaultDirectory.appendingPathComponent(file.storedName).path)
            }
        }
    }

    var biometricType: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "密码"
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        @unknown default: return "生物识别"
        }
    }
}

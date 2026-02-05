import Foundation
import SwiftUI

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
    let isDirectory: Bool
    let size: Int64
    let modDate: Date

    var fileExtension: String { url.pathExtension.lowercased() }

    var icon: String {
        if isDirectory { return "folder.fill" }
        switch fileExtension {
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "bmp", "tiff":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "txt", "md", "log", "json", "xml", "csv", "html", "css", "js", "swift", "py":
            return "doc.text"
        case "mp4", "mov", "avi", "mkv":
            return "film"
        case "mp3", "wav", "aac", "m4a":
            return "music.note"
        case "zip", "rar", "7z", "tar", "gz":
            return "doc.zipper"
        default:
            return "doc"
        }
    }

    var iconColor: Color {
        if isDirectory { return .blue }
        switch fileExtension {
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "bmp", "tiff":
            return .green
        case "pdf":
            return .red
        case "txt", "md", "log", "json", "xml", "csv", "html", "css", "js", "swift", "py":
            return .orange
        case "mp4", "mov", "avi", "mkv":
            return .purple
        case "mp3", "wav", "aac", "m4a":
            return .pink
        case "zip", "rar", "7z", "tar", "gz":
            return Color(hex: "667eea")
        default:
            return .gray
        }
    }

    var isImage: Bool {
        ["jpg", "jpeg", "png", "gif", "heic", "webp", "bmp", "tiff"].contains(fileExtension)
    }
    var isText: Bool {
        ["txt", "md", "log", "json", "xml", "csv", "html", "css", "js", "swift", "py", "c", "h", "java", "rb", "php", "sh"].contains(fileExtension)
    }
    var isPDF: Bool { fileExtension == "pdf" }
    var isArchive: Bool { ["zip", "rar", "7z", "tar", "gz"].contains(fileExtension) }
    var isPreviewable: Bool { isImage || isText || isPDF }

    var formattedSize: String {
        if isDirectory { return "文件夹" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modDate)
    }
}

enum SortOption: String, CaseIterable {
    case name = "名称"
    case size = "大小"
    case date = "日期"
    case type = "类型"
}

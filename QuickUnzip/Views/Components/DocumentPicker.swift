import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    var allowsMultipleSelection: Bool = false

    // Custom UTTypes for archive formats
    static let sevenZip = UTType(filenameExtension: "7z") ?? .data
    static let rar = UTType(filenameExtension: "rar") ?? .data
    static let tarGz = UTType(filenameExtension: "tgz") ?? .data
    static let splitArchive = UTType(filenameExtension: "001") ?? .data

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [
            .zip,
            .archive,
            .gzip,
            Self.sevenZip,
            Self.rar,
            Self.tarGz,
            Self.splitArchive,
            .data
        ]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = allowsMultipleSelection
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                onPick(url)
            }
        }
    }
}

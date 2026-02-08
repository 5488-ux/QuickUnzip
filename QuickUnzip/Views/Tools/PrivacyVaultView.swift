import SwiftUI
import PhotosUI

struct PrivacyVaultView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var vault = PrivacyVaultService.shared
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var showPreview = false
    @State private var showDeleteConfirm = false
    @State private var fileToDelete: PrivacyVaultService.VaultFile?

    var body: some View {
        NavigationStack {
            Group {
                if vault.isUnlocked {
                    unlockedView
                } else {
                    lockedView
                }
            }
            .background(Color(hex: "f8f9ff").ignoresSafeArea())
            .navigationTitle("隐私保险箱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if vault.isUnlocked {
                        Button(action: { vault.lock() }) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(Color(hex: "ff6b6b"))
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("确认删除", isPresented: $showDeleteConfirm) {
                Button("删除", role: .destructive) {
                    if let file = fileToDelete {
                        vault.removeFile(file)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后无法恢复")
            }
            .sheet(isPresented: $showPreview) {
                if let image = previewImage {
                    ImagePreviewSheet(image: image)
                }
            }
        }
    }

    // MARK: - Locked View

    var lockedView: some View {
        VStack(spacing: 30) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "667eea").opacity(0.15), Color(hex: "764ba2").opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("隐私保险箱")
                    .font(.title2.bold())

                Text("使用 \(vault.biometricType) 保护您的私密文件")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                Task { _ = await vault.authenticate() }
            }) {
                HStack {
                    Image(systemName: vault.biometricType == "Face ID" ? "faceid" : "touchid")
                    Text("解锁保险箱")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Unlocked View

    var unlockedView: some View {
        VStack(spacing: 0) {
            if vault.vaultFiles.isEmpty {
                emptyVaultView
            } else {
                fileListView
            }

            // Add buttons
            addButtonsBar
        }
    }

    var emptyVaultView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("保险箱是空的")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("添加图片或文件到保险箱中安全存储")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))

            Spacer()
        }
    }

    var fileListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vault.vaultFiles) { file in
                    VaultFileRow(file: file) {
                        // Preview
                        if file.fileType == .image, let image = vault.loadImage(file) {
                            previewImage = image
                            showPreview = true
                        }
                    } onDelete: {
                        fileToDelete = file
                        showDeleteConfirm = true
                    }
                }
            }
            .padding()
        }
    }

    var addButtonsBar: some View {
        HStack(spacing: 16) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack {
                    Image(systemName: "photo.fill")
                    Text("添加图片")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: "667eea"))
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .onChange(of: selectedPhotoItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        let name = "IMG_\(Int(Date().timeIntervalSince1970)).jpg"
                        try? vault.addImage(image, name: name)
                    }
                }
            }

            Button(action: { showDocumentPicker = true }) {
                HStack {
                    Image(systemName: "doc.fill")
                    Text("添加文件")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: "764ba2"))
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .sheet(isPresented: $showDocumentPicker) {
                VaultDocumentPicker { url in
                    try? vault.addFile(from: url)
                }
            }
        }
        .padding()
        .background(.white.shadow(.drop(color: .black.opacity(0.08), radius: 8, y: -4)))
    }
}

// MARK: - Vault File Row

struct VaultFileRow: View {
    let file: PrivacyVaultService.VaultFile
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(fileColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: file.fileType.icon)
                        .font(.system(size: 18))
                        .foregroundColor(fileColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(file.originalName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(formatSize(file.fileSize))
                        Text("·")
                        Text(formatDate(file.addedDate))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.6))
                        .padding(8)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    var fileColor: Color {
        switch file.fileType {
        case .image: return Color(hex: "667eea")
        case .video: return Color(hex: "ff6b6b")
        case .audio: return Color(hex: "ffd700")
        case .document: return Color(hex: "11998e")
        case .other: return Color(hex: "606c88")
        }
    }

    func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Image Preview Sheet

struct ImagePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Vault Document Picker

struct VaultDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            onPick(url)
        }
    }
}

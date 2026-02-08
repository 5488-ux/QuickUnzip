import SwiftUI
import PhotosUI

struct CompressView: View {
    @EnvironmentObject var store: FileStore
    @StateObject private var vm = CompressViewModel()
    @State private var selectedPhotos: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(hex: "fff5f5"), Color(hex: "ffe8e8")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Add Files Section
                        addFilesSection

                        // Selected Files
                        if !vm.selectedFiles.isEmpty {
                            selectedFilesSection
                        }

                        // Archive Settings
                        if !vm.selectedFiles.isEmpty {
                            archiveSettingsSection
                        }

                        // Compress Button
                        if !vm.selectedFiles.isEmpty {
                            compressButton
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                }

                // Compression Overlay
                if vm.isCompressing {
                    compressionOverlay
                }
            }
            .navigationTitle("压缩文件")
            .sheet(isPresented: $vm.showFilePicker) {
                DocumentPicker(allowsMultipleSelection: true) { url in
                    vm.addFile(url: url)
                }
            }
            .photosPicker(isPresented: $vm.showImagePicker, selection: $selectedPhotos, maxSelectionCount: 20, matching: .any(of: [.images, .videos]))
            .onChange(of: selectedPhotos) { newItems in
                handlePhotoPicker(items: newItems)
            }
            .alert("错误", isPresented: $vm.showError) {
                Button("确定") {}
            } message: {
                Text(vm.errorMessage)
            }
            .alert("压缩成功", isPresented: $vm.showSuccess) {
                Button("确定") {}
            } message: {
                if let url = vm.createdArchiveURL {
                    Text("已创建: \(url.lastPathComponent)")
                }
            }
        }
    }

    // MARK: - Add Files Section

    var addFilesSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Add Files Button
                AddFileButton(
                    icon: "doc.badge.plus",
                    title: "添加文件",
                    color: Color(hex: "ff6b6b")
                ) {
                    vm.showFilePicker = true
                }

                // Add Photos/Videos Button
                AddFileButton(
                    icon: "photo.badge.plus",
                    title: "照片/视频",
                    color: Color(hex: "ff9f43")
                ) {
                    vm.showImagePicker = true
                }
            }
            .padding(.horizontal)

            // Instructions
            if vm.selectedFiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.up.doc")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "ff6b6b").opacity(0.5))

                    Text("选择要压缩的文件")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("支持文件、图片、视频等多种类型")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                )
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Selected Files Section

    var selectedFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.on.doc")
                    .foregroundColor(Color(hex: "ff6b6b"))
                Text("已选文件")
                    .font(.headline)
                Text("(\(vm.selectedFiles.count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text(vm.formattedTotalSize)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button(action: { vm.clearAll() }) {
                    Text("清空")
                        .font(.caption)
                        .foregroundColor(Color(hex: "ff6b6b"))
                }
            }
            .padding(.horizontal)

            ForEach(vm.selectedFiles) { file in
                SelectedFileRow(file: file) {
                    vm.removeFile(file)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Archive Settings Section

    var archiveSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape")
                    .foregroundColor(Color(hex: "ff6b6b"))
                Text("压缩设置")
                    .font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                // Archive Name
                HStack {
                    Image(systemName: "textformat")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    Text("包名")
                        .foregroundColor(.secondary)
                    Spacer()
                    TextField("压缩包名称", text: $vm.archiveName)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.plain)
                }
                .padding()

                Divider().padding(.leading, 48)

                // Format Selection
                HStack {
                    Image(systemName: "doc.zipper")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    Text("格式")
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("格式", selection: $vm.selectedFormat) {
                        ForEach(CompressionFormat.allCases) { format in
                            HStack {
                                Text(format.rawValue)
                                if !format.isSupported {
                                    Text("(暂不支持)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color(hex: "ff6b6b"))
                }
                .padding()

                Divider().padding(.leading, 48)

                // Password Toggle
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    Text("设置密码")
                        .foregroundColor(.secondary)
                    Spacer()
                    Toggle("", isOn: $vm.usePassword)
                        .tint(Color(hex: "ff6b6b"))
                }
                .padding()

                // Password Field
                if vm.usePassword {
                    Divider().padding(.leading, 48)
                    HStack {
                        Image(systemName: "key")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        SecureField("输入密码", text: $vm.password)
                    }
                    .padding()
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Compress Button

    var compressButton: some View {
        Button(action: { vm.compress(store: store) }) {
            HStack {
                Image(systemName: "archivebox.fill")
                Text("开始压缩")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: vm.canCompress ? [Color(hex: "ff6b6b"), Color(hex: "ff8e8e")] : [Color.gray.opacity(0.5), Color.gray.opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: vm.canCompress ? Color(hex: "ff6b6b").opacity(0.3) : .clear, radius: 8, y: 4)
        }
        .disabled(!vm.canCompress)
        .padding(.horizontal)
    }

    // MARK: - Compression Overlay

    var compressionOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "ff6b6b").opacity(0.3), lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: vm.compressionProgress)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "ff6b6b"), Color(hex: "ff8e8e")],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: "ff6b6b"))
                }

                VStack(spacing: 8) {
                    Text("\(Int(vm.compressionProgress * 100))%")
                        .font(.title.weight(.bold))
                        .foregroundColor(.white)

                    Text(vm.compressionStatus)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
        }
    }

    // MARK: - Helpers

    func handlePhotoPicker(items: [PhotosPickerItem]) {
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data = data {
                        // Save to temp file
                        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("photo_temp")
                        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                        let fileName = "\(UUID().uuidString).jpg"
                        let tempURL = tempDir.appendingPathComponent(fileName)

                        try? data.write(to: tempURL)
                        self.vm.addFile(url: tempURL)
                    }
                case .failure:
                    break
                }
            }
        }
        selectedPhotos.removeAll()
    }
}

// MARK: - Supporting Views

struct AddFileButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SelectedFileRow: View {
    let file: CompressViewModel.SelectedFile
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail or Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(file.type.color.opacity(0.15))
                    .frame(width: 48, height: 48)

                if let thumbnail = file.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: file.type.icon)
                        .font(.system(size: 20))
                        .foregroundColor(file.type.color)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(file.formattedSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }
}

import SwiftUI
import PhotosUI

struct SteganographyToolView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isEncodeMode = true
    @State private var secretMessage = ""
    @State private var selectedImage: UIImage?
    @State private var resultImage: UIImage?
    @State private var decodedMessage: String?
    @State private var showImagePicker = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    @State private var showSaveSuccess = false
    @State private var selectedItem: PhotosPickerItem?

    private let service = SteganographyService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView

                    // Mode Toggle
                    modeToggle

                    // Image Selection
                    imageSelectionSection

                    if isEncodeMode {
                        encodeSection
                    } else {
                        decodeSection
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(hex: "f8f9ff").ignoresSafeArea())
            .navigationTitle("图片隐写术")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("好的") {}
            } message: {
                Text(errorMessage)
            }
            .alert("保存成功", isPresented: $showSaveSuccess) {
                Button("好的") {}
            } message: {
                Text("含隐藏消息的图片已保存到相册")
            }
        }
    }

    // MARK: - Header

    var headerView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "11998e").opacity(0.2), Color(hex: "38ef7d").opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)

                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Color(hex: "11998e"))
            }

            Text("将秘密文字隐藏在图片中")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Mode Toggle

    var modeToggle: some View {
        HStack(spacing: 0) {
            Button(action: {
                withAnimation { isEncodeMode = true; decodedMessage = nil; resultImage = nil }
            }) {
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                    Text("隐藏消息")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isEncodeMode ? Color(hex: "11998e") : Color.clear)
                .foregroundColor(isEncodeMode ? .white : .secondary)
            }

            Button(action: {
                withAnimation { isEncodeMode = false; resultImage = nil; secretMessage = "" }
            }) {
                VStack(spacing: 6) {
                    Image(systemName: "lock.open.fill")
                        .font(.title3)
                    Text("提取消息")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(!isEncodeMode ? Color(hex: "11998e") : Color.clear)
                .foregroundColor(!isEncodeMode ? .white : .secondary)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Image Selection

    var imageSelectionSection: some View {
        VStack(spacing: 12) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(12)

                if let cgImage = image.cgImage {
                    Text("\(cgImage.width) x \(cgImage.height) · 最大可隐藏 \(formatBytes(service.maxMessageLength(for: image)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text(selectedImage == nil ? "选择图片" : "更换图片")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(hex: "11998e").opacity(0.1))
                .foregroundColor(Color(hex: "11998e"))
                .cornerRadius(14)
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            selectedImage = image
                            resultImage = nil
                            decodedMessage = nil
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    // MARK: - Encode Section

    var encodeSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("秘密消息")
                    .font(.headline)

                TextEditor(text: $secretMessage)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(hex: "f0f2ff"))
                    .cornerRadius(12)

                if let image = selectedImage {
                    let maxLen = service.maxMessageLength(for: image)
                    let currentLen = secretMessage.utf8.count
                    Text("\(currentLen) / \(maxLen) 字节")
                        .font(.caption)
                        .foregroundColor(currentLen > maxLen ? .red : .secondary)
                }
            }

            Button(action: encode) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    }
                    Image(systemName: "eye.slash")
                    Text("隐藏到图片中")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "11998e"), Color(hex: "38ef7d")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(selectedImage == nil || secretMessage.isEmpty || isProcessing)

            if let result = resultImage {
                VStack(spacing: 12) {
                    Text("隐写完成!")
                        .font(.headline)
                        .foregroundColor(Color(hex: "11998e"))

                    Image(uiImage: result)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(12)

                    Button(action: saveImage) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("保存到相册")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "667eea").opacity(0.1))
                        .foregroundColor(Color(hex: "667eea"))
                        .cornerRadius(14)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    // MARK: - Decode Section

    var decodeSection: some View {
        VStack(spacing: 16) {
            Button(action: decode) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    }
                    Image(systemName: "eye")
                    Text("提取隐藏消息")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "11998e"), Color(hex: "38ef7d")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(selectedImage == nil || isProcessing)

            if let message = decodedMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: "11998e"))
                        Text("发现隐藏消息!")
                            .font(.headline)
                            .foregroundColor(Color(hex: "11998e"))
                        Spacer()
                        Button(action: { UIPasteboard.general.string = message }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                Text("复制")
                            }
                            .font(.caption)
                            .foregroundColor(Color(hex: "667eea"))
                        }
                    }

                    Text(message)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "f0fff0"))
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    // MARK: - Actions

    func encode() {
        guard let image = selectedImage else { return }
        isProcessing = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try service.hideMessage(secretMessage, in: image)
                DispatchQueue.main.async {
                    resultImage = result
                    isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    showError = true
                    isProcessing = false
                }
            }
        }
    }

    func decode() {
        guard let image = selectedImage else { return }
        isProcessing = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let message = try service.extractMessage(from: image)
                DispatchQueue.main.async {
                    decodedMessage = message
                    isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    showError = true
                    isProcessing = false
                }
            }
        }
    }

    func saveImage() {
        guard let image = resultImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        showSaveSuccess = true
    }

    func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return "\(bytes / 1024) KB" }
        return String(format: "%.1f MB", Double(bytes) / 1048576.0)
    }
}

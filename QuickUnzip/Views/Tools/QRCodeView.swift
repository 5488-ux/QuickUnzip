import SwiftUI

struct QRCodeView: View {
    @EnvironmentObject var store: FileStore
    @Environment(\.dismiss) var dismiss
    @State private var selectedArchive: FileItem?
    @State private var showFilePicker = false
    @State private var password = ""
    @State private var usePassword = false
    @State private var qrImage: UIImage?
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var qrType: QRType = .info

    enum QRType: String, CaseIterable {
        case info = "基本信息"
        case stylized = "精美分享图"

        var icon: String {
            switch self {
            case .info: return "qrcode"
            case .stylized: return "photo.on.rectangle.angled"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "f0f4ff"), Color(hex: "dce6ff")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        infoCard

                        selectArchiveSection

                        if selectedArchive != nil {
                            qrTypeSelector
                            passwordSection
                            generateButton
                        }

                        if let image = (qrType == .info ? qrImage : shareImage) {
                            qrDisplaySection(image: image)
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("二维码分享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker { url in
                    handleArchiveSelection(url)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = (qrType == .info ? qrImage : shareImage) {
                    ShareSheet(items: [image])
                }
            }
            .alert("错误", isPresented: $showError) {
                Button("确定") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Info Card

    var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "qrcode")
                    .font(.title2)
                    .foregroundColor(Color(hex: "54a0ff"))

                Text("功能说明")
                    .font(.headline)
            }

            Text("生成包含压缩包信息的二维码，方便快速分享文件名、大小、格式等信息。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .padding(.horizontal)
    }

    // MARK: - Select Archive Section

    var selectArchiveSection: some View {
        VStack(spacing: 16) {
            if let archive = selectedArchive {
                HStack(spacing: 14) {
                    Image(systemName: "doc.zipper")
                        .font(.title2)
                        .foregroundColor(Color(hex: "54a0ff"))
                        .frame(width: 48, height: 48)
                        .background(Color(hex: "54a0ff").opacity(0.1))
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(archive.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)

                        Text(archive.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        selectedArchive = nil
                        qrImage = nil
                        shareImage = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                )
            } else {
                Button(action: { showFilePicker = true }) {
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "54a0ff").opacity(0.6))

                        Text("选择压缩包")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("支持所有格式")
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
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - QR Type Selector

    var qrTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("二维码样式")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 12) {
                ForEach(QRType.allCases, id: \.self) { type in
                    Button(action: { qrType = type; qrImage = nil; shareImage = nil }) {
                        HStack {
                            Image(systemName: type.icon)
                            Text(type.rawValue)
                                .font(.subheadline)
                        }
                        .foregroundColor(qrType == type ? .white : Color(hex: "54a0ff"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            qrType == type ?
                                Color(hex: "54a0ff") :
                                Color(hex: "54a0ff").opacity(0.1)
                        )
                        .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Password Section

    var passwordSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "lock")
                    .foregroundColor(.gray)
                    .frame(width: 24)

                Text("包含密码")
                    .foregroundColor(.primary)

                Spacer()

                Toggle("", isOn: $usePassword)
                    .tint(Color(hex: "54a0ff"))
            }
            .padding()

            if usePassword {
                Divider().padding(.leading, 48)

                HStack {
                    Image(systemName: "key")
                        .foregroundColor(.gray)
                        .frame(width: 24)

                    SecureField("输入密码", text: $password)
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

    // MARK: - Generate Button

    var generateButton: some View {
        Button(action: generateQRCode) {
            HStack {
                Image(systemName: "sparkles")
                Text("生成二维码")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "54a0ff"), Color(hex: "3742fa")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: Color(hex: "54a0ff").opacity(0.3), radius: 8, y: 4)
        }
        .padding(.horizontal)
    }

    // MARK: - QR Display Section

    func qrDisplaySection(image: UIImage) -> some View {
        VStack(spacing: 16) {
            Text(qrType == .info ? "二维码" : "分享图")
                .font(.headline)

            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: qrType == .info ? 300 : .infinity)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 12, y: 6)

            HStack(spacing: 12) {
                Button(action: { saveToPhotos(image) }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("保存")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "2ed573"))
                    .cornerRadius(10)
                }

                Button(action: { showShareSheet = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("分享")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "54a0ff"))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }

    // MARK: - Actions

    func handleArchiveSelection(_ url: URL) {
        do {
            let localURL = try store.importFile(from: url)
            if let item = store.archives.first(where: { $0.url == localURL }) {
                selectedArchive = item
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func generateQRCode() {
        guard let archive = selectedArchive else { return }

        let pwd = usePassword && !password.isEmpty ? password : nil

        DispatchQueue.global(qos: .userInitiated).async {
            let image: UIImage?

            switch qrType {
            case .info:
                image = QRCodeGenerator.generateArchiveInfoQR(archiveURL: archive.url, password: pwd)
            case .stylized:
                image = QRCodeGenerator.createShareableImage(archiveURL: archive.url, password: pwd)
            }

            DispatchQueue.main.async {
                if let image = image {
                    if qrType == .info {
                        qrImage = image
                    } else {
                        shareImage = image
                    }
                } else {
                    errorMessage = "生成二维码失败"
                    showError = true
                }
            }
        }
    }

    func saveToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        // You might want to show a success message here
    }
}

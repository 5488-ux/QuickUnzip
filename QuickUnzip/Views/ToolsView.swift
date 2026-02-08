import SwiftUI

struct ToolsView: View {
    @EnvironmentObject var store: FileStore
    @State private var selectedTool: Tool?

    enum Tool: String, CaseIterable, Identifiable {
        case encodingFixer = "乱码修复"
        case cleaner = "压缩包瘦身"
        case analyzer = "压缩率分析"
        case qrcode = "二维码分享"
        case morseCode = "摩斯密码"
        case steganography = "图片隐写术"
        case privacyVault = "隐私保险箱"
        case fileHash = "文件哈希校验"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .encodingFixer: return "textformat.abc"
            case .cleaner: return "trash.slash"
            case .analyzer: return "chart.bar.fill"
            case .qrcode: return "qrcode"
            case .morseCode: return "wave.3.right"
            case .steganography: return "eye.slash.fill"
            case .privacyVault: return "lock.shield.fill"
            case .fileHash: return "checkmark.shield.fill"
            }
        }

        var color: Color {
            switch self {
            case .encodingFixer: return Color(hex: "5f27cd")
            case .cleaner: return Color(hex: "00d2d3")
            case .analyzer: return Color(hex: "ff9ff3")
            case .qrcode: return Color(hex: "54a0ff")
            case .morseCode: return Color(hex: "ffd700")
            case .steganography: return Color(hex: "11998e")
            case .privacyVault: return Color(hex: "764ba2")
            case .fileHash: return Color(hex: "fc4a1a")
            }
        }

        var description: String {
            switch self {
            case .encodingFixer: return "修复 Windows ZIP 中文乱码"
            case .cleaner: return "清理系统垃圾文件，减小体积"
            case .analyzer: return "分析压缩效果和文件类型"
            case .qrcode: return "生成二维码快速分享"
            case .morseCode: return "文字转摩斯密码，手电筒发信号"
            case .steganography: return "在图片中隐藏/提取秘密信息"
            case .privacyVault: return "Face ID 保护的私密文件存储"
            case .fileHash: return "MD5/SHA256 校验，验证完整性"
            }
        }

        var isNew: Bool {
            switch self {
            case .morseCode, .steganography, .privacyVault, .fileHash: return true
            default: return false
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "f5f7fa"), Color(hex: "e8ecf1")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection

                        toolsGrid

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("工具箱")
            .sheet(item: $selectedTool) { tool in
                toolDetailView(for: tool)
            }
        }
    }

    // MARK: - Header Section

    var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "667eea").opacity(0.2), Color(hex: "764ba2").opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "667eea"))
            }

            Text("专业工具")
                .font(.title2.bold())

            Text("小众但强大的压缩包处理工具")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Tools Grid

    var toolsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(Tool.allCases) { tool in
                ToolCard(tool: tool) {
                    selectedTool = tool
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Tool Detail Views

    @ViewBuilder
    func toolDetailView(for tool: Tool) -> some View {
        switch tool {
        case .encodingFixer:
            EncodingFixerView()
                .environmentObject(store)
        case .cleaner:
            CleanerView()
                .environmentObject(store)
        case .analyzer:
            AnalyzerView()
                .environmentObject(store)
        case .qrcode:
            QRCodeView()
                .environmentObject(store)
        case .morseCode:
            MorseCodeToolView()
        case .steganography:
            SteganographyToolView()
        case .privacyVault:
            PrivacyVaultView()
        case .fileHash:
            FileHashView()
        }
    }
}

// MARK: - Tool Card

struct ToolCard: View {
    let tool: ToolsView.Tool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(tool.color.opacity(0.15))
                            .frame(width: 64, height: 64)

                        Image(systemName: tool.icon)
                            .font(.system(size: 28))
                            .foregroundColor(tool.color)
                    }

                    if tool.isNew {
                        Text("NEW")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(hex: "ff6b6b"))
                            .cornerRadius(4)
                            .offset(x: 8, y: -4)
                    }
                }

                VStack(spacing: 4) {
                    Text(tool.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(tool.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

struct ToolsView_Previews: PreviewProvider {
    static var previews: some View {
        ToolsView()
            .environmentObject(FileStore())
    }
}

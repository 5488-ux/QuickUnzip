import SwiftUI

struct UpdateLogView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Announcement Card
                    announcementCard

                    // Update Log
                    updateLogSection

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .background(Color(hex: "f8f9ff").ignoresSafeArea())
            .navigationTitle("更新日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Announcement Card

    var announcementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "megaphone.fill")
                    .foregroundColor(.white)
                Text("公告")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("NEW")
                    .font(.caption2.bold())
                    .foregroundColor(Color(hex: "667eea"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .cornerRadius(8)
            }

            Text("快速解压 v2.9.1 正式发布！")
                .font(.subheadline.bold())
                .foregroundColor(.white)

            Text("本次更新修复了压缩功能的多个问题，新增了密码保护、UTF-8文件名支持，并优化了整体稳定性。感谢大家的支持！")
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(4)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Update Log Section

    var updateLogSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("版本历史")
                .font(.headline)
                .padding(.horizontal)

            // v2.9.1
            UpdateLogCard(
                version: "2.9.1",
                date: "2026年2月6日",
                isLatest: true,
                changes: [
                    UpdateItem(type: .fix, text: "修复压缩密码不生效的问题"),
                    UpdateItem(type: .fix, text: "修复压缩后文件名乱码问题"),
                    UpdateItem(type: .fix, text: "修复压缩后解压文件损坏问题"),
                    UpdateItem(type: .new, text: "支持 PKWARE 传统加密"),
                    UpdateItem(type: .new, text: "文件名 UTF-8 编码支持"),
                    UpdateItem(type: .new, text: "添加更新日志和公告页面")
                ]
            )

            // v2.9.0
            UpdateLogCard(
                version: "2.9.0",
                date: "2026年2月6日",
                isLatest: false,
                changes: [
                    UpdateItem(type: .new, text: "新增压缩功能"),
                    UpdateItem(type: .new, text: "底部导航栏 (解压/压缩)"),
                    UpdateItem(type: .new, text: "支持 ZIP、7Z 格式压缩"),
                    UpdateItem(type: .new, text: "自定义压缩包名称"),
                    UpdateItem(type: .new, text: "可选密码保护"),
                    UpdateItem(type: .new, text: "添加文件、图片、视频")
                ]
            )

            // v2.8.0
            UpdateLogCard(
                version: "2.8.0",
                date: "2026年2月6日",
                isLatest: false,
                changes: [
                    UpdateItem(type: .new, text: "支持 RAR、7Z、TAR.GZ 解压"),
                    UpdateItem(type: .new, text: "支持 7z.001 分卷压缩包"),
                    UpdateItem(type: .new, text: "添加设置页面"),
                    UpdateItem(type: .new, text: "存储空间统计"),
                    UpdateItem(type: .new, text: "批量选择删除"),
                    UpdateItem(type: .improve, text: "全新 UI 设计")
                ]
            )

            // v1.0.0
            UpdateLogCard(
                version: "1.0.0",
                date: "2026年2月5日",
                isLatest: false,
                changes: [
                    UpdateItem(type: .new, text: "首次发布"),
                    UpdateItem(type: .new, text: "支持 ZIP 格式解压"),
                    UpdateItem(type: .new, text: "文件预览功能"),
                    UpdateItem(type: .new, text: "文件管理功能")
                ]
            )
        }
    }
}

// MARK: - Update Log Card

struct UpdateLogCard: View {
    let version: String
    let date: String
    let isLatest: Bool
    let changes: [UpdateItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("v\(version)")
                    .font(.headline)
                    .foregroundColor(isLatest ? Color(hex: "667eea") : .primary)

                if isLatest {
                    Text("最新")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "667eea"))
                        .cornerRadius(4)
                }

                Spacer()

                Text(date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(changes) { item in
                    HStack(alignment: .top, spacing: 8) {
                        item.type.icon
                            .font(.caption)
                            .foregroundColor(item.type.color)
                            .frame(width: 20)

                        Text(item.text)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isLatest ? Color(hex: "667eea").opacity(0.3) : .clear, lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Update Item

struct UpdateItem: Identifiable {
    let id = UUID()
    let type: UpdateType
    let text: String
}

enum UpdateType {
    case new
    case fix
    case improve

    var icon: Image {
        switch self {
        case .new: return Image(systemName: "plus.circle.fill")
        case .fix: return Image(systemName: "wrench.fill")
        case .improve: return Image(systemName: "arrow.up.circle.fill")
        }
    }

    var color: Color {
        switch self {
        case .new: return .green
        case .fix: return .orange
        case .improve: return .blue
        }
    }

    var label: String {
        switch self {
        case .new: return "新增"
        case .fix: return "修复"
        case .improve: return "优化"
        }
    }
}

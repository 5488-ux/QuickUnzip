import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @EnvironmentObject var store: FileStore
    @EnvironmentObject var authService: AppleAuthService
    @StateObject private var csAPI = CustomerServiceAPI.shared
    @State private var showCustomerService = false
    @State private var showAIChat = false
    @State private var showSettings = false
    @State private var showUpdateLog = false
    @State private var showFeedback = false
    @State private var showShare = false
    @State private var storageInfo = StorageInfo()

    struct StorageInfo {
        var archiveCount: Int = 0
        var extractedCount: Int = 0
        var totalSize: String = "0 B"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 用户卡片
                    userCard

                    // 存储统计
                    storageCard

                    // 功能菜单
                    menuSection

                    // 关于
                    aboutSection

                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .background(Color(hex: "f8f9ff").ignoresSafeArea())
            .navigationTitle("我的")
            .onAppear {
                calculateStorage()
            }
            .sheet(isPresented: $showCustomerService) {
                CustomerServiceView()
            }
            .sheet(isPresented: $showAIChat) {
                AIChatView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showUpdateLog) {
                UpdateLogView()
            }
            .sheet(isPresented: $showFeedback) {
                FeedbackView()
            }
            .sheet(isPresented: $showShare) {
                ShareAppView()
            }
        }
    }

    // MARK: - User Card

    var userCard: some View {
        VStack(spacing: 16) {
            if authService.isLoggedIn {
                // 已登录：用户头像
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)

                    Text(String(authService.userName.prefix(1)).uppercased())
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(spacing: 4) {
                    Text(authService.userName.isEmpty ? "用户" : authService.userName)
                        .font(.title2.bold())
                        .foregroundColor(.primary)

                    if !authService.userEmail.isEmpty {
                        Text(authService.userEmail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("v3.1.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // VIP 标签
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Color(hex: "ffd700"))
                    Text("永久免费 · 无广告")
                        .font(.caption.bold())
                        .foregroundColor(Color(hex: "ffd700"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(hex: "ffd700").opacity(0.15))
                .cornerRadius(20)

                // 登出按钮
                Button(action: {
                    authService.logout()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.caption)
                        Text("退出登录")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                }
            } else {
                // 未登录：Apple 登录按钮
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)

                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }

                VStack(spacing: 4) {
                    Text("免费解压王")
                        .font(.title2.bold())
                        .foregroundColor(.primary)

                    Text("v3.1.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                            handleAppleCredential(credential)
                        }
                    case .failure(let error):
                        print("Apple Sign In failed: \(error)")
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 44)
                .cornerRadius(22)
                .padding(.horizontal, 40)

                // VIP 标签
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Color(hex: "ffd700"))
                    Text("永久免费 · 无广告")
                        .font(.caption.bold())
                        .foregroundColor(Color(hex: "ffd700"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(hex: "ffd700").opacity(0.15))
                .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        )
        .padding(.horizontal)
    }

    private func handleAppleCredential(_ credential: ASAuthorizationAppleIDCredential) {
        let userId = credential.user
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        let email = credential.email ?? ""

        let savedName = UserDefaults.standard.string(forKey: "apple_user_name") ?? ""
        let savedEmail = UserDefaults.standard.string(forKey: "apple_user_email") ?? ""
        let finalName = fullName.isEmpty ? savedName : fullName
        let finalEmail = email.isEmpty ? savedEmail : email

        UserDefaults.standard.set(userId, forKey: "apple_user_id")
        if !finalName.isEmpty {
            UserDefaults.standard.set(finalName, forKey: "apple_user_name")
        }
        if !finalEmail.isEmpty {
            UserDefaults.standard.set(finalEmail, forKey: "apple_user_email")
        }

        authService.isLoggedIn = true
        authService.userName = finalName
        authService.userEmail = finalEmail

        // Send to server
        sendAppleLoginToServer(appleUserId: userId, name: finalName, email: finalEmail)
    }

    private func sendAppleLoginToServer(appleUserId: String, name: String, email: String) {
        guard let url = URL(string: "https://781391.cn/admin/api.php?action=apple_login") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let deviceId = UserDefaults.standard.string(forKey: "cs_device_id") ?? UUID().uuidString
        let body: [String: Any] = [
            "device_id": deviceId,
            "apple_user_id": appleUserId,
            "name": name,
            "email": email
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("Apple login server sync failed: \(error)")
            }
        }.resume()
    }

    // MARK: - Storage Card

    var storageCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("存储统计")
                    .font(.headline)
                Spacer()
                Button("管理") {
                    showSettings = true
                }
                .font(.subheadline)
                .foregroundColor(Color(hex: "667eea"))
            }

            HStack(spacing: 20) {
                StorageStatItem(
                    icon: "doc.zipper",
                    title: "压缩包",
                    value: "\(storageInfo.archiveCount)",
                    color: Color(hex: "667eea")
                )

                StorageStatItem(
                    icon: "folder.fill",
                    title: "已解压",
                    value: "\(storageInfo.extractedCount)",
                    color: Color(hex: "764ba2")
                )

                StorageStatItem(
                    icon: "internaldrive",
                    title: "总占用",
                    value: storageInfo.totalSize,
                    color: Color(hex: "f093fb")
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        )
        .padding(.horizontal)
    }

    // MARK: - Menu Section

    var menuSection: some View {
        VStack(spacing: 0) {
            // 在线客服
            MenuRow(
                icon: "headphones",
                title: "在线客服",
                subtitle: "有问题随时咨询",
                badge: csAPI.unreadCount > 0 ? "\(csAPI.unreadCount)" : nil,
                iconColors: [Color(hex: "667eea"), Color(hex: "764ba2")]
            ) {
                showCustomerService = true
            }

            Divider().padding(.leading, 56)

            // AI 助手
            MenuRow(
                icon: "sparkles",
                title: "DeepSeek AI",
                subtitle: "图片识别 · 深度思考 · 多轮对话",
                badge: "AI",
                badgeColor: Color(hex: "4f46e5"),
                iconColors: [Color(hex: "4f46e5"), Color(hex: "7c3aed")]
            ) {
                showAIChat = true
            }

            Divider().padding(.leading, 56)

            // 意见反馈
            MenuRow(
                icon: "bubble.left.and.bubble.right",
                title: "意见反馈",
                subtitle: "帮助我们做得更好",
                iconColors: [Color(hex: "11998e"), Color(hex: "38ef7d")]
            ) {
                showFeedback = true
            }

            Divider().padding(.leading, 56)

            // 分享应用
            MenuRow(
                icon: "square.and.arrow.up",
                title: "分享应用",
                subtitle: "推荐给朋友",
                iconColors: [Color(hex: "fc4a1a"), Color(hex: "f7b733")]
            ) {
                showShare = true
            }

            Divider().padding(.leading, 56)

            // 更新日志
            MenuRow(
                icon: "doc.text",
                title: "更新日志",
                subtitle: "查看版本历史",
                badge: "NEW",
                badgeColor: Color(hex: "ff6b6b"),
                iconColors: [Color(hex: "6a11cb"), Color(hex: "2575fc")]
            ) {
                showUpdateLog = true
            }

            Divider().padding(.leading, 56)

            // 设置
            MenuRow(
                icon: "gearshape",
                title: "设置",
                subtitle: "清理缓存、格式支持",
                iconColors: [Color(hex: "606c88"), Color(hex: "3f4c6b")]
            ) {
                showSettings = true
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        )
        .padding(.horizontal)
    }

    // MARK: - About Section

    var aboutSection: some View {
        VStack(spacing: 0) {
            MenuRow(
                icon: "star",
                title: "给个好评",
                subtitle: "您的支持是我们前进的动力",
                iconColors: [Color(hex: "f7971e"), Color(hex: "ffd200")]
            ) {
                // 跳转到 App Store
            }

            Divider().padding(.leading, 56)

            MenuRow(
                icon: "info.circle",
                title: "关于我们",
                subtitle: "免费解压王 v3.1.0",
                iconColors: [Color(hex: "667eea"), Color(hex: "764ba2")]
            ) {
                // 关于页面
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        )
        .padding(.horizontal)
    }

    func calculateStorage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let (archives, extracted, total) = store.calculateStorageUsed()
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file

            DispatchQueue.main.async {
                storageInfo.archiveCount = store.archives.count
                storageInfo.extractedCount = store.recentExtractions.count
                storageInfo.totalSize = formatter.string(fromByteCount: total)
            }
        }
    }
}

// MARK: - Storage Stat Item

struct StorageStatItem: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }

            Text(value)
                .font(.headline)
                .foregroundColor(.primary)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Menu Row

struct MenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var badge: String? = nil
    var badgeColor: Color = Color(hex: "667eea")
    let iconColors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: iconColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 38, height: 38)

                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }

                // 文字
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)

                        if let badge = badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badgeColor)
                                .cornerRadius(4)
                        }
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Feedback View

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var contactInfo = ""
    @State private var feedbackType = 0
    @State private var showAlert = false

    let feedbackTypes = ["功能建议", "问题反馈", "其他"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("反馈类型", selection: $feedbackType) {
                        ForEach(0..<feedbackTypes.count, id: \.self) { index in
                            Text(feedbackTypes[index]).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("反馈内容") {
                    TextEditor(text: $feedbackText)
                        .frame(minHeight: 150)
                }

                Section("联系方式（选填）") {
                    TextField("邮箱或手机号", text: $contactInfo)
                        .keyboardType(.emailAddress)
                }

                Section {
                    Button(action: submitFeedback) {
                        HStack {
                            Spacer()
                            Text("提交反馈")
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("意见反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("提交成功", isPresented: $showAlert) {
                Button("好的") {
                    dismiss()
                }
            } message: {
                Text("感谢您的反馈，我们会认真处理！")
            }
        }
    }

    func submitFeedback() {
        // 通过客服系统发送反馈
        Task {
            let content = "【\(feedbackTypes[feedbackType])】\n\(feedbackText)\n\n联系方式: \(contactInfo.isEmpty ? "未提供" : contactInfo)"
            _ = try? await CustomerServiceAPI.shared.sendMessage(content)
            await MainActor.run {
                showAlert = true
            }
        }
    }
}

// MARK: - Share App View

struct ShareAppView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()

                // App 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 100, height: 100)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                }

                VStack(spacing: 8) {
                    Text("免费解压王")
                        .font(.title.bold())

                    Text("免费 · 无广告 · 多格式支持")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // 分享按钮
                VStack(spacing: 16) {
                    ShareLink(item: URL(string: "https://apps.apple.com/app/id123456789")!) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("分享给朋友")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                    }

                    Button(action: {
                        UIPasteboard.general.string = "免费解压王 - 免费无广告的解压缩工具"
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("复制分享文案")
                        }
                        .font(.headline)
                        .foregroundColor(Color(hex: "667eea"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "667eea").opacity(0.1))
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 30)

                Spacer()
                Spacer()
            }
            .navigationTitle("分享应用")
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
}

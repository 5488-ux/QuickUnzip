import SwiftUI

struct CustomerServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CustomerServiceViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 消息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // 欢迎消息
                            if viewModel.messages.isEmpty && !viewModel.isLoading {
                                welcomeMessage
                            }

                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }

                            // 加载中
                            if viewModel.isSending {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding(.trailing, 20)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color(hex: "f5f5f5"))

                // 输入区域
                inputArea
            }
            .navigationTitle("在线客服")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadMessages()
            }
            .onDisappear {
                viewModel.stopPolling()
            }
        }
    }

    // MARK: - Welcome Message

    var welcomeMessage: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.fill")
                .font(.system(size: 50))
                .foregroundColor(Color(hex: "667eea"))

            Text("欢迎使用在线客服")
                .font(.headline)
                .foregroundColor(.primary)

            Text("有任何问题都可以在这里咨询，我们会尽快回复您。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // 快捷问题
            VStack(spacing: 10) {
                QuickQuestionButton(text: "如何使用压缩功能？") {
                    viewModel.sendMessage("如何使用压缩功能？")
                }
                QuickQuestionButton(text: "支持哪些压缩格式？") {
                    viewModel.sendMessage("支持哪些压缩格式？")
                }
                QuickQuestionButton(text: "为什么解压失败？") {
                    viewModel.sendMessage("为什么解压失败？")
                }
            }
            .padding(.top, 10)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Input Area

    var inputArea: some View {
        HStack(spacing: 12) {
            // 输入框
            TextField("输入消息...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "f0f0f0"))
                .cornerRadius(20)
                .lineLimit(1...4)
                .focused($isInputFocused)

            // 发送按钮
            Button(action: {
                viewModel.sendMessage(viewModel.inputText)
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.gray
                        : LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: CSMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 60)
                VStack(alignment: .trailing, spacing: 4) {
                    // 消息气泡
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(18)
                        .cornerRadius(4, corners: .bottomRight)

                    // 时间和状态
                    HStack(spacing: 4) {
                        Text(formatTime(message.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if message.isRead {
                            Text("已读")
                                .font(.caption2)
                                .foregroundColor(Color(hex: "667eea"))
                        }
                    }
                }
                .padding(.trailing, 16)
            } else {
                // 客服头像
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "headphones")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    )
                    .padding(.leading, 12)

                VStack(alignment: .leading, spacing: 4) {
                    // 消息气泡
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(18)
                        .cornerRadius(4, corners: .bottomLeft)
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                    // 时间
                    Text(formatTime(message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 60)
            }
        }
    }

    func formatTime(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let date = formatter.date(from: dateString) else { return "" }

        let now = Date()
        let diff = now.timeIntervalSince(date)

        if diff < 60 {
            return "刚刚"
        } else if diff < 3600 {
            return "\(Int(diff / 60))分钟前"
        } else if Calendar.current.isDateInToday(date) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            return timeFormatter.string(from: date)
        } else {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "MM/dd HH:mm"
            return timeFormatter.string(from: date)
        }
    }
}

// MARK: - Quick Question Button

struct QuickQuestionButton: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .foregroundColor(Color(hex: "667eea"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "667eea").opacity(0.1))
                .cornerRadius(20)
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - View Model

class CustomerServiceViewModel: ObservableObject {
    @Published var messages: [CSMessage] = []
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var isSending = false

    private let api = CustomerServiceAPI.shared
    private var pollTimer: Timer?

    func loadMessages() {
        isLoading = true

        Task {
            do {
                // 先注册用户
                try await api.registerUser(nickname: "iOS用户")

                // 获取消息
                let msgs = try await api.getMessages()
                await MainActor.run {
                    self.messages = msgs
                    self.isLoading = false
                }

                // 开始轮询
                startPolling()
            } catch {
                print("加载消息失败: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    func sendMessage(_ content: String) {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSending = true
        inputText = ""

        // 立即添加到本地
        let tempMessage = CSMessage(
            id: Int.random(in: 100000...999999),
            content: text,
            isFromUser: true,
            isRead: false,
            createdAt: formatCurrentTime()
        )
        messages.append(tempMessage)

        Task {
            do {
                let success = try await api.sendMessage(text)
                if success {
                    // 重新加载消息
                    let msgs = try await api.getMessages()
                    await MainActor.run {
                        self.messages = msgs
                        self.isSending = false
                    }
                }
            } catch {
                print("发送失败: \(error)")
                await MainActor.run {
                    self.isSending = false
                }
            }
        }
    }

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.pollNewMessages()
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollNewMessages() {
        guard let lastId = messages.last?.id else { return }

        Task {
            do {
                let newMsgs = try await api.getMessages(lastId: lastId)
                if !newMsgs.isEmpty {
                    await MainActor.run {
                        self.messages.append(contentsOf: newMsgs)
                    }
                }
            } catch {
                print("轮询失败: \(error)")
            }
        }
    }

    private func formatCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}

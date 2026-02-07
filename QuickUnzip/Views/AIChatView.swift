import SwiftUI

struct AIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatService = AIChatService.shared
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Message list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if chatService.messages.isEmpty && !chatService.isLoading {
                                welcomeSection
                            }

                            ForEach(chatService.messages) { message in
                                AIChatBubbleView(message: message)
                                    .id(message.id)
                            }

                            if chatService.isLoading {
                                HStack(spacing: 8) {
                                    // AI avatar
                                    Circle()
                                        .fill(LinearGradient(
                                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Image(systemName: "brain.head.profile")
                                                .font(.system(size: 16))
                                                .foregroundColor(.white)
                                        )
                                        .padding(.leading, 12)

                                    TypingIndicator()
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .background(Color.white)
                                        .cornerRadius(18)
                                        .cornerRadius(4, corners: .bottomLeft)
                                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

                                    Spacer()
                                }
                                .id("loading")
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .onChange(of: chatService.messages.count) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: chatService.isLoading) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                }
                .background(Color(hex: "f5f5f5"))

                // Input area
                chatInputArea
            }
            .navigationTitle("AI 助手")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            chatService.clearHistory()
                        } label: {
                            Label("清空聊天记录", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Color(hex: "667eea"))
                    }
                }
            }
        }
    }

    // MARK: - Welcome Section

    var welcomeSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                    .shadow(color: Color(hex: "667eea").opacity(0.4), radius: 12, y: 6)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            Text("AI 智能助手")
                .font(.title2.bold())
                .foregroundColor(.primary)

            Text("我可以回答关于文件压缩、解压缩等问题，也可以和你聊天。试试问我吧！")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Quick questions
            VStack(spacing: 10) {
                AIQuickButton(text: "如何压缩文件？") {
                    sendMessage("如何压缩文件？")
                }
                AIQuickButton(text: "支持哪些压缩格式？") {
                    sendMessage("支持哪些压缩格式？")
                }
                AIQuickButton(text: "解压密码忘了怎么办？") {
                    sendMessage("解压密码忘了怎么办？")
                }
                AIQuickButton(text: "ZIP和RAR有什么区别？") {
                    sendMessage("ZIP和RAR有什么区别？")
                }
            }
            .padding(.top, 10)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Input Area

    var chatInputArea: some View {
        HStack(spacing: 12) {
            TextField("输入消息...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "f0f0f0"))
                .cornerRadius(20)
                .lineLimit(1...4)
                .focused($isInputFocused)

            Button(action: {
                sendMessage(inputText)
            }) {
                Circle()
                    .fill(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? AnyShapeStyle(Color.gray.opacity(0.3))
                        : AnyShapeStyle(LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatService.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
    }

    // MARK: - Helpers

    private func sendMessage(_ text: String) {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        inputText = ""

        Task {
            await chatService.sendMessage(content)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if chatService.isLoading {
            withAnimation { proxy.scrollTo("loading", anchor: .bottom) }
        } else if let last = chatService.messages.last {
            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }
}

// MARK: - Chat Bubble View

struct AIChatBubbleView: View {
    let message: AIChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 60)
                VStack(alignment: .trailing, spacing: 4) {
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

                    Text(formatTime(message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 16)
            } else {
                // AI avatar
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    )
                    .padding(.leading, 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(18)
                        .cornerRadius(4, corners: .bottomLeft)
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                        .textSelection(.enabled)

                    Text(formatTime(message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 60)
            }
        }
    }

    func formatTime(_ date: Date) -> String {
        let now = Date()
        let diff = now.timeIntervalSince(date)

        if diff < 60 {
            return "刚刚"
        } else if diff < 3600 {
            return "\(Int(diff / 60))分钟前"
        } else if Calendar.current.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd HH:mm"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Quick Button

struct AIQuickButton: View {
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

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color(hex: "667eea"))
                    .frame(width: 8, height: 8)
                    .scaleEffect(dotScale(for: index))
                    .opacity(dotOpacity(for: index))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
    }

    private func dotScale(for index: Int) -> CGFloat {
        let offset = Double(index) * 0.2
        return phase > offset ? 1.0 : 0.5
    }

    private func dotOpacity(for index: Int) -> Double {
        let offset = Double(index) * 0.2
        return phase > offset ? 1.0 : 0.4
    }
}

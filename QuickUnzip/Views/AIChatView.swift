import SwiftUI
import PhotosUI

struct AIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatService = AIChatService.shared
    @State private var inputText = ""
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showConversations = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Model indicator
                modelIndicator

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
                                loadingBubble
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

                // Image preview
                if let image = selectedImage {
                    imagePreviewBar(image)
                }

                // Input area
                chatInputArea
            }
            .navigationTitle("AI 助手")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        // Thinking toggle
                        Button {
                            chatService.thinkingEnabled.toggle()
                        } label: {
                            Image(systemName: chatService.thinkingEnabled ? "brain.fill" : "brain")
                                .foregroundColor(chatService.thinkingEnabled ? Color(hex: "667eea") : .secondary)
                        }

                        // New chat
                        Button {
                            chatService.newConversation()
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(Color(hex: "667eea"))
                        }

                        // Conversations list
                        Button {
                            showConversations = true
                        } label: {
                            Image(systemName: "list.bullet")
                                .foregroundColor(Color(hex: "667eea"))
                        }
                    }
                }
            }
            .sheet(isPresented: $showConversations) {
                ConversationListView(chatService: chatService)
            }
            .onChange(of: selectedPhotoItem) { newItem in
                loadImage(from: newItem)
            }
        }
    }

    // MARK: - Model Indicator

    var modelIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            Text(chatService.thinkingEnabled ? "深度思考模式" : "AI 智能助手")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.8))
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

            Text("AI 助手")
                .font(.title2.bold())
                .foregroundColor(.primary)

            Text("支持图片识别和深度思考模式\n试试问我任何问题！")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Feature tags
            HStack(spacing: 8) {
                featureTag(icon: "photo", text: "图片识别")
                featureTag(icon: "brain", text: "深度思考")
                featureTag(icon: "bubble.left.and.bubble.right", text: "多轮对话")
            }
            .padding(.top, 4)

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

    private func featureTag(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundColor(Color(hex: "667eea"))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(hex: "667eea").opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Loading Bubble

    var loadingBubble: some View {
        HStack(spacing: 8) {
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
                if chatService.thinkingEnabled {
                    Text("思考中...")
                        .font(.caption)
                        .foregroundColor(Color(hex: "667eea"))
                }
                TypingIndicator()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(18)
            .cornerRadius(4, corners: .bottomLeft)
            .conditionalGlassEffect()
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)

            Spacer()
        }
        .id("loading")
    }

    // MARK: - Image Preview

    func imagePreviewBar(_ image: UIImage) -> some View {
        HStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .cornerRadius(10)
                .clipped()

            VStack(alignment: .leading) {
                Text("已选择图片")
                    .font(.caption.bold())
                Text("将随消息一起发送")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                selectedImage = nil
                selectedPhotoItem = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 4, y: -2)
    }

    // MARK: - Input Area

    var chatInputArea: some View {
        HStack(spacing: 8) {
            // Photo picker
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "667eea"))
            }

            TextField("输入消息...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "f0f0f0"))
                .cornerRadius(20)
                .lineLimit(1...4)
                .focused($isInputFocused)

            // Send button
            Button(action: { sendMessage(inputText) }) {
                Circle()
                    .fill(
                        canSend
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        : AnyShapeStyle(Color.gray.opacity(0.3))
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
            .disabled(!canSend || chatService.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImage != nil
    }

    // MARK: - Helpers

    private func sendMessage(_ text: String) {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageData: Data? = selectedImage.flatMap { AIChatService.compressImage($0) }
        guard !content.isEmpty || imageData != nil else { return }

        inputText = ""
        selectedImage = nil
        selectedPhotoItem = nil

        Task {
            await chatService.sendMessage(content, imageData: imageData)
        }
    }

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        item.loadTransferable(type: Data.self) { result in
            if case .success(let data) = result, let data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    selectedImage = image
                }
            }
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
    @State private var showThinking = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 60)
                VStack(alignment: .trailing, spacing: 4) {
                    // User image attachment
                    if let imageData = message.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200, maxHeight: 200)
                            .cornerRadius(14)
                    }

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
                    // Thinking content (collapsible)
                    if let thinking = message.thinkingContent, !thinking.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showThinking.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "brain")
                                    .font(.caption2)
                                Text(showThinking ? "收起思考过程" : "查看思考过程")
                                    .font(.caption2)
                                Image(systemName: showThinking ? "chevron.up" : "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(Color(hex: "667eea"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: "667eea").opacity(0.1))
                            .cornerRadius(10)
                        }

                        if showThinking {
                            Text(thinking)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color(hex: "f8f5ff"))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(hex: "667eea").opacity(0.2), lineWidth: 1)
                                )
                        }
                    }

                    // Main content
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(18)
                        .cornerRadius(4, corners: .bottomLeft)
                        .conditionalGlassEffect()
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

// MARK: - Conversation List View

struct ConversationListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var chatService: AIChatService

    var body: some View {
        NavigationStack {
            Group {
                if chatService.conversations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("暂无对话")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(chatService.conversations) { conv in
                            Button {
                                chatService.switchToConversation(conv.id)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(conv.title)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)

                                        Text(formatDate(conv.updatedAt))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if conv.id == chatService.currentConversationId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(hex: "667eea"))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                chatService.deleteConversation(chatService.conversations[index].id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("对话列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        chatService.newConversation()
                        dismiss()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Color(hex: "667eea"))
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return "今天 " + formatter.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
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
                .conditionalGlassEffect()
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

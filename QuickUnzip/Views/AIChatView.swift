import SwiftUI
import PhotosUI
import AVKit

struct AIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatService = AIChatService.shared
    @State private var inputText = ""
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showConversations = false
    @State private var showNewConvPicker = false
    @FocusState private var isInputFocused: Bool

    private var isSoraMode: Bool {
        chatService.currentConversationType == .sora
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Model indicator
                modelIndicator
                    .conditionalGlassEffect()

                // Message list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if chatService.messages.isEmpty && !chatService.isLoading {
                                if isSoraMode {
                                    soraWelcomeSection
                                } else {
                                    welcomeSection
                                }
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

                // Sora duration picker
                if isSoraMode {
                    soraDurationPicker
                }

                // Image preview
                if let image = selectedImage {
                    imagePreviewBar(image)
                }

                // Input area
                chatInputArea
            }
            .navigationTitle(isSoraMode ? "Sora 视频" : "AI 助手")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        if !isSoraMode {
                            // Thinking toggle
                            Button {
                                chatService.thinkingEnabled.toggle()
                            } label: {
                                Image(systemName: chatService.thinkingEnabled ? "brain.fill" : "brain")
                                    .foregroundColor(chatService.thinkingEnabled ? Color(hex: "667eea") : .secondary)
                            }
                        }

                        // New chat with type picker
                        Button {
                            showNewConvPicker = true
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
            .confirmationDialog("新建对话", isPresented: $showNewConvPicker) {
                Button("AI 对话") {
                    chatService.newConversation(type: .chat)
                }
                Button("Sora 视频生成") {
                    chatService.newConversation(type: .sora)
                }
                Button("取消", role: .cancel) {}
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
                .fill(isSoraMode ? Color.orange : Color.green)
                .frame(width: 6, height: 6)
            if isSoraMode {
                Text("Sora-2 · 720p · \(chatService.selectedDuration)s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text(chatService.thinkingEnabled ? "深度思考模式" : "AI 智能助手")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.8))
    }

    // MARK: - Welcome Section (Chat)

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

            Text("支持图片识别和深度思考模式\n试试问我任何问题！")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            HStack(spacing: 8) {
                featureTag(icon: "photo", text: "图片识别")
                featureTag(icon: "brain", text: "深度思考")
                featureTag(icon: "bubble.left.and.bubble.right", text: "多轮对话")
            }
            .padding(.top, 4)

            VStack(spacing: 10) {
                AIQuickButton(text: "如何压缩文件？") { sendMessage("如何压缩文件？") }
                AIQuickButton(text: "支持哪些压缩格式？") { sendMessage("支持哪些压缩格式？") }
                AIQuickButton(text: "解压密码忘了怎么办？") { sendMessage("解压密码忘了怎么办？") }
            }
            .padding(.top, 10)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Welcome Section (Sora)

    var soraWelcomeSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "f093fb"), Color(hex: "f5576c")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                    .shadow(color: Color(hex: "f5576c").opacity(0.4), radius: 12, y: 6)

                Image(systemName: "film")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            Text("Sora 视频生成")
                .font(.title2.bold())

            Text("输入描述，AI 为你生成视频\n支持 4s / 8s / 12s · 720p")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            HStack(spacing: 8) {
                featureTag(icon: "film", text: "Sora-2")
                featureTag(icon: "timer", text: "4s/8s/12s")
                featureTag(icon: "sparkles", text: "720p")
            }
            .padding(.top, 4)

            VStack(spacing: 10) {
                AIQuickButton(text: "一只猫在弹钢琴") { sendVideoPrompt("一只猫在弹钢琴") }
                AIQuickButton(text: "海边日落延时摄影") { sendVideoPrompt("海边日落延时摄影") }
                AIQuickButton(text: "赛博朋克城市夜景航拍") { sendVideoPrompt("赛博朋克城市夜景航拍") }
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
        .conditionalGlassEffect()
    }

    // MARK: - Sora Duration Picker

    var soraDurationPicker: some View {
        HStack(spacing: 0) {
            ForEach([4, 8, 12], id: \.self) { duration in
                Button {
                    chatService.selectedDuration = duration
                } label: {
                    Text("\(duration)s")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(chatService.selectedDuration == duration ? .white : Color(hex: "667eea"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            chatService.selectedDuration == duration
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                                startPoint: .leading, endPoint: .trailing
                              ))
                            : AnyShapeStyle(Color.clear)
                        )
                        .cornerRadius(16)
                }
            }
        }
        .padding(4)
        .background(Color(hex: "667eea").opacity(0.1))
        .cornerRadius(20)
        .conditionalGlassEffect()
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Loading Bubble

    var loadingBubble: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(LinearGradient(
                    colors: isSoraMode
                        ? [Color(hex: "f093fb"), Color(hex: "f5576c")]
                        : [Color(hex: "667eea"), Color(hex: "764ba2")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: isSoraMode ? "film" : "brain.head.profile")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                )
                .padding(.leading, 12)

            VStack(alignment: .leading, spacing: 4) {
                if isSoraMode {
                    Text("视频生成中，请耐心等待...")
                        .font(.caption)
                        .foregroundColor(Color(hex: "f5576c"))
                } else if chatService.thinkingEnabled {
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
        .conditionalGlassEffect()
        .shadow(color: .black.opacity(0.05), radius: 4, y: -2)
    }

    // MARK: - Input Area

    var chatInputArea: some View {
        HStack(spacing: 8) {
            if !isSoraMode {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "667eea"))
                }
            }

            TextField(isSoraMode ? "描述你想生成的视频..." : "输入消息...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "f0f0f0"))
                .cornerRadius(20)
                .lineLimit(1...4)
                .focused($isInputFocused)

            Button(action: {
                if isSoraMode {
                    sendVideoPrompt(inputText)
                } else {
                    sendMessage(inputText)
                }
            }) {
                Circle()
                    .fill(
                        canSend
                        ? AnyShapeStyle(LinearGradient(
                            colors: isSoraMode
                                ? [Color(hex: "f093fb"), Color(hex: "f5576c")]
                                : [Color(hex: "667eea"), Color(hex: "764ba2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        : AnyShapeStyle(Color.gray.opacity(0.3))
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: isSoraMode ? "film" : "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
            .disabled(!canSend || chatService.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .conditionalGlassEffect()
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
        Task { await chatService.sendMessage(content, imageData: imageData) }
    }

    private func sendVideoPrompt(_ text: String) {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        inputText = ""
        Task { await chatService.generateVideo(prompt: content) }
    }

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        item.loadTransferable(type: Data.self) { result in
            if case .success(let data) = result, let data, let image = UIImage(data: data) {
                DispatchQueue.main.async { selectedImage = image }
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
                        colors: message.videoURL != nil
                            ? [Color(hex: "f093fb"), Color(hex: "f5576c")]
                            : [Color(hex: "667eea"), Color(hex: "764ba2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: message.videoURL != nil ? "film" : "brain.head.profile")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    )
                    .padding(.leading, 12)

                VStack(alignment: .leading, spacing: 6) {
                    // Thinking content
                    if let thinking = message.thinkingContent, !thinking.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showThinking.toggle() }
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
                            .conditionalGlassEffect()
                        }

                        if showThinking {
                            Text(thinking)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color(hex: "f8f5ff"))
                                .cornerRadius(14)
                                .conditionalGlassEffect()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color(hex: "667eea").opacity(0.2), lineWidth: 1)
                                )
                        }
                    }

                    // Video player
                    if let videoURLString = message.videoURL, let url = URL(string: videoURLString) {
                        VideoPlayer(player: AVPlayer(url: url))
                            .frame(width: 240, height: 135)
                            .cornerRadius(14)
                            .conditionalGlassEffect()
                            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)

                        // Copy URL button
                        Button {
                            UIPasteboard.general.string = videoURLString
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption2)
                                Text("复制视频链接")
                                    .font(.caption2)
                            }
                            .foregroundColor(Color(hex: "667eea"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: "667eea").opacity(0.1))
                            .cornerRadius(10)
                            .conditionalGlassEffect()
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
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "刚刚" }
        if diff < 3600 { return "\(Int(diff / 60))分钟前" }
        let fmt = DateFormatter()
        fmt.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "MM/dd HH:mm"
        return fmt.string(from: date)
    }
}

// MARK: - Conversation List View

struct ConversationListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var chatService: AIChatService
    @State private var showNewConvPicker = false

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
                                HStack(spacing: 12) {
                                    // Type icon
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient(
                                                colors: conv.type == .sora
                                                    ? [Color(hex: "f093fb"), Color(hex: "f5576c")]
                                                    : [Color(hex: "667eea"), Color(hex: "764ba2")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
                                            .frame(width: 32, height: 32)

                                        Image(systemName: conv.type == .sora ? "film" : "brain.head.profile")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(conv.title)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)

                                        HStack(spacing: 4) {
                                            Text(conv.type == .sora ? "Sora" : "AI")
                                                .font(.caption2.bold())
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(conv.type == .sora ? Color(hex: "f5576c") : Color(hex: "667eea"))
                                                .cornerRadius(4)

                                            Text(formatDate(conv.updatedAt))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if conv.id == chatService.currentConversationId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(hex: "667eea"))
                                    }
                                }
                                .padding(.vertical, 2)
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
                        showNewConvPicker = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Color(hex: "667eea"))
                    }
                }
            }
            .confirmationDialog("新建对话", isPresented: $showNewConvPicker) {
                Button("AI 对话") {
                    chatService.newConversation(type: .chat)
                    dismiss()
                }
                Button("Sora 视频生成") {
                    chatService.newConversation(type: .sora)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            return "今天 " + fmt.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "昨天"
        } else {
            let fmt = DateFormatter()
            fmt.dateFormat = "MM/dd"
            return fmt.string(from: date)
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

import Foundation
import UIKit

// MARK: - Models

enum ConversationType: String, Codable {
    case chat
    case sora
}

struct AIChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: String
    let content: String
    let imageData: Data?
    let thinkingContent: String?
    let videoURL: String?
    let createdAt: Date

    var isFromUser: Bool { role == "user" }

    init(role: String, content: String, imageData: Data? = nil, thinkingContent: String? = nil, videoURL: String? = nil, createdAt: Date = Date()) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.imageData = imageData
        self.thinkingContent = thinkingContent
        self.videoURL = videoURL
        self.createdAt = createdAt
    }

    static func == (lhs: AIChatMessage, rhs: AIChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct ChatConversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var type: ConversationType
    let createdAt: Date
    var updatedAt: Date

    init(title: String = "新对话", type: ConversationType = .chat) {
        self.id = UUID()
        self.title = title
        self.type = type
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - AI Chat Service

class AIChatService: ObservableObject {
    static let shared = AIChatService()

    private var apiKey: String { APIConfig.aiAPIKey }
    private var chatURL: String { APIConfig.aiChatURL }
    private var videoURL: String { APIConfig.aiVideoURL }

    private let systemPrompt = """
    你是「免费解压王」App 内置的全能 AI 助手，由 Claude 驱动。你的能力不限于文件压缩解压，你可以：

    1. 回答任何领域的问题：编程、学习、翻译、写作、数学、科学、历史、生活百科等
    2. 帮助用户处理文件相关问题：压缩、解压、格式转换、文件名乱码修复等
    3. 进行自由的日常对话，聊天、讲故事、创意写作
    4. 分析用户发送的图片，提供详细描述和解读
    5. 提供编程帮助：代码调试、解释、编写
    6. 翻译多种语言

    请用友好、专业的中文回复。回答要详细有帮助，格式清晰。你没有任何话题限制，尽你所能帮助用户。
    """

    @Published var messages: [AIChatMessage] = []
    @Published var isLoading = false
    @Published var thinkingEnabled = false
    @Published var conversations: [ChatConversation] = []
    @Published var currentConversationId: UUID?
    @Published var selectedDuration: Int = 4

    private let conversationsKey = "ai_conversations_v3"

    var currentConversationType: ConversationType {
        conversations.first(where: { $0.id == currentConversationId })?.type ?? .chat
    }

    private var model: String {
        thinkingEnabled ? "claude-haiku-4-5-20251001-thinking" : "claude-haiku-4-5-20251001"
    }

    init() {
        loadConversations()
        if let first = conversations.first {
            currentConversationId = first.id
            loadMessages(for: first.id)
        }
    }

    // MARK: - Conversation Management

    func newConversation(type: ConversationType = .chat) {
        if let currentId = currentConversationId {
            saveMessages(for: currentId)
        }

        let title = type == .sora ? "Sora 视频" : "新对话"
        let conv = ChatConversation(title: title, type: type)
        conversations.insert(conv, at: 0)
        saveConversations()

        currentConversationId = conv.id
        messages = []
    }

    func switchToConversation(_ id: UUID) {
        guard id != currentConversationId else { return }

        if let currentId = currentConversationId {
            saveMessages(for: currentId)
        }

        currentConversationId = id
        loadMessages(for: id)
    }

    func deleteConversation(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        UserDefaults.standard.removeObject(forKey: "ai_conv_\(id.uuidString)")
        saveConversations()

        if currentConversationId == id {
            if let first = conversations.first {
                currentConversationId = first.id
                loadMessages(for: first.id)
            } else {
                currentConversationId = nil
                messages = []
            }
        }
    }

    // MARK: - Send Chat Message

    func sendMessage(_ content: String, imageData: Data? = nil) async {
        if currentConversationId == nil {
            await MainActor.run { newConversation(type: .chat) }
        }

        let finalContent = content.isEmpty && imageData != nil ? "请描述这张图片" : content
        let userMessage = AIChatMessage(role: "user", content: finalContent, imageData: imageData)

        await MainActor.run {
            messages.append(userMessage)
            isLoading = true
        }

        updateConversationTitle(finalContent)

        do {
            let (reply, thinking) = try await callChatAPI()
            let assistantMessage = AIChatMessage(role: "assistant", content: reply, thinkingContent: thinking)

            await MainActor.run {
                messages.append(assistantMessage)
                isLoading = false
                if let id = currentConversationId { saveMessages(for: id) }
            }
        } catch {
            await MainActor.run {
                messages.append(AIChatMessage(role: "assistant", content: "抱歉，请求失败：\(error.localizedDescription)"))
                isLoading = false
            }
        }
    }

    // MARK: - Generate Video

    func generateVideo(prompt: String) async {
        if currentConversationId == nil {
            await MainActor.run { newConversation(type: .sora) }
        }

        let durationText = "\(selectedDuration)s"
        let userMessage = AIChatMessage(role: "user", content: "🎬 \(prompt)\n⏱ \(durationText) · 720p")

        await MainActor.run {
            messages.append(userMessage)
            isLoading = true
        }

        updateConversationTitle(prompt)

        do {
            let url = try await callVideoAPI(prompt: prompt, duration: selectedDuration)
            let assistantMessage = AIChatMessage(role: "assistant", content: "视频生成完成！", videoURL: url)

            await MainActor.run {
                messages.append(assistantMessage)
                isLoading = false
                if let id = currentConversationId { saveMessages(for: id) }
            }
        } catch {
            await MainActor.run {
                messages.append(AIChatMessage(role: "assistant", content: "视频生成失败：\(error.localizedDescription)"))
                isLoading = false
            }
        }
    }

    // MARK: - Chat API

    private func callChatAPI() async throws -> (String, String?) {
        var chatMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        let recentMessages = messages.suffix(20)
        for msg in recentMessages {
            if let imgData = msg.imageData {
                let base64 = imgData.base64EncodedString()
                let content: [[String: Any]] = [
                    ["type": "text", "text": msg.content],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
                ]
                chatMessages.append(["role": msg.role, "content": content])
            } else {
                chatMessages.append(["role": msg.role, "content": msg.content])
            }
        }

        let requestBody: [String: Any] = [
            "model": model,
            "messages": chatMessages,
            "stream": false
        ]

        guard let url = URL(string: chatURL) else {
            throw NSError(domain: "AI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 API 地址"])
        }

        guard !apiKey.isEmpty else {
            throw NSError(domain: "AI", code: -1, userInfo: [NSLocalizedDescriptionKey: "未配置 API Key，请在 Secrets.plist 中设置"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await NetworkHelper.dataWithRetry(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "未知错误"
            throw NSError(domain: "AI", code: -1, userInfo: [NSLocalizedDescriptionKey: body])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "AI", code: -2, userInfo: [NSLocalizedDescriptionKey: "解析响应失败"])
        }

        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            throw NSError(domain: "AI", code: -3, userInfo: [NSLocalizedDescriptionKey: message])
        }

        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "AI", code: -4, userInfo: [NSLocalizedDescriptionKey: "没有返回内容"])
        }

        return (content, message["reasoning_content"] as? String)
    }

    // MARK: - Video API

    private func callVideoAPI(prompt: String, duration: Int) async throws -> String {
        let requestBody: [String: Any] = [
            "model": "grok-video-3",
            "prompt": prompt,
            "size": "1280x720",
            "duration": duration,
            "n": 1
        ]

        guard let url = URL(string: videoURL) else {
            throw NSError(domain: "Sora", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的视频 API 地址"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 300
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await NetworkHelper.dataWithRetry(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "未知错误"
            throw NSError(domain: "Sora", code: -1, userInfo: [NSLocalizedDescriptionKey: body])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "Sora", code: -2, userInfo: [NSLocalizedDescriptionKey: "解析响应失败"])
        }

        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            throw NSError(domain: "Sora", code: -3, userInfo: [NSLocalizedDescriptionKey: message])
        }

        if let dataArr = json["data"] as? [[String: Any]], let first = dataArr.first, let url = first["url"] as? String {
            return url
        }

        throw NSError(domain: "Sora", code: -4, userInfo: [NSLocalizedDescriptionKey: "未返回视频地址"])
    }

    // MARK: - Helpers

    private func updateConversationTitle(_ content: String) {
        guard let convId = currentConversationId,
              messages.filter({ $0.isFromUser }).count == 1,
              let idx = conversations.firstIndex(where: { $0.id == convId }) else { return }

        let prefix = conversations[idx].type == .sora ? "🎬 " : ""
        let title = prefix + String(content.prefix(18)) + (content.count > 18 ? "..." : "")

        Task { @MainActor in
            conversations[idx].title = title
            conversations[idx].updatedAt = Date()
            saveConversations()
        }
    }

    func clearHistory() {
        messages.removeAll()
        if let id = currentConversationId { saveMessages(for: id) }
    }

    static func compressImage(_ image: UIImage, maxSize: CGFloat = 1024) -> Data? {
        let size = image.size
        let scale = min(maxSize / max(size.width, size.height), 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resized?.jpegData(compressionQuality: 0.6)
    }

    // MARK: - Persistence

    private func saveConversations() {
        if let data = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(data, forKey: conversationsKey)
        }
    }

    private func loadConversations() {
        guard let data = UserDefaults.standard.data(forKey: conversationsKey),
              let convs = try? JSONDecoder().decode([ChatConversation].self, from: data) else { return }
        conversations = convs
    }

    private func saveMessages(for conversationId: UUID) {
        let key = "ai_conv_\(conversationId.uuidString)"
        let items: [[String: Any]] = messages.map { msg in
            var dict: [String: Any] = [
                "role": msg.role,
                "content": msg.content,
                "createdAt": msg.createdAt.timeIntervalSince1970
            ]
            if let imgData = msg.imageData { dict["imageData"] = imgData.base64EncodedString() }
            if let thinking = msg.thinkingContent { dict["thinkingContent"] = thinking }
            if let video = msg.videoURL { dict["videoURL"] = video }
            return dict
        }
        if let data = try? JSONSerialization.data(withJSONObject: items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadMessages(for conversationId: UUID) {
        let key = "ai_conv_\(conversationId.uuidString)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            messages = []
            return
        }

        messages = items.compactMap { dict in
            guard let role = dict["role"] as? String, let content = dict["content"] as? String else { return nil }
            let ts = dict["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
            return AIChatMessage(
                role: role,
                content: content,
                imageData: (dict["imageData"] as? String).flatMap { Data(base64Encoded: $0) },
                thinkingContent: dict["thinkingContent"] as? String,
                videoURL: dict["videoURL"] as? String,
                createdAt: Date(timeIntervalSince1970: ts)
            )
        }
    }
}

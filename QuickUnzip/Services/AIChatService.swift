import Foundation
import UIKit

// MARK: - Models

struct AIChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: String
    let content: String
    let imageData: Data?
    let thinkingContent: String?
    let createdAt: Date

    var isFromUser: Bool { role == "user" }

    init(role: String, content: String, imageData: Data? = nil, thinkingContent: String? = nil, createdAt: Date = Date()) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.imageData = imageData
        self.thinkingContent = thinkingContent
        self.createdAt = createdAt
    }

    static func == (lhs: AIChatMessage, rhs: AIChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct ChatConversation: Identifiable, Codable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date

    init(title: String = "新对话") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - AI Chat Service

class AIChatService: ObservableObject {
    static let shared = AIChatService()

    private let apiKey = "sk-8yCdmD8Z6dLqUY8lneL88BOieBGQWC0QBz9YXFivetb2i02n"
    private let baseURL = "https://aicanapi.com/v1/chat/completions"

    private let systemPrompt = """
    你是「免费解压王」App 内置的 AI 助手。你可以回答用户关于文件压缩、解压缩、文件管理等方面的问题，也可以进行日常聊天。请用简洁友好的中文回复。
    """

    @Published var messages: [AIChatMessage] = []
    @Published var isLoading = false
    @Published var thinkingEnabled = false
    @Published var conversations: [ChatConversation] = []
    @Published var currentConversationId: UUID?

    private let conversationsKey = "ai_conversations_v2"

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

    func newConversation() {
        if let currentId = currentConversationId {
            saveMessages(for: currentId)
        }

        let conv = ChatConversation()
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

    // MARK: - Send Message

    func sendMessage(_ content: String, imageData: Data? = nil) async {
        if currentConversationId == nil {
            await MainActor.run { newConversation() }
        }

        let finalContent = content.isEmpty && imageData != nil ? "请描述这张图片" : content
        let userMessage = AIChatMessage(role: "user", content: finalContent, imageData: imageData)

        await MainActor.run {
            messages.append(userMessage)
            isLoading = true
        }

        // Update conversation title from first user message
        if let convId = currentConversationId,
           messages.filter({ $0.isFromUser }).count == 1,
           let idx = conversations.firstIndex(where: { $0.id == convId }) {
            let title = String(finalContent.prefix(20)) + (finalContent.count > 20 ? "..." : "")
            await MainActor.run {
                conversations[idx].title = title
                conversations[idx].updatedAt = Date()
                saveConversations()
            }
        }

        do {
            let (reply, thinking) = try await callAPI()
            let assistantMessage = AIChatMessage(role: "assistant", content: reply, thinkingContent: thinking)

            await MainActor.run {
                messages.append(assistantMessage)
                isLoading = false
                if let id = currentConversationId {
                    saveMessages(for: id)
                }
            }
        } catch {
            let errorMessage = AIChatMessage(
                role: "assistant",
                content: "抱歉，请求失败：\(error.localizedDescription)"
            )
            await MainActor.run {
                messages.append(errorMessage)
                isLoading = false
            }
        }
    }

    // MARK: - API Call

    private func callAPI() async throws -> (String, String?) {
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

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的响应"])
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "未知错误"
            throw NSError(domain: "AIChatService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(body)"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "AIChatService", code: -2, userInfo: [NSLocalizedDescriptionKey: "解析响应失败"])
        }

        if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
            throw NSError(domain: "AIChatService", code: -3, userInfo: [NSLocalizedDescriptionKey: message])
        }

        guard let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "AIChatService", code: -4, userInfo: [NSLocalizedDescriptionKey: "没有返回内容"])
        }

        let reasoningContent = message["reasoning_content"] as? String

        return (content, reasoningContent)
    }

    // MARK: - Clear

    func clearHistory() {
        messages.removeAll()
        if let id = currentConversationId {
            saveMessages(for: id)
        }
    }

    // MARK: - Image Helper

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
              let convs = try? JSONDecoder().decode([ChatConversation].self, from: data) else {
            return
        }
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
            if let imgData = msg.imageData {
                dict["imageData"] = imgData.base64EncodedString()
            }
            if let thinking = msg.thinkingContent {
                dict["thinkingContent"] = thinking
            }
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
            guard let role = dict["role"] as? String,
                  let content = dict["content"] as? String else { return nil }

            let timestamp = dict["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
            let imageData = (dict["imageData"] as? String).flatMap { Data(base64Encoded: $0) }
            let thinkingContent = dict["thinkingContent"] as? String

            return AIChatMessage(
                role: role,
                content: content,
                imageData: imageData,
                thinkingContent: thinkingContent,
                createdAt: Date(timeIntervalSince1970: timestamp)
            )
        }
    }
}

import Foundation

// MARK: - AI Chat Models

struct AIChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String // "user" or "assistant"
    let content: String
    let createdAt: Date

    var isFromUser: Bool {
        role == "user"
    }
}

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool

    struct ChatMessage: Codable {
        let role: String
        let content: String
    }
}

struct ChatCompletionResponse: Codable {
    let choices: [Choice]?
    let error: APIError?

    struct Choice: Codable {
        let message: MessageContent

        struct MessageContent: Codable {
            let role: String
            let content: String
        }
    }

    struct APIError: Codable {
        let message: String
    }
}

// MARK: - AI Chat Service

class AIChatService: ObservableObject {
    static let shared = AIChatService()

    private let apiKey = "sk-8yCdmD8Z6dLqUY8lneL88BOieBGQWC0QBz9YXFivetb2i02n"
    private let baseURL = "https://aicanapi.com/v1/chat/completions"
    private let model = "claude-opus-4-5-20251101-thinking"

    private let systemPrompt = """
    你是「免费解压王」App 内置的 AI 助手。你可以回答用户关于文件压缩、解压缩、文件管理等方面的问题，也可以进行日常聊天。请用简洁友好的中文回复。
    """

    @Published var messages: [AIChatMessage] = []
    @Published var isLoading = false

    private let historyKey = "ai_chat_history"

    init() {
        loadHistory()
    }

    // MARK: - Send Message

    func sendMessage(_ content: String) async {
        let userMessage = AIChatMessage(role: "user", content: content, createdAt: Date())

        await MainActor.run {
            messages.append(userMessage)
            isLoading = true
        }

        saveHistory()

        do {
            let reply = try await callAPI()
            let assistantMessage = AIChatMessage(role: "assistant", content: reply, createdAt: Date())

            await MainActor.run {
                messages.append(assistantMessage)
                isLoading = false
            }

            saveHistory()
        } catch {
            let errorMessage = AIChatMessage(
                role: "assistant",
                content: "抱歉，请求失败：\(error.localizedDescription)",
                createdAt: Date()
            )

            await MainActor.run {
                messages.append(errorMessage)
                isLoading = false
            }
        }
    }

    // MARK: - API Call

    private func callAPI() async throws -> String {
        var chatMessages = [ChatCompletionRequest.ChatMessage(role: "system", content: systemPrompt)]

        // Include recent conversation context (last 20 messages)
        let recentMessages = messages.suffix(20)
        for msg in recentMessages {
            chatMessages.append(ChatCompletionRequest.ChatMessage(role: msg.role, content: msg.content))
        }

        let requestBody = ChatCompletionRequest(
            model: model,
            messages: chatMessages,
            stream: false
        )

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的响应"])
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "未知错误"
            throw NSError(domain: "AIChatService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(body)"])
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)

        if let error = decoded.error {
            throw NSError(domain: "AIChatService", code: -2, userInfo: [NSLocalizedDescriptionKey: error.message])
        }

        guard let reply = decoded.choices?.first?.message.content else {
            throw NSError(domain: "AIChatService", code: -3, userInfo: [NSLocalizedDescriptionKey: "没有返回内容"])
        }

        return reply
    }

    // MARK: - History

    func clearHistory() {
        messages.removeAll()
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    private func saveHistory() {
        let items = messages.map { ["role": $0.role, "content": $0.content] }
        if let data = try? JSONSerialization.data(withJSONObject: items) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            return
        }

        messages = items.compactMap { dict in
            guard let role = dict["role"], let content = dict["content"] else { return nil }
            return AIChatMessage(role: role, content: content, createdAt: Date())
        }
    }
}

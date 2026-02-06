import Foundation

// MARK: - API Models

struct CSUser: Codable {
    let userId: Int
    let nickname: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nickname
    }
}

struct CSMessage: Codable, Identifiable {
    let id: Int
    let content: String
    let isFromUser: Bool
    let isRead: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case isFromUser = "is_from_user"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

struct MessagesResponse: Codable {
    let messages: [CSMessage]
}

struct SendResponse: Codable {
    let success: Bool?
    let messageId: Int?
    let createdAt: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case messageId = "message_id"
        case createdAt = "created_at"
        case error
    }
}

struct UnreadCountResponse: Codable {
    let count: Int
}

// MARK: - Customer Service API

class CustomerServiceAPI: ObservableObject {
    static let shared = CustomerServiceAPI()

    private let baseURL = "https://781391.cn/admin"

    @Published var unreadCount: Int = 0

    private var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: "cs_device_id") {
            return id
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "cs_device_id")
        return newId
    }

    private var nickname: String {
        UserDefaults.standard.string(forKey: "cs_nickname") ?? "用户"
    }

    init() {
        // 启动时检查未读消息
        Task {
            await checkUnreadCount()
        }
    }

    // MARK: - Register User

    func registerUser(nickname: String = "用户") async throws {
        let url = URL(string: "\(baseURL)/api.php?action=register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "device_id": deviceId,
            "nickname": nickname
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, _) = try await URLSession.shared.data(for: request)
        UserDefaults.standard.set(nickname, forKey: "cs_nickname")
    }

    // MARK: - Send Message

    func sendMessage(_ content: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/api.php?action=send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "device_id": deviceId,
            "content": content
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SendResponse.self, from: data)

        return response.success ?? false
    }

    // MARK: - Get Messages

    func getMessages(lastId: Int = 0) async throws -> [CSMessage] {
        var urlString = "\(baseURL)/api.php?action=messages&device_id=\(deviceId)"
        if lastId > 0 {
            urlString += "&last_id=\(lastId)"
        }

        let url = URL(string: urlString)!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(MessagesResponse.self, from: data)

        // 更新未读数为0（因为已经读取了）
        await MainActor.run {
            self.unreadCount = 0
        }

        return response.messages
    }

    // MARK: - Check Unread Count

    func checkUnreadCount() async {
        do {
            let url = URL(string: "\(baseURL)/api.php?action=unread_count&device_id=\(deviceId)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(UnreadCountResponse.self, from: data)

            await MainActor.run {
                self.unreadCount = response.count
            }
        } catch {
            print("检查未读消息失败: \(error)")
        }
    }

    // MARK: - Mark as Read

    func markAsRead() async {
        do {
            let url = URL(string: "\(baseURL)/api.php?action=mark_read")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = ["device_id": deviceId]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let _ = try await URLSession.shared.data(for: request)

            await MainActor.run {
                self.unreadCount = 0
            }
        } catch {
            print("标记已读失败: \(error)")
        }
    }
}

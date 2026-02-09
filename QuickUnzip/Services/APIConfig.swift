import Foundation

/// 集中管理所有 API 配置
/// 优先从 Secrets.plist 读取，若不存在则使用 Bundle Info.plist 中的值
struct APIConfig {

    // MARK: - AI Chat

    static var aiAPIKey: String {
        secret(for: "AI_API_KEY") ?? "sk-aDNuLw9dfI77QFy3pTT8Hehtkg26VnaydPC9Rpvpm6a29UF1"
    }

    static var aiChatURL: String {
        secret(for: "AI_CHAT_URL") ?? "https://aicanapi.com/v1/chat/completions"
    }

    static var aiVideoURL: String {
        secret(for: "AI_VIDEO_URL") ?? "https://aicanapi.com/v1/video/generations"
    }

    // MARK: - Customer Service

    static var customerServiceBaseURL: String {
        secret(for: "CS_BASE_URL") ?? "https://781391.cn/admin"
    }

    // MARK: - Helper

    /// 从 Secrets.plist 中读取值（优先），否则从 Info.plist 读取
    private static func secret(for key: String) -> String? {
        // 1. 优先从 Secrets.plist 读取
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let value = dict[key] as? String, !value.isEmpty {
            return value
        }
        // 2. 从 Info.plist 读取
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty {
            return value
        }
        return nil
    }
}

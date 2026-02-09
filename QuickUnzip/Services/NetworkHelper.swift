import Foundation

/// 网络请求工具：支持自动重试和指数退避
enum NetworkHelper {

    /// 带重试的 URLRequest 请求
    static func dataWithRetry(
        for request: URLRequest,
        maxRetries: Int = 3,
        session: URLSession = .shared
    ) async throws -> (Data, URLResponse) {
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                let (data, response) = try await session.data(for: request)

                // 对 5xx 服务器错误进行重试
                if let http = response as? HTTPURLResponse, http.statusCode >= 500, attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                return (data, response)
            } catch let error as URLError where isRetryable(error) && attempt < maxRetries {
                lastError = error
                let delay = pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                throw error
            }
        }

        throw lastError ?? URLError(.unknown)
    }

    /// 带重试的 URL GET 请求
    static func dataWithRetry(
        from url: URL,
        maxRetries: Int = 3,
        session: URLSession = .shared
    ) async throws -> (Data, URLResponse) {
        let request = URLRequest(url: url)
        return try await dataWithRetry(for: request, maxRetries: maxRetries, session: session)
    }

    /// 判断错误是否值得重试
    private static func isRetryable(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut,
             .networkConnectionLost,
             .notConnectedToInternet,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}

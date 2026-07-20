import Foundation

enum APIError: LocalizedError, Identifiable {
    case invalidServerURL
    case invalidResponse
    case http(Int, String)
    case business(Int, String)
    case unauthorized(String)
    case decoding(String)
    case network(String)

    var id: String { localizedDescription }

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "服务器地址无效，请检查是否包含 http(s)://"
        case .invalidResponse:
            return "服务器返回了无法识别的响应"
        case .http(let code, let message):
            return "HTTP \(code): \(message)"
        case .business(_, let message):
            return message
        case .unauthorized(let message):
            return message
        case .decoding(let message):
            return "数据解析失败: \(message)"
        case .network(let message):
            return message
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var isRefreshing = false
    private var refreshWaiters: [CheckedContinuation<String?, Never>] = []

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    func get<T: Decodable>(_ path: String, query: [String: Any?] = [:], auth: Bool = true) async throws -> T {
        try await request(path, method: "GET", query: query, body: Optional<EmptyBody>.none, auth: auth)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B, query: [String: Any?] = [:], auth: Bool = true) async throws -> T {
        try await request(path, method: "POST", query: query, body: body, auth: auth)
    }

    func put<T: Decodable, B: Encodable>(_ path: String, body: B, query: [String: Any?] = [:], auth: Bool = true) async throws -> T {
        try await request(path, method: "PUT", query: query, body: body, auth: auth)
    }

    func delete<T: Decodable>(_ path: String, query: [String: Any?] = [:], auth: Bool = true) async throws -> T {
        try await request(path, method: "DELETE", query: query, body: Optional<EmptyBody>.none, auth: auth)
    }

    func postEmpty(_ path: String, body: some Encodable, auth: Bool = true) async throws {
        let _: EmptyData = try await post(path, body: body, auth: auth)
    }

    private struct EmptyBody: Encodable {}

    private func request<T: Decodable, B: Encodable>(
        _ path: String,
        method: String,
        query: [String: Any?],
        body: B?,
        auth: Bool,
        retrying: Bool = false
    ) async throws -> T {
        let url = try buildURL(path: path, query: query, method: method)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Locale.current.identifier, forHTTPHeaderField: "Accept-Language")
        request.setValue("1", forHTTPHeaderField: "X-Sub2API-User-UI")

        if auth {
            let token = await MainActor.run { AppSession.shared.accessToken }
            if let token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 401, auth, !retrying {
            if let newToken = await refreshAccessTokenIfNeeded() {
                await MainActor.run {
                    AppSession.shared.updateAccessToken(newToken)
                }
                return try await self.request(path, method: method, query: query, body: body, auth: auth, retrying: true)
            }
            await MainActor.run {
                AppSession.shared.forceLogout(reason: "登录已过期，请重新登录")
            }
            throw APIError.unauthorized("登录已过期，请重新登录")
        }

        if !(200...299).contains(http.statusCode) {
            let message = extractMessage(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            if http.statusCode == 401 {
                throw APIError.unauthorized(message)
            }
            throw APIError.http(http.statusCode, message)
        }

        if T.self == EmptyData.self {
            if data.isEmpty {
                return EmptyData() as! T
            }
        }

        do {
            if let envelope = try? decoder.decode(APIEnvelope<T>.self, from: data) {
                if envelope.code == 0 {
                    if let value = envelope.data {
                        return value
                    }
                    if T.self == EmptyData.self {
                        return EmptyData() as! T
                    }
                    throw APIError.business(envelope.code, envelope.message ?? "空响应")
                } else {
                    throw APIError.business(envelope.code, envelope.message ?? "业务错误")
                }
            }

            return try decoder.decode(T.self, from: data)
        } catch let api as APIError {
            throw api
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    private func refreshAccessTokenIfNeeded() async -> String? {
        if isRefreshing {
            return await withCheckedContinuation { continuation in
                refreshWaiters.append(continuation)
            }
        }

        let refreshToken = await MainActor.run { AppSession.shared.refreshToken }
        guard let refreshToken else {
            return nil
        }

        isRefreshing = true
        defer {
            isRefreshing = false
        }

        do {
            struct RefreshBody: Encodable { let refresh_token: String }
            let response: RefreshTokenResponse = try await request(
                "/auth/refresh",
                method: "POST",
                query: [:],
                body: RefreshBody(refresh_token: refreshToken),
                auth: false,
                retrying: true
            )
            await MainActor.run {
                AppSession.shared.applyTokens(
                    access: response.access_token,
                    refresh: response.refresh_token ?? refreshToken,
                    expiresIn: response.expires_in
                )
            }
            let token = response.access_token
            for waiter in refreshWaiters {
                waiter.resume(returning: token)
            }
            refreshWaiters.removeAll()
            return token
        } catch {
            for waiter in refreshWaiters {
                waiter.resume(returning: nil)
            }
            refreshWaiters.removeAll()
            return nil
        }
    }

    private func buildURL(path: String, query: [String: Any?], method: String) throws -> URL {
        let base = await MainActor.run { AppSession.shared.apiBaseURLString }
        guard var components = URLComponents(string: base + normalize(path: path)) else {
            throw APIError.invalidServerURL
        }

        var items: [URLQueryItem] = []
        for (key, value) in query {
            if let value {
                items.append(URLQueryItem(name: key, value: "\(value)"))
            }
        }
        if method.uppercased() == "GET" {
            items.append(URLQueryItem(name: "timezone", value: TimeZone.current.identifier))
        }
        if !items.isEmpty {
            components.queryItems = items
        }
        guard let url = components.url else {
            throw APIError.invalidServerURL
        }
        return url
    }

    private func normalize(path: String) -> String {
        path.hasPrefix("/") ? path : "/\(path)"
    }

    private func extractMessage(from data: Data) -> String? {
        if let envelope = try? decoder.decode(APIEnvelope<EmptyData>.self, from: data) {
            return envelope.message
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return (obj["message"] as? String) ?? (obj["detail"] as? String)
        }
        return String(data: data, encoding: .utf8)
    }
}

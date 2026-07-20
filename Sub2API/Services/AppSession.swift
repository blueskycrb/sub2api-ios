import Foundation
import Combine

@MainActor
final class AppSession: ObservableObject {
    static let shared = AppSession()

    private enum Keys {
        static let serverURL = "server_url"
        static let access = "access_token"
        static let refresh = "refresh_token"
        static let expiresAt = "token_expires_at"
        static let user = "auth_user"
        static let settings = "public_settings"
    }

    @Published var serverURL: String
    @Published var user: User?
    @Published var publicSettings: PublicSettings?
    @Published var isBootstrapping = true
    @Published var authExpiredMessage: String?

    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private var expiresAt: Date?

    var isAuthenticated: Bool { accessToken != nil && user != nil }
    var paymentEnabled: Bool { publicSettings?.payment_enabled == true }
    var channelMonitorEnabled: Bool { publicSettings?.channel_monitor_enabled != false }
    var siteName: String { publicSettings?.site_name?.nilIfEmpty ?? "Sub2API" }

    var apiBaseURLString: String {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmed.isEmpty { return "" }
        if trimmed.hasSuffix("/api/v1") { return trimmed }
        return trimmed + "/api/v1"
    }

    private init() {
        serverURL = UserDefaults.standard.string(forKey: Keys.serverURL) ?? ""
        accessToken = KeychainStore.get(Keys.access)
        refreshToken = KeychainStore.get(Keys.refresh)
        if let raw = UserDefaults.standard.string(forKey: Keys.expiresAt), let ts = Double(raw) {
            expiresAt = Date(timeIntervalSince1970: ts)
        }
        if let data = UserDefaults.standard.data(forKey: Keys.user),
           let saved = try? JSONDecoder().decode(User.self, from: data) {
            user = saved
        }
        if let data = UserDefaults.standard.data(forKey: Keys.settings),
           let settings = try? JSONDecoder().decode(PublicSettings.self, from: data) {
            publicSettings = settings
        }
    }

    func bootstrap() async {
        defer { isBootstrapping = false }
        guard !serverURL.isEmpty else { return }
        do {
            try await refreshPublicSettings()
            if accessToken != nil {
                try await refreshCurrentUser()
            }
        } catch {
            // Keep cached session if offline; clear only hard auth failures.
            if case APIError.unauthorized = error {
                clearSession()
            }
        }
    }

    func updateServerURL(_ url: String) {
        serverURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(serverURL, forKey: Keys.serverURL)
    }

    func applyAuth(_ response: AuthResponse) {
        applyTokens(access: response.access_token, refresh: response.refresh_token, expiresIn: response.expires_in)
        user = response.user
        persistUser()
        authExpiredMessage = nil
    }

    func applyTokens(access: String, refresh: String?, expiresIn: Int?) {
        accessToken = access
        KeychainStore.set(access, for: Keys.access)
        if let refresh {
            refreshToken = refresh
            KeychainStore.set(refresh, for: Keys.refresh)
        }
        if let expiresIn {
            let date = Date().addingTimeInterval(TimeInterval(expiresIn))
            expiresAt = date
            UserDefaults.standard.set(String(date.timeIntervalSince1970), forKey: Keys.expiresAt)
        }
    }

    func updateAccessToken(_ token: String) {
        accessToken = token
        KeychainStore.set(token, for: Keys.access)
    }

    func updateUser(_ user: User) {
        self.user = user
        persistUser()
    }

    func refreshPublicSettings() async throws {
        let settings: PublicSettings = try await APIClient.shared.get("/settings/public", auth: false)
        publicSettings = settings
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Keys.settings)
        }
        if let remote = settings.api_base_url?.nilIfEmpty, serverURL.isEmpty {
            updateServerURL(remote)
        }
    }

    func refreshCurrentUser() async throws {
        let me: User = try await APIClient.shared.get("/auth/me")
        user = me
        persistUser()
    }

    func logout() async {
        if let refreshToken {
            struct Body: Encodable { let refresh_token: String }
            try? await APIClient.shared.postEmpty("/auth/logout", body: Body(refresh_token: refreshToken), auth: true)
        }
        clearSession()
    }

    func forceLogout(reason: String) {
        clearSession()
        authExpiredMessage = reason
    }

    private func clearSession() {
        accessToken = nil
        refreshToken = nil
        expiresAt = nil
        user = nil
        KeychainStore.delete(Keys.access)
        KeychainStore.delete(Keys.refresh)
        UserDefaults.standard.removeObject(forKey: Keys.expiresAt)
        UserDefaults.standard.removeObject(forKey: Keys.user)
    }

    private func persistUser() {
        guard let user, let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: Keys.user)
    }
}

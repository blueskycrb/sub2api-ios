import Foundation

enum Sub2APIService {
    // MARK: - Auth
    static func login(email: String, password: String, turnstile: String? = nil) async throws -> Result<AuthResponse, TotpLoginResponse> {
        struct Dual: Decodable {
            let access_token: String?
            let refresh_token: String?
            let expires_in: Int?
            let token_type: String?
            let user: User?
            let requires_2fa: Bool?
            let temp_token: String?
            let user_email_masked: String?
        }

        let dual: Dual = try await APIClient.shared.post(
            "/auth/login",
            body: LoginRequest(email: email, password: password, turnstile_token: turnstile),
            auth: false
        )

        if dual.requires_2fa == true {
            return .failure(TotpLoginResponse(
                requires_2fa: true,
                temp_token: dual.temp_token,
                user_email_masked: dual.user_email_masked
            ))
        }

        guard let token = dual.access_token, let user = dual.user else {
            throw APIError.invalidResponse
        }

        return .success(AuthResponse(
            access_token: token,
            refresh_token: dual.refresh_token,
            expires_in: dual.expires_in,
            token_type: dual.token_type,
            user: user
        ))
    }

    static func login2FA(tempToken: String, code: String) async throws -> AuthResponse {
        try await APIClient.shared.post(
            "/auth/login/2fa",
            body: TotpLogin2FARequest(temp_token: tempToken, code: code),
            auth: false
        )
    }

    static func register(_ payload: RegisterRequest) async throws -> AuthResponse {
        try await APIClient.shared.post("/auth/register", body: payload, auth: false)
    }

    static func sendVerifyCode(email: String) async throws -> MessageResponse {
        struct Body: Encodable { let email: String }
        return try await APIClient.shared.post("/auth/send-verify-code", body: Body(email: email), auth: false)
    }

    static func forgotPassword(email: String) async throws -> MessageResponse {
        struct Body: Encodable { let email: String }
        return try await APIClient.shared.post("/auth/forgot-password", body: Body(email: email), auth: false)
    }

    // MARK: - Dashboard / Usage
    static func dashboardStats() async throws -> UserDashboardStats {
        try await APIClient.shared.get("/usage/dashboard/stats")
    }

    static func dashboardModels(startDate: String, endDate: String) async throws -> ModelStatsResponse {
        try await APIClient.shared.get("/usage/dashboard/models", query: [
            "start_date": startDate,
            "end_date": endDate
        ])
    }

    static func adminDashboardStats() async throws -> AdminDashboardStats {
        try await APIClient.shared.get("/admin/dashboard/stats")
    }

    static func usageLogs(page: Int = 1, pageSize: Int = 20, apiKeyId: Int? = nil) async throws -> PaginatedResponse<UsageLog> {
        try await APIClient.shared.get("/usage", query: [
            "page": page,
            "page_size": pageSize,
            "api_key_id": apiKeyId
        ])
    }

    static func usageStats() async throws -> UsageStatsResponse {
        try await APIClient.shared.get("/usage/stats", query: ["period": "today"])
    }

    // MARK: - Keys
    static func listKeys(page: Int = 1, pageSize: Int = 50, search: String? = nil) async throws -> PaginatedResponse<ApiKey> {
        try await APIClient.shared.get("/keys", query: [
            "page": page,
            "page_size": pageSize,
            "search": search
        ])
    }

    static func createKey(_ payload: CreateApiKeyRequest) async throws -> ApiKey {
        try await APIClient.shared.post("/keys", body: payload)
    }

    static func updateKey(id: Int, _ payload: UpdateApiKeyRequest) async throws -> ApiKey {
        try await APIClient.shared.put("/keys/\(id)", body: payload)
    }

    static func deleteKey(id: Int) async throws -> MessageResponse {
        try await APIClient.shared.delete("/keys/\(id)")
    }

    static func availableGroups() async throws -> [APIGroup] {
        try await APIClient.shared.get("/groups/available")
    }

    // MARK: - Profile
    static func profile() async throws -> User {
        try await APIClient.shared.get("/user/profile")
    }

    static func updateProfile(_ payload: UpdateProfileRequest) async throws -> User {
        try await APIClient.shared.put("/user", body: payload)
    }

    static func changePassword(old: String, new: String) async throws -> MessageResponse {
        try await APIClient.shared.put("/user/password", body: ChangePasswordRequest(old_password: old, new_password: new))
    }

    static func platformQuotas() async throws -> PlatformQuotasResponse {
        try await APIClient.shared.get("/user/platform-quotas")
    }

    // MARK: - Announcements
    static func announcements(unreadOnly: Bool = false) async throws -> [UserAnnouncement] {
        try await APIClient.shared.get("/announcements", query: ["unread_only": unreadOnly ? 1 : nil])
    }

    static func markAnnouncementRead(id: Int) async throws -> MessageResponse {
        struct Body: Encodable {}
        return try await APIClient.shared.post("/announcements/\(id)/read", body: Body())
    }

    // MARK: - Subscriptions
    static func mySubscriptions() async throws -> [UserSubscription] {
        try await APIClient.shared.get("/subscriptions")
    }

    static func subscriptionProgress() async throws -> [SubscriptionProgress] {
        try await APIClient.shared.get("/subscriptions/progress")
    }

    static func subscriptionSummary() async throws -> SubscriptionSummary {
        try await APIClient.shared.get("/subscriptions/summary")
    }

    // MARK: - Redeem / Affiliate
    static func redeem(code: String) async throws -> RedeemResult {
        struct Body: Encodable { let code: String }
        return try await APIClient.shared.post("/redeem", body: Body(code: code))
    }

    static func redeemHistory() async throws -> [RedeemHistoryItem] {
        try await APIClient.shared.get("/redeem/history")
    }

    static func affiliateDetail() async throws -> UserAffiliateDetail {
        try await APIClient.shared.get("/user/aff")
    }

    static func transferAffiliateQuota() async throws -> AffiliateTransferResponse {
        struct Body: Encodable {}
        return try await APIClient.shared.post("/user/aff/transfer", body: Body())
    }

    // MARK: - Channels
    static func availableChannels() async throws -> [UserAvailableChannel] {
        try await APIClient.shared.get("/channels/available")
    }

    // MARK: - Payment
    static func paymentConfig() async throws -> PaymentConfig {
        try await APIClient.shared.get("/payment/config")
    }

    static func paymentPlans() async throws -> [SubscriptionPlan] {
        try await APIClient.shared.get("/payment/plans")
    }

    static func myOrders(page: Int = 1, pageSize: Int = 20) async throws -> PaginatedResponse<PaymentOrder> {
        try await APIClient.shared.get("/payment/orders/my", query: [
            "page": page,
            "page_size": pageSize
        ])
    }

    static func createOrder(planId: Int, method: String?) async throws -> CreateOrderResult {
        try await APIClient.shared.post("/payment/orders", body: CreateOrderRequest(plan_id: planId, method: method, quantity: 1))
    }

    static func cancelOrder(id: Int) async throws -> MessageResponse {
        struct Body: Encodable {}
        return try await APIClient.shared.post("/payment/orders/\(id)/cancel", body: Body())
    }

    // MARK: - Channel Monitor
    static func channelMonitors() async throws -> [UserMonitorView] {
        let res: UserMonitorListResponse = try await APIClient.shared.get("/channel-monitors")
        return res.items ?? []
    }

    static func channelMonitorStatus(id: Int) async throws -> UserMonitorDetail {
        try await APIClient.shared.get("/channel-monitors/\(id)/status")
    }

    // MARK: - Admin Accounts
    static func adminAccounts(
        page: Int = 1,
        pageSize: Int = 50,
        platform: String? = nil,
        status: String? = nil,
        search: String? = nil
    ) async throws -> PaginatedResponse<AdminAccount> {
        try await APIClient.shared.get("/admin/accounts", query: [
            "page": page,
            "page_size": pageSize,
            "platform": platform,
            "status": status,
            "search": search,
            "lite": "1"
        ])
    }

    static func adminAccount(id: Int) async throws -> AdminAccount {
        try await APIClient.shared.get("/admin/accounts/\(id)")
    }

    static func updateAdminAccount(id: Int, _ payload: UpdateAdminAccountRequest) async throws -> AdminAccount {
        try await APIClient.shared.put("/admin/accounts/\(id)", body: payload)
    }

    static func setAdminAccountStatus(id: Int, status: String) async throws -> AdminAccount {
        try await updateAdminAccount(id: id, UpdateAdminAccountRequest(status: status))
    }

    static func deleteAdminAccount(id: Int) async throws -> MessageResponse {
        try await APIClient.shared.delete("/admin/accounts/\(id)")
    }

    static func testAdminAccount(id: Int) async throws -> AccountTestResult {
        struct Body: Encodable {}
        return try await APIClient.shared.post("/admin/accounts/\(id)/test", body: Body())
    }

    static func refreshAdminAccount(id: Int) async throws -> AdminAccount {
        struct Body: Encodable {}
        return try await APIClient.shared.post("/admin/accounts/\(id)/refresh", body: Body())
    }

    static func clearAdminAccountError(id: Int) async throws -> AdminAccount {
        struct Body: Encodable {}
        return try await APIClient.shared.post("/admin/accounts/\(id)/clear-error", body: Body())
    }

    static func clearAdminAccountRateLimit(id: Int) async throws -> AdminAccount {
        struct Body: Encodable {}
        return try await APIClient.shared.post("/admin/accounts/\(id)/clear-rate-limit", body: Body())
    }

    static func recoverAdminAccount(id: Int) async throws -> AdminAccount {
        struct Body: Encodable {}
        return try await APIClient.shared.post("/admin/accounts/\(id)/recover-state", body: Body())
    }
}

import Foundation

struct APIEnvelope<T: Decodable>: Decodable {
    let code: Int
    let message: String?
    let data: T?
}

struct EmptyData: Decodable {}

struct LoginRequest: Encodable {
    let email: String
    let password: String
    let turnstile_token: String?
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let verify_code: String?
    let turnstile_token: String?
    let promo_code: String?
    let invitation_code: String?
    let aff_code: String?
}

struct TotpLogin2FARequest: Encodable {
    let temp_token: String
    let code: String
}

struct AuthResponse: Decodable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int?
    let token_type: String?
    let user: User
}

struct TotpLoginResponse: Decodable, Error {
    let requires_2fa: Bool
    let temp_token: String?
    let user_email_masked: String?
}

struct RefreshTokenResponse: Decodable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int?
    let token_type: String?
}

struct MessageResponse: Decodable {
    let message: String?
}

struct User: Codable, Identifiable, Hashable {
    let id: Int
    var username: String
    var email: String
    var avatar_url: String?
    var role: String
    var balance: Double
    var frozen_balance: Double?
    var concurrency: Int
    var rpm_limit: Int?
    var status: String
    var balance_notify_enabled: Bool?
    var balance_notify_threshold: Double?
    var created_at: String?
    var updated_at: String?
    var run_mode: String?

    var isAdmin: Bool { role == "admin" }
    var isSimpleMode: Bool { run_mode == "simple" }
}

struct PublicSettings: Codable {
    var registration_enabled: Bool?
    var email_verify_enabled: Bool?
    var promo_code_enabled: Bool?
    var password_reset_enabled: Bool?
    var invitation_code_enabled: Bool?
    var turnstile_enabled: Bool?
    var turnstile_site_key: String?
    var site_name: String?
    var site_logo: String?
    var site_subtitle: String?
    var api_base_url: String?
    var contact_info: String?
    var doc_url: String?
    var payment_enabled: Bool?
    var risk_control_enabled: Bool?
    var backend_mode_enabled: Bool?
    var linuxdo_oauth_enabled: Bool?
    var wechat_oauth_enabled: Bool?
    var oidc_oauth_enabled: Bool?
    var github_oauth_enabled: Bool?
    var google_oauth_enabled: Bool?
    var channel_monitor_enabled: Bool?
}

struct APIGroup: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var description: String?
    var platform: String?
    var rate_multiplier: Double?
    var subscription_type: String?
    var is_exclusive: Bool?
}

struct ApiKey: Codable, Identifiable, Hashable {
    let id: Int
    var user_id: Int?
    var key: String
    var name: String
    var group_id: Int?
    var status: String
    var ip_whitelist: [String]?
    var ip_blacklist: [String]?
    var last_used_at: String?
    var last_used_ip: String?
    var quota: Double?
    var quota_used: Double?
    var expires_at: String?
    var created_at: String?
    var updated_at: String?
    var current_concurrency: Int?
    var group: APIGroup?
    var rate_limit_5h: Double?
    var rate_limit_1d: Double?
    var rate_limit_7d: Double?
    var usage_5h: Double?
    var usage_1d: Double?
    var usage_7d: Double?

    var isActive: Bool { status == "active" }
    var maskedKey: String {
        guard key.count > 12 else { return key }
        return String(key.prefix(8)) + "..." + String(key.suffix(4))
    }
}

struct CreateApiKeyRequest: Encodable {
    var name: String
    var group_id: Int?
    var custom_key: String?
    var ip_whitelist: [String]?
    var ip_blacklist: [String]?
    var quota: Double?
    var expires_in_days: Int?
    var rate_limit_5h: Double?
    var rate_limit_1d: Double?
    var rate_limit_7d: Double?
}

struct UpdateApiKeyRequest: Encodable {
    var name: String?
    var group_id: Int?
    var status: String?
    var quota: Double?
    var reset_quota: Bool?
}

struct PaginatedResponse<T: Decodable>: Decodable {
    let items: [T]
    let total: Int
    let page: Int
    let page_size: Int
    let pages: Int?
}

struct UsageLog: Codable, Identifiable, Hashable {
    let id: Int
    var api_key_id: Int?
    var request_id: String?
    var model: String?
    var input_tokens: Int?
    var output_tokens: Int?
    var cache_creation_tokens: Int?
    var cache_read_tokens: Int?
    var total_cost: Double?
    var actual_cost: Double?
    var stream: Bool?
    var duration_ms: Int?
    var created_at: String?
    var status: String?
}

struct UserDashboardStats: Codable {
    var total_api_keys: Int?
    var active_api_keys: Int?
    var total_requests: Int?
    var total_input_tokens: Int?
    var total_output_tokens: Int?
    var total_tokens: Int?
    var total_cost: Double?
    var total_actual_cost: Double?
    var today_requests: Int?
    var today_tokens: Int?
    var today_cost: Double?
    var today_actual_cost: Double?
    var average_duration_ms: Double?
    var rpm: Double?
    var tpm: Double?
}

struct AdminDashboardStats: Codable {
    var total_users: Int?
    var active_users: Int?
    var total_api_keys: Int?
    var active_api_keys: Int?
    var total_accounts: Int?
    var normal_accounts: Int?
    var error_accounts: Int?
    var total_requests: Int?
    var today_requests: Int?
    var total_cost: Double?
    var today_cost: Double?
    var total_actual_cost: Double?
    var today_actual_cost: Double?
}

struct UsageStatsResponse: Codable {
    var total_requests: Int?
    var total_tokens: Int?
    var total_cost: Double?
    var total_actual_cost: Double?
    var today_requests: Int?
    var today_tokens: Int?
    var today_cost: Double?
    var today_actual_cost: Double?
}

struct ModelStat: Codable, Identifiable, Hashable {
    var model: String
    var requests: Int?
    var input_tokens: Int?
    var output_tokens: Int?
    var cache_creation_tokens: Int?
    var cache_read_tokens: Int?
    var total_tokens: Int?
    var cost: Double?
    var actual_cost: Double?
    var account_cost: Double?

    var id: String { model }
}

struct ModelStatsResponse: Codable {
    var models: [ModelStat]?
    var start_date: String?
    var end_date: String?
}

struct UserAnnouncement: Codable, Identifiable, Hashable {
    let id: Int
    var title: String
    var content: String
    var notify_mode: String?
    var starts_at: String?
    var ends_at: String?
    var read_at: String?
    var created_at: String?
    var updated_at: String?

    var isUnread: Bool { read_at == nil || read_at?.isEmpty == true }
}

struct UserSubscription: Codable, Identifiable, Hashable {
    let id: Int
    var user_id: Int?
    var group_id: Int?
    var status: String
    var starts_at: String?
    var daily_usage_usd: Double?
    var weekly_usage_usd: Double?
    var monthly_usage_usd: Double?
    var expires_at: String?
    var created_at: String?
    var updated_at: String?
    var group: APIGroup?
}

struct ProgressBucket: Codable, Hashable {
    var used: Double?
    var limit: Double?
    var percentage: Double?
    var reset_in_seconds: Int?
}

struct SubscriptionProgress: Codable, Identifiable, Hashable {
    var subscription_id: Int
    var daily: ProgressBucket?
    var weekly: ProgressBucket?
    var monthly: ProgressBucket?

    var id: Int { subscription_id }
}

struct SubscriptionSummary: Codable {
    var active_count: Int?
    var subscriptions: [SubscriptionSummaryItem]?
}

struct SubscriptionSummaryItem: Codable, Identifiable, Hashable {
    var id: Int
    var group_name: String?
    var status: String?
    var daily_progress: Double?
    var weekly_progress: Double?
    var monthly_progress: Double?
    var expires_at: String?
    var days_remaining: Int?
}

struct RedeemResult: Codable {
    var message: String?
    var type: String?
    var value: Double?
    var new_balance: Double?
    var new_concurrency: Int?
}

struct RedeemHistoryItem: Codable, Identifiable, Hashable {
    let id: Int
    var code: String
    var type: String
    var value: Double
    var status: String?
    var used_at: String?
    var created_at: String?
    var notes: String?
    var group_id: Int?
    var validity_days: Int?
    var group: APIGroup?
}

struct UserAffiliateDetail: Codable {
    var user_id: Int?
    var aff_code: String?
    var inviter_id: Int?
    var aff_count: Int?
    var aff_quota: Double?
    var aff_frozen_quota: Double?
    var aff_history_quota: Double?
    var effective_rebate_rate_percent: Double?
    var invitees: [AffiliateInvitee]?
}

struct AffiliateInvitee: Codable, Identifiable, Hashable {
    var user_id: Int
    var email: String?
    var username: String?
    var created_at: String?
    var total_rebate: Double?

    var id: Int { user_id }
}

struct AffiliateTransferResponse: Codable {
    var transferred_quota: Double?
    var balance: Double?
}

struct UserAvailableGroup: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var platform: String?
    var subscription_type: String?
    var rate_multiplier: Double?
    var peak_rate_enabled: Bool?
    var peak_start: String?
    var peak_end: String?
    var peak_rate_multiplier: Double?
    var is_exclusive: Bool?
}

struct UserSupportedModelPricing: Codable, Hashable {
    var billing_mode: String?
    var input_price: Double?
    var output_price: Double?
    var cache_write_price: Double?
    var cache_read_price: Double?
    var image_input_price: Double?
    var image_output_price: Double?
    var per_request_price: Double?
}

struct UserSupportedModel: Codable, Identifiable, Hashable {
    var name: String
    var platform: String?
    var pricing: UserSupportedModelPricing?

    var id: String { "\(platform ?? "")-\(name)" }
}

struct UserChannelPlatformSection: Codable, Hashable {
    var platform: String
    var groups: [UserAvailableGroup]?
    var supported_models: [UserSupportedModel]?
}

struct UserAvailableChannel: Codable, Identifiable, Hashable {
    var name: String
    var description: String?
    var platforms: [UserChannelPlatformSection]?

    var id: String { name }
}

struct PlatformQuotaItem: Codable, Identifiable, Hashable {
    var platform: String
    var quota: Double?
    var used: Double?
    var remaining: Double?

    var id: String { platform }
}

struct PlatformQuotasResponse: Codable {
    var items: [PlatformQuotaItem]?
}

struct ChangePasswordRequest: Encodable {
    let old_password: String
    let new_password: String
}

struct UpdateProfileRequest: Encodable {
    var username: String?
    var avatar_url: String?
    var balance_notify_enabled: Bool?
    var balance_notify_threshold: Double?
}

struct PaymentConfig: Codable {
    var enabled: Bool?
    var methods: [String]?
    var currency: String?
    var min_amount: Double?
    var max_amount: Double?
}

struct SubscriptionPlan: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var description: String?
    var price: Double?
    var currency: String?
    var duration_days: Int?
    var group_id: Int?
    var status: String?
    var features: [String]?
}

struct PaymentOrder: Codable, Identifiable, Hashable {
    let id: Int
    var out_trade_no: String?
    var status: String?
    var amount: Double?
    var currency: String?
    var plan_name: String?
    var created_at: String?
    var paid_at: String?
    var expires_at: String?
}

struct CreateOrderRequest: Encodable {
    var plan_id: Int
    var method: String?
    var quantity: Int?
}

struct CreateOrderResult: Codable {
    var order: PaymentOrder?
    var pay_url: String?
    var qr_code: String?
    var message: String?
}

struct ChannelStatusItem: Codable, Identifiable, Hashable {
    var id: String { "\(name)-\(platform ?? "")" }
    var name: String
    var platform: String?
    var status: String?
    var latency_ms: Double?
    var message: String?
    var updated_at: String?
}

struct UserMonitorExtraModel: Codable, Identifiable, Hashable {
    var model: String
    var status: String?
    var latency_ms: Double?

    var id: String { model }
}

struct MonitorTimelinePoint: Codable, Hashable {
    var status: String?
    var latency_ms: Double?
    var ping_latency_ms: Double?
    var checked_at: String?
}

struct UserMonitorView: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var provider: String?
    var group_name: String?
    var primary_model: String?
    var primary_status: String?
    var primary_latency_ms: Double?
    var primary_ping_latency_ms: Double?
    var availability_7d: Double?
    var extra_models: [UserMonitorExtraModel]?
    var timeline: [MonitorTimelinePoint]?
}

struct UserMonitorListResponse: Codable {
    var items: [UserMonitorView]?
}

struct UserMonitorModelDetail: Codable, Identifiable, Hashable {
    var model: String
    var latest_status: String?
    var latest_latency_ms: Double?
    var availability_7d: Double?
    var availability_15d: Double?
    var availability_30d: Double?
    var avg_latency_7d_ms: Double?

    var id: String { model }
}

struct UserMonitorDetail: Codable, Identifiable, Hashable {
    let id: Int
    var name: String?
    var provider: String?
    var group_name: String?
    var models: [UserMonitorModelDetail]?
}



// MARK: - Admin Accounts

struct AdminAccountGroup: Codable, Identifiable, Hashable {
    let id: Int
    var name: String?
    var platform: String?
}

struct AdminAccountCredentials: Codable, Hashable {
    var base_url: String?
    var api_key: String?
}

struct AdminAccountCredentialsStatus: Codable, Hashable {
    var has_api_key: Bool?
}

struct AdminAccount: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var notes: String?
    var platform: String?
    var type: String?
    var status: String?
    var error_message: String?
    var concurrency: Int?
    var current_concurrency: Int?
    var priority: Int?
    var rate_multiplier: Double?
    var load_factor: Double?
    var proxy_id: Int?
    var proxy_fallback_origin_name: String?
    var schedulable: Bool?
    var last_used_at: String?
    var created_at: String?
    var updated_at: String?
    var rate_limited_at: String?
    var rate_limit_reset_at: String?
    var overload_until: String?
    var temp_unschedulable_until: String?
    var temp_unschedulable_reason: String?
    var session_window_status: String?
    var group_ids: [Int]?
    var groups: [AdminAccountGroup]?
    var credentials: AdminAccountCredentials?
    var credentials_status: AdminAccountCredentialsStatus?

    var platformLabel: String { (platform ?? "-").uppercased() }
    var groupNames: String {
        let names = (groups ?? []).compactMap { $0.name }.filter { !$0.isEmpty }
        return names.isEmpty ? "-" : names.joined(separator: ", ")
    }

    var supportsCredentialEdit: Bool {
        let t = (type ?? "").lowercased()
        return t == "apikey" || t == "upstream"
    }

    var hasStoredAPIKey: Bool {
        if let flag = credentials_status?.has_api_key { return flag }
        if let key = credentials?.api_key, !key.isEmpty { return true }
        return false
    }

    var currentBaseURL: String {
        credentials?.base_url ?? ""
    }

    /// 是否仍在限流窗口内（rate_limit_reset_at 未过期，或仅有 rate_limited_at 标记）
    var isRateLimitedNow: Bool {
        if isFutureTimestamp(rate_limit_reset_at) { return true }
        // 有限流时间戳但没有明确复位时间时，仍视为限流中
        if let limited = rate_limited_at, !limited.isEmpty, rate_limit_reset_at == nil || rate_limit_reset_at?.isEmpty == true {
            return true
        }
        return false
    }

    /// 临时不可调度（temp_unschedulable_until 未过期）
    var isTempUnschedulableNow: Bool {
        isFutureTimestamp(temp_unschedulable_until)
    }

    /// 过载窗口（overload_until 未过期）
    var isOverloadedNow: Bool {
        isFutureTimestamp(overload_until)
    }

    /// 运行态“限流类”：限流 / 临时不可调用 / 过载
    var isLimitedLike: Bool {
        isRateLimitedNow || isTempUnschedulableNow || isOverloadedNow
    }

    private func isFutureTimestamp(_ raw: String?) -> Bool {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return false
        }
        if let date = AdminAccount.parseAPIDate(raw) {
            return date > Date()
        }
        // 解析失败时保守视为仍生效，避免漏显示
        return true
    }

    private static func parseAPIDate(_ raw: String) -> Date? {
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFrac.date(from: raw) { return d }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return d }
        let f1 = DateFormatter()
        f1.locale = Locale(identifier: "en_US_POSIX")
        f1.timeZone = TimeZone(secondsFromGMT: 0)
        f1.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let d = f1.date(from: raw) { return d }
        let f2 = DateFormatter()
        f2.locale = Locale(identifier: "en_US_POSIX")
        f2.timeZone = TimeZone(secondsFromGMT: 0)
        f2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f2.date(from: raw)
    }
}

struct AdminAccountCredentialsUpdate: Encodable {
    var api_key: String? = nil
    var base_url: String? = nil

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(api_key, forKey: .api_key)
        try c.encodeIfPresent(base_url, forKey: .base_url)
    }

    private enum CodingKeys: String, CodingKey {
        case api_key, base_url
    }
}

struct UpdateAdminAccountRequest: Encodable {
    var status: String? = nil
    var name: String? = nil
    var notes: String? = nil
    var concurrency: Int? = nil
    var priority: Int? = nil
    var credentials: AdminAccountCredentialsUpdate? = nil

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encodeIfPresent(concurrency, forKey: .concurrency)
        try c.encodeIfPresent(priority, forKey: .priority)
        try c.encodeIfPresent(credentials, forKey: .credentials)
    }

    private enum CodingKeys: String, CodingKey {
        case status, name, notes, concurrency, priority, credentials
    }
}

struct AccountTestResult: Codable {
    var success: Bool?
    var message: String?
    var latency_ms: Double?
}

struct AccountAvailableModel: Codable, Identifiable, Hashable {
    var id: String
    var type: String?
    var object: String?
    var display_name: String?
    var created_at: String?

    var label: String {
        let name = (display_name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? id : name
    }
}

struct AccountTestRequest: Encodable {
    var model_id: String
    var prompt: String = ""
    var mode: String = "default"
}

struct AccountTestEvent: Decodable, Hashable {
    var type: String
    var text: String?
    var model: String?
    var success: Bool?
    var error: String?
    var image_url: String?
    var mime_type: String?
}

struct AccountTestLogLine: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var tone: Tone

    enum Tone: Hashable {
        case info, success, warning, error, muted, content, accent
    }
}

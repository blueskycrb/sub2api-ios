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


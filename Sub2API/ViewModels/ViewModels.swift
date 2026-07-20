import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var serverURL = AppSession.shared.serverURL
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var verifyCode = ""
    @Published var invitationCode = ""
    @Published var promoCode = ""
    @Published var affCode = ""
    @Published var totpCode = ""
    @Published var isRegisterMode = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var requires2FA = false
    @Published var tempToken: String?
    @Published var maskedEmail: String?

    var settings: PublicSettings? { AppSession.shared.publicSettings }

    func prepare() async {
        serverURL = AppSession.shared.serverURL
        if !serverURL.isEmpty {
            await loadSettings()
        }
    }

    func saveServerAndLoad() async {
        errorMessage = nil
        let normalized = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: normalized), let scheme = url.scheme, ["http", "https"].contains(scheme), url.host != nil else {
            errorMessage = "请输入有效的服务器地址，例如 https://api.example.com"
            return
        }
        AppSession.shared.updateServerURL(normalized)
        await loadSettings()
    }

    func loadSettings() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppSession.shared.refreshPublicSettings()
            infoMessage = "已连接 \(AppSession.shared.siteName)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func login() async {
        errorMessage = nil
        infoMessage = nil
        guard !AppSession.shared.serverURL.isEmpty else {
            errorMessage = "请先配置服务器地址"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Sub2APIService.login(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            switch result {
            case .success(let auth):
                AppSession.shared.applyAuth(auth)
                try? await AppSession.shared.refreshCurrentUser()
            case .failure(let totp):
                requires2FA = true
                tempToken = totp.temp_token
                maskedEmail = totp.user_email_masked
                infoMessage = "请输入二次验证码"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submit2FA() async {
        guard let tempToken else { return }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let auth = try await Sub2APIService.login2FA(tempToken: tempToken, code: totpCode.trimmingCharacters(in: .whitespacesAndNewlines))
            AppSession.shared.applyAuth(auth)
            requires2FA = false
            try? await AppSession.shared.refreshCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func register() async {
        errorMessage = nil
        infoMessage = nil
        guard password == confirmPassword else {
            errorMessage = "两次输入的密码不一致"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let auth = try await Sub2APIService.register(
                RegisterRequest(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    verify_code: verifyCode.nilIfEmpty,
                    turnstile_token: nil,
                    promo_code: promoCode.nilIfEmpty,
                    invitation_code: invitationCode.nilIfEmpty,
                    aff_code: affCode.nilIfEmpty
                )
            )
            AppSession.shared.applyAuth(auth)
            try? await AppSession.shared.refreshCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendCode() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let res = try await Sub2APIService.sendVerifyCode(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
            infoMessage = res.message ?? "验证码已发送"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func forgotPassword() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let res = try await Sub2APIService.forgotPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
            infoMessage = res.message ?? "如果邮箱存在，将收到重置邮件"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var stats: UserDashboardStats?
    @Published var announcements: [UserAnnouncement] = []
    @Published var summary: SubscriptionSummary?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            async let statsTask = Sub2APIService.dashboardStats()
            async let annTask = Sub2APIService.announcements()
            async let summaryTask = Sub2APIService.subscriptionSummary()
            stats = try await statsTask
            announcements = try await annTask
            summary = try? await summaryTask
            try? await AppSession.shared.refreshCurrentUser()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markRead(_ item: UserAnnouncement) async {
        do {
            _ = try await Sub2APIService.markAnnouncementRead(id: item.id)
            if let idx = announcements.firstIndex(where: { $0.id == item.id }) {
                announcements[idx].read_at = ISO8601DateFormatter().string(from: Date())
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class KeysViewModel: ObservableObject {
    @Published var items: [ApiKey] = []
    @Published var groups: [Group] = []
    @Published var search = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showCreate = false

    // create form
    @Published var newName = ""
    @Published var selectedGroupId: Int?
    @Published var customKey = ""
    @Published var quotaText = ""
    @Published var expiresDaysText = ""

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            async let keysTask = Sub2APIService.listKeys(search: search.nilIfEmpty)
            async let groupsTask = Sub2APIService.availableGroups()
            let page = try await keysTask
            items = page.items
            groups = (try? await groupsTask) ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create() async {
        errorMessage = nil
        successMessage = nil
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "请输入密钥名称"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            var payload = CreateApiKeyRequest(name: newName.trimmingCharacters(in: .whitespacesAndNewlines))
            payload.group_id = selectedGroupId
            payload.custom_key = customKey.nilIfEmpty
            if let q = Double(quotaText), q > 0 { payload.quota = q }
            if let d = Int(expiresDaysText), d > 0 { payload.expires_in_days = d }
            let created = try await Sub2APIService.createKey(payload)
            items.insert(created, at: 0)
            showCreate = false
            resetForm()
            successMessage = "密钥创建成功"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggle(_ key: ApiKey) async {
        do {
            let updated = try await Sub2APIService.updateKey(id: key.id, UpdateApiKeyRequest(status: key.isActive ? "inactive" : "active"))
            if let idx = items.firstIndex(where: { $0.id == key.id }) {
                items[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ key: ApiKey) async {
        do {
            _ = try await Sub2APIService.deleteKey(id: key.id)
            items.removeAll { $0.id == key.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetForm() {
        newName = ""
        selectedGroupId = nil
        customKey = ""
        quotaText = ""
        expiresDaysText = ""
    }
}

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var items: [UsageLog] = []
    @Published var stats: UsageStatsResponse?
    @Published var page = 1
    @Published var total = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(reset: Bool = true) async {
        if reset { page = 1 }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            async let logsTask = Sub2APIService.usageLogs(page: page)
            async let statsTask = Sub2APIService.usageStats()
            let pageData = try await logsTask
            items = pageData.items
            total = pageData.total
            stats = try? await statsTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func nextPage() async {
        guard items.count < total else { return }
        page += 1
        await load(reset: false)
    }

    func prevPage() async {
        guard page > 1 else { return }
        page -= 1
        await load(reset: false)
    }
}

@MainActor
final class SubscriptionsViewModel: ObservableObject {
    @Published var items: [UserSubscription] = []
    @Published var progress: [Int: SubscriptionProgress] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            async let listTask = Sub2APIService.mySubscriptions()
            async let progressTask = Sub2APIService.subscriptionProgress()
            items = try await listTask
            let p = (try? await progressTask) ?? []
            progress = Dictionary(uniqueKeysWithValues: p.map { ($0.subscription_id, $0) })
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class RedeemViewModel: ObservableObject {
    @Published var code = ""
    @Published var history: [RedeemHistoryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            history = try await Sub2APIService.redeemHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func redeem() async {
        errorMessage = nil
        successMessage = nil
        let value = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            errorMessage = "请输入兑换码"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Sub2APIService.redeem(code: value)
            successMessage = result.message ?? "兑换成功"
            code = ""
            if let balance = result.new_balance, var user = AppSession.shared.user {
                user.balance = balance
                AppSession.shared.updateUser(user)
            }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class AffiliateViewModel: ObservableObject {
    @Published var detail: UserAffiliateDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await Sub2APIService.affiliateDetail()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func transfer() async {
        errorMessage = nil
        successMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let res = try await Sub2APIService.transferAffiliateQuota()
            successMessage = "已转入 \(res.transferred_quota?.compactCurrencyText ?? "$0")"
            if let balance = res.balance, var user = AppSession.shared.user {
                user.balance = balance
                AppSession.shared.updateUser(user)
            }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class ChannelsViewModel: ObservableObject {
    @Published var items: [UserAvailableChannel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await Sub2APIService.availableChannels()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var username = ""
    @Published var avatarURL = ""
    @Published var oldPassword = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var quotas: [PlatformQuotaItem] = []

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let user = try await Sub2APIService.profile()
            AppSession.shared.updateUser(user)
            username = user.username
            avatarURL = user.avatar_url ?? ""
            if let q = try? await Sub2APIService.platformQuotas() {
                quotas = q.items ?? []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveProfile() async {
        errorMessage = nil
        successMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let user = try await Sub2APIService.updateProfile(
                UpdateProfileRequest(
                    username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                    avatar_url: avatarURL.nilIfEmpty
                )
            )
            AppSession.shared.updateUser(user)
            successMessage = "资料已更新"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changePassword() async {
        errorMessage = nil
        successMessage = nil
        guard newPassword == confirmPassword else {
            errorMessage = "两次输入的新密码不一致"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let res = try await Sub2APIService.changePassword(old: oldPassword, new: newPassword)
            successMessage = res.message ?? "密码已修改"
            oldPassword = ""
            newPassword = ""
            confirmPassword = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class PaymentViewModel: ObservableObject {
    @Published var plans: [SubscriptionPlan] = []
    @Published var orders: [PaymentOrder] = []
    @Published var config: PaymentConfig?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var createdPayURL: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let plansTask = Sub2APIService.paymentPlans()
            async let ordersTask = Sub2APIService.myOrders()
            async let configTask = Sub2APIService.paymentConfig()
            plans = try await plansTask
            orders = (try await ordersTask).items
            config = try? await configTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase(_ plan: SubscriptionPlan) async {
        errorMessage = nil
        successMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Sub2APIService.createOrder(planId: plan.id, method: config?.methods?.first)
            createdPayURL = result.pay_url
            successMessage = result.message ?? "订单已创建"
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class MonitorViewModel: ObservableObject {
    @Published var items: [UserMonitorView] = []
    @Published var details: [Int: UserMonitorDetail] = [:]
    @Published var selected: UserMonitorView?
    @Published var isLoading = false
    @Published var errorMessage: String?

    var overallStatus: String {
        guard !items.isEmpty else { return "operational" }
        for item in items {
            let status = (item.primary_status ?? "").lowercased()
            if status == "failed" || status == "error" || (status != "operational" && !status.isEmpty && status != "ok" && status != "success") {
                return "degraded"
            }
        }
        return "operational"
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            items = try await Sub2APIService.channelMonitors()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadDetail(for item: UserMonitorView, force: Bool = false) async {
        if !force, details[item.id] != nil { return }
        do {
            details[item.id] = try await Sub2APIService.channelMonitorStatus(id: item.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


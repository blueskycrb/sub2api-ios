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
    @Published var adminStats: AdminDashboardStats?
    @Published var models: [ModelStat] = []
    @Published var modelRangeStart: String = ""
    @Published var modelRangeEnd: String = ""
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    /// 防止下拉刷新 / 首次进入 / 右上角刷新并发互相覆盖
    private var loadGeneration = 0

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var hasContent: Bool { stats != nil }

    /// 首次进入：无数据才全屏 loading
    func loadIfNeeded() async {
        guard !hasContent else { return }
        await load(mode: .initial)
    }

    /// 用户主动刷新（下拉 / 按钮）
    func refresh() async {
        await load(mode: .refresh)
    }

    /// 兼容旧调用
    func load() async {
        await load(mode: hasContent ? .refresh : .initial)
    }

    private enum LoadMode {
        case initial
        case refresh
    }

    private func load(mode: LoadMode) async {
        loadGeneration += 1
        let generation = loadGeneration

        switch mode {
        case .initial:
            isLoading = true
            isRefreshing = false
        case .refresh:
            isRefreshing = true
            // 刷新时保留旧数据，避免页面被清空闪烁
        }
        errorMessage = nil

        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -6, to: end) ?? end
        let rangeStart = Self.dayFormatter.string(from: start)
        let rangeEnd = Self.dayFormatter.string(from: end)

        do {
            async let statsTask = Sub2APIService.dashboardStats()
            async let modelsTask = Sub2APIService.dashboardModels(
                startDate: rangeStart,
                endDate: rangeEnd
            )

            let newStats = try await statsTask
            let modelResp = try? await modelsTask
            // 用户信息与统计并行意义不大，放在核心数据之后，失败不阻断刷新
            try? await AppSession.shared.refreshCurrentUser()

            var newAdmin: AdminDashboardStats? = nil
            if AppSession.shared.user?.isAdmin == true {
                newAdmin = try? await Sub2APIService.adminDashboardStats()
            }

            // 只应用最新一次请求结果，避免慢请求回写覆盖新数据
            guard generation == loadGeneration else { return }
            modelRangeStart = rangeStart
            modelRangeEnd = rangeEnd
            stats = newStats
            models = modelResp?.models ?? []
            adminStats = newAdmin
        } catch {
            guard generation == loadGeneration else { return }
            // 刷新失败保留旧数据，只提示错误
            errorMessage = error.localizedDescription
            if mode == .initial && stats == nil {
                // keep empty
            }
        }

        if generation == loadGeneration {
            isLoading = false
            isRefreshing = false
        }
    }
}

@MainActor
final class KeysViewModel: ObservableObject {
    @Published var items: [ApiKey] = []
    @Published var groups: [APIGroup] = []
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



@MainActor
final class AccountsViewModel: ObservableObject {
    @Published var items: [AdminAccount] = []
    @Published var search = ""
    @Published var statusFilter: String = "all"
    @Published var platformFilter: String = "all"
    @Published var isLoading = false
    @Published var isActing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var selected: AdminAccount?
    @Published var total = 0

    var platforms: [String] {
        let set = Set(items.compactMap { $0.platform }.filter { !$0.isEmpty })
        return ["all"] + set.sorted()
    }

    /// 与网页/后端对齐的运营筛选：
    /// - all: 全部
    /// - normal: 正常可调用（后端 status=active 会排除限流/临时不可调度/不可调度）
    /// - limited: 限流 + 临时不可调用（合并 rate_limited 与 temp_unschedulable）
    /// - error: 异常
    private var apiStatusParam: String? {
        switch statusFilter {
        case "all": return nil
        case "normal": return "active"
        case "error": return "error"
        case "limited": return nil // 特殊合并逻辑
        default: return nil
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        let platform = platformFilter == "all" ? nil : platformFilter
        let searchText = search.nilIfEmpty
        do {
            if statusFilter == "limited" {
                // 后端无合并筛选：并行拉限流 + 临时不可调度，再按 id 去重
                async let ratePage = Sub2APIService.adminAccounts(
                    page: 1,
                    pageSize: 500,
                    platform: platform,
                    status: "rate_limited",
                    search: searchText
                )
                async let tempPage = Sub2APIService.adminAccounts(
                    page: 1,
                    pageSize: 500,
                    platform: platform,
                    status: "temp_unschedulable",
                    search: searchText
                )
                let (a, b) = try await (ratePage, tempPage)
                var map: [Int: AdminAccount] = [:]
                for item in a.items + b.items {
                    map[item.id] = item
                }
                // 客户端再兜底一次：过载中的账号若未被上述接口覆盖，也并入（需全量时才有；这里仅对已返回集合补标记）
                let merged = Array(map.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                items = merged
                // 去重后的列表数量；若服务端总量更大（超 pageSize），用两边 total 之和作为上限提示
                if a.items.count < a.total || b.items.count < b.total {
                    total = max(merged.count, a.total + b.total)
                } else {
                    total = merged.count
                }
            } else {
                let page = try await Sub2APIService.adminAccounts(
                    page: 1,
                    pageSize: 500,
                    platform: platform,
                    status: apiStatusParam,
                    search: searchText
                )
                items = page.items
                total = page.total
            }
            if let selected, let refreshed = items.first(where: { $0.id == selected.id }) {
                self.selected = refreshed
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ item: AdminAccount) async {
        selected = item
        do {
            selected = try await Sub2APIService.adminAccount(id: item.id)
        } catch {
            // keep list item if detail fetch fails
            errorMessage = error.localizedDescription
        }
    }

    private func replace(_ account: AdminAccount) {
        if let idx = items.firstIndex(where: { $0.id == account.id }) {
            items[idx] = account
        }
        if selected?.id == account.id {
            selected = account
        }
    }

    private func runAction(_ work: () async throws -> AdminAccount, success: String) async {
        isActing = true
        defer { isActing = false }
        errorMessage = nil
        successMessage = nil
        do {
            let account = try await work()
            replace(account)
            successMessage = success
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleStatus(_ item: AdminAccount) async {
        let next = (item.status == "active") ? "inactive" : "active"
        await runAction({
            try await Sub2APIService.setAdminAccountStatus(id: item.id, status: next)
        }, success: next == "active" ? "已启用账号" : "已停用账号")
    }

    func refreshAfterTest(id: Int) async {
        if let refreshed = try? await Sub2APIService.adminAccount(id: id) {
            replace(refreshed)
        } else {
            await load()
        }
    }

    func refreshCredentials(_ item: AdminAccount) async {
        await runAction({
            try await Sub2APIService.refreshAdminAccount(id: item.id)
        }, success: "凭证已刷新")
    }

    func clearError(_ item: AdminAccount) async {
        await runAction({
            try await Sub2APIService.clearAdminAccountError(id: item.id)
        }, success: "错误状态已清除")
    }

    func clearRateLimit(_ item: AdminAccount) async {
        await runAction({
            try await Sub2APIService.clearAdminAccountRateLimit(id: item.id)
        }, success: "限流状态已清除")
    }

    func recover(_ item: AdminAccount) async {
        await runAction({
            try await Sub2APIService.recoverAdminAccount(id: item.id)
        }, success: "运行状态已恢复")
    }

    func delete(_ item: AdminAccount) async {
        isActing = true
        defer { isActing = false }
        errorMessage = nil
        successMessage = nil
        do {
            _ = try await Sub2APIService.deleteAdminAccount(id: item.id)
            items.removeAll { $0.id == item.id }
            if selected?.id == item.id { selected = nil }
            total = max(0, total - 1)
            successMessage = "账号已删除"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 更新 API Key / Base URL（apikey、upstream 账号）
    /// - apiKey 留空表示不修改已有密钥（后端敏感字段合并保留）
    func updateCredentials(id: Int, apiKey: String?, baseURL: String?, hasExistingAPIKey: Bool) async -> Bool {
        isActing = true
        defer { isActing = false }
        errorMessage = nil
        successMessage = nil

        let trimmedKey = (apiKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBase = (baseURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedKey.isEmpty && !hasExistingAPIKey {
            errorMessage = "请填写 API Key"
            return false
        }

        var cred = AdminAccountCredentialsUpdate()
        if !trimmedKey.isEmpty {
            cred.api_key = trimmedKey
        }
        // 始终提交 base_url，与网页版编辑逻辑一致
        cred.base_url = trimmedBase

        do {
            let updated = try await Sub2APIService.updateAdminAccount(
                id: id,
                UpdateAdminAccountRequest(credentials: cred)
            )
            replace(updated)
            successMessage = "凭证已更新"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

@MainActor
final class AccountTestViewModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case loadingModels
        case ready
        case connecting
        case success
        case failed
    }

    let account: AdminAccount

    @Published var status: Status = .idle
    @Published var models: [AccountAvailableModel] = []
    @Published var selectedModelId: String = ""
    @Published var testMode: String = "default" // default | compact
    @Published var prompt: String = ""
    @Published var lines: [AccountTestLogLine] = []
    @Published var streamingText: String = ""
    @Published var errorMessage: String?
    @Published var imageURLs: [String] = []

    private var runTask: Task<Void, Never>?

    var isOpenAI: Bool {
        (account.platform ?? "").lowercased() == "openai"
    }

    var supportsImageTest: Bool {
        let mid = selectedModelId.lowercased()
        let platform = (account.platform ?? "").lowercased()
        let type = (account.type ?? "").lowercased()
        if mid.hasPrefix("gpt-image-") {
            return platform == "openai"
        }
        if mid.hasPrefix("gemini-") && mid.contains("-image") {
            return platform == "gemini" || (platform == "antigravity" && type == "apikey")
        }
        return false
    }

    var canStart: Bool {
        !selectedModelId.isEmpty && status != .connecting && status != .loadingModels
    }

    var selectedModelLabel: String {
        models.first(where: { $0.id == selectedModelId })?.label ?? selectedModelId
    }

    init(account: AdminAccount) {
        self.account = account
    }

    func loadModels() async {
        status = .loadingModels
        errorMessage = nil
        lines = []
        streamingText = ""
        imageURLs = []
        do {
            var list = try await Sub2APIService.adminAccountModels(id: account.id)
            let platform = (account.platform ?? "").lowercased()
            if platform == "gemini" || platform == "antigravity" {
                let priority = [
                    "gemini-3.1-flash-image",
                    "gemini-2.5-flash-image",
                    "gemini-3.5-flash",
                    "gemini-2.5-flash",
                    "gemini-2.5-pro",
                    "gemini-3-flash-preview",
                    "gemini-3-pro-preview",
                    "gemini-2.0-flash"
                ]
                let rank = Dictionary(uniqueKeysWithValues: priority.enumerated().map { ($0.element, $0.offset) })
                list.sort { a, b in
                    let ra = rank[a.id] ?? Int.max
                    let rb = rank[b.id] ?? Int.max
                    if ra != rb { return ra < rb }
                    return a.id < b.id
                }
            }
            models = list
            if platform == "gemini" {
                selectedModelId = list.first?.id ?? ""
            } else if let sonnet = list.first(where: { $0.id.lowercased().contains("sonnet") }) {
                selectedModelId = sonnet.id
            } else {
                selectedModelId = list.first?.id ?? ""
            }
            status = .ready
            if list.isEmpty {
                errorMessage = "该账号暂无可用测试模型"
            }
        } catch {
            status = .failed
            errorMessage = error.localizedDescription
            models = []
            selectedModelId = ""
        }
    }

    func start() {
        guard canStart else { return }
        runTask?.cancel()
        runTask = Task { await runTest() }
    }

    func stop() {
        runTask?.cancel()
        runTask = nil
        if status == .connecting {
            status = .ready
            append("已取消测试", .warning)
        }
    }

    private func runTest() async {
        lines = []
        streamingText = ""
        imageURLs = []
        errorMessage = nil
        status = .connecting

        append("开始测试账号：\(account.name)", .accent)
        append("账号类型：\(account.type ?? "-")", .muted)
        append("", .muted)

        let mode = isOpenAI ? testMode : "default"
        let promptToSend = supportsImageTest ? prompt.trimmingCharacters(in: .whitespacesAndNewlines) : ""

        do {
            let stream = Sub2APIService.testAdminAccountEvents(
                id: account.id,
                modelId: selectedModelId,
                prompt: promptToSend,
                mode: mode
            )
            for try await event in stream {
                if Task.isCancelled { return }
                handle(event)
            }
            if status == .connecting {
                // stream ended without complete event
                if streamingText.isEmpty {
                    status = .failed
                    errorMessage = "测试结束但未收到完成事件"
                } else {
                    flushStreaming()
                    status = .success
                }
            }
        } catch is CancellationError {
            status = .ready
        } catch {
            status = .failed
            errorMessage = error.localizedDescription
            append("Error: \(error.localizedDescription)", .error)
        }
    }

    private func handle(_ event: AccountTestEvent) {
        switch event.type {
        case "test_start":
            append("已连接到 API", .success)
            if let model = event.model, !model.isEmpty {
                append("使用模型：\(model)", .accent)
            } else {
                append("使用模型：\(selectedModelId)", .accent)
            }
            if supportsImageTest {
                append("发送图片测试请求…", .muted)
            } else {
                append("发送测试消息：\"hi\"", .muted)
            }
            append("", .muted)
            append("响应：", .warning)
        case "content":
            if let text = event.text {
                streamingText += text
            }
        case "status":
            if let text = event.text, !text.isEmpty {
                append(text, .accent)
            }
        case "image":
            if let url = event.image_url, !url.isEmpty {
                imageURLs.append(url)
                append("收到图片 #\(imageURLs.count)", .content)
            }
        case "test_complete":
            flushStreaming()
            if event.success == true {
                status = .success
            } else {
                status = .failed
                errorMessage = event.error ?? "测试失败"
            }
        case "error":
            flushStreaming()
            status = .failed
            errorMessage = event.error ?? "未知错误"
            if let err = event.error {
                append(err, .error)
            }
        default:
            if let text = event.text, !text.isEmpty {
                append(text, .info)
            }
        }
    }

    private func flushStreaming() {
        if !streamingText.isEmpty {
            append(streamingText, .content)
            streamingText = ""
        }
    }

    private func append(_ text: String, _ tone: AccountTestLogLine.Tone) {
        lines.append(AccountTestLogLine(text: text, tone: tone))
    }
}

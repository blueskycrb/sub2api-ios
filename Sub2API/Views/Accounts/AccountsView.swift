import SwiftUI

struct AccountsView: View {
    @StateObject private var vm = AccountsViewModel()
    @State private var accountToDelete: AdminAccount?

    var body: some View {
        List {
            if let error = vm.errorMessage {
                Section {
                    ErrorBanner(message: error) {
                        Task { await vm.load() }
                    }
                }
            }
            if let success = vm.successMessage {
                Section {
                    Text(success).foregroundStyle(.green)
                }
            }

            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索名称 / 备注", text: $vm.search)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { Task { await vm.load() } }
                    if !vm.search.isEmpty {
                        Button {
                            vm.search = ""
                            Task { await vm.load() }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Picker("状态", selection: $vm.statusFilter) {
                    Text("全部").tag("all")
                    Text("启用").tag("active")
                    Text("停用").tag("inactive")
                    Text("异常").tag("error")
                }
                .pickerStyle(.segmented)
                .onChange(of: vm.statusFilter) { _ in
                    Task { await vm.load() }
                }

                Picker("平台", selection: $vm.platformFilter) {
                    Text("全部平台").tag("all")
                    ForEach(vm.platforms.filter { $0 != "all" }, id: \.self) { platform in
                        Text(platform).tag(platform)
                    }
                }
                .onChange(of: vm.platformFilter) { _ in
                    Task { await vm.load() }
                }
            } header: {
                Text("筛选 · 共 \(vm.total) 个账号")
            }

            Section("账号列表") {
                if vm.items.isEmpty && !vm.isLoading {
                    Text("暂无账号").foregroundStyle(.secondary)
                }
                ForEach(vm.items) { item in
                    NavigationLink {
                        AccountDetailView(item: item, vm: vm)
                    } label: {
                        AccountRowView(item: item)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            accountToDelete = item
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        Button {
                            Task { await vm.toggleStatus(item) }
                        } label: {
                            Label(item.status == "active" ? "停用" : "启用",
                                  systemImage: item.status == "active" ? "pause.circle" : "play.circle")
                        }
                        .tint(item.status == "active" ? .orange : .green)
                    }
                }
            }
        }
        .navigationTitle("账号管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await vm.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(vm.isLoading || vm.isActing)
            }
        }
        .overlay {
            if vm.isLoading && vm.items.isEmpty {
                LoadingView()
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .confirmationDialog(
            "确认删除账号？",
            isPresented: Binding(
                get: { accountToDelete != nil },
                set: { if !$0 { accountToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let item = accountToDelete {
                Button("删除 \(item.name)", role: .destructive) {
                    Task {
                        await vm.delete(item)
                        accountToDelete = nil
                    }
                }
                Button("取消", role: .cancel) { accountToDelete = nil }
            }
        }
    }
}

struct AccountRowView: View {
    let item: AdminAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                StatusBadge(text: item.status ?? "-", tone: StatusTone.forStatus(item.status))
            }

            HStack(spacing: 8) {
                Label(item.platformLabel, systemImage: "cpu")
                if let type = item.type, !type.isEmpty {
                    Text("· \(type)")
                }
                Spacer()
                Text("并发 \(item.current_concurrency ?? 0)/\(item.concurrency ?? 0)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if item.schedulable == false {
                    StatusBadge(text: "不可调度", tone: .warning)
                }
                if item.rate_limit_reset_at != nil || item.rate_limited_at != nil {
                    StatusBadge(text: "限流中", tone: .danger)
                }
                if let groups = item.groups, !groups.isEmpty {
                    Text(item.groupNames)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            if let err = item.error_message, !err.isEmpty {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AccountDetailView: View {
    let item: AdminAccount
    @ObservedObject var vm: AccountsViewModel
    @State private var confirmDelete = false
    @State private var editAPIKey = ""
    @State private var editBaseURL = ""
    @State private var showAPIKey = false
    @State private var didPrefillCredentials = false

    private var account: AdminAccount {
        vm.selected?.id == item.id ? (vm.selected ?? item) : item
    }

    var body: some View {
        List {
            if let error = vm.errorMessage {
                Section { Text(error).foregroundStyle(.red) }
            }
            if let success = vm.successMessage {
                Section { Text(success).foregroundStyle(.green) }
            }

            Section("基本信息") {
                LabeledContent("名称", value: account.name)
                LabeledContent("平台", value: account.platformLabel)
                LabeledContent("类型", value: account.type ?? "-")
                HStack {
                    Text("状态")
                    Spacer()
                    StatusBadge(text: account.status ?? "-", tone: StatusTone.forStatus(account.status))
                }
                LabeledContent("优先级", value: "\(account.priority ?? 0)")
                LabeledContent("并发", value: "\(account.current_concurrency ?? 0)/\(account.concurrency ?? 0)")
                LabeledContent("倍率", value: String(format: "%.2f", account.rate_multiplier ?? 1))
                LabeledContent("可调度", value: account.schedulable == true ? "是" : "否")
                LabeledContent("分组", value: account.groupNames)
                LabeledContent("最近使用", value: DateText.display(account.last_used_at))
                LabeledContent("创建时间", value: DateText.display(account.created_at))
                if let notes = account.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("备注").font(.caption).foregroundStyle(.secondary)
                        Text(notes)
                    }
                }
            }

            if let err = account.error_message, !err.isEmpty {
                Section("错误信息") {
                    Text(err).foregroundStyle(.red)
                }
            }

            if account.supportsCredentialEdit {
                Section {
                    HStack {
                        Text("密钥状态")
                        Spacer()
                        StatusBadge(
                            text: account.hasStoredAPIKey ? "已配置" : "未配置",
                            tone: account.hasStoredAPIKey ? .success : .warning
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Base URL").font(.caption).foregroundStyle(.secondary)
                        TextField("https://api.example.com", text: $editBaseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .font(.body.monospaced())
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("API Key").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button(showAPIKey ? "隐藏" : "显示") {
                                showAPIKey.toggle()
                            }
                            .font(.caption)
                            .buttonStyle(.plain)
                        }
                        Group {
                            if showAPIKey {
                                TextField(account.hasStoredAPIKey ? "留空则不修改已有密钥" : "请输入 API Key", text: $editAPIKey)
                            } else {
                                SecureField(account.hasStoredAPIKey ? "留空则不修改已有密钥" : "请输入 API Key", text: $editAPIKey)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                    }

                    Button {
                        Task {
                            let ok = await vm.updateCredentials(
                                id: account.id,
                                apiKey: editAPIKey,
                                baseURL: editBaseURL,
                                hasExistingAPIKey: account.hasStoredAPIKey
                            )
                            if ok {
                                editAPIKey = ""
                                showAPIKey = false
                                // refresh base url from server response
                                editBaseURL = vm.selected?.currentBaseURL ?? editBaseURL
                            }
                        }
                    } label: {
                        Label("保存凭证", systemImage: "key.fill")
                    }
                    .disabled(vm.isActing)
                } header: {
                    Text("凭证设置")
                } footer: {
                    Text("API Key 因安全原因不会回显。填写新密钥可覆盖旧值；留空则保留原密钥。")
                }
            }

            if account.rate_limited_at != nil || account.rate_limit_reset_at != nil || account.temp_unschedulable_until != nil {
                Section("限流 / 临时状态") {
                    LabeledContent("限流开始", value: DateText.display(account.rate_limited_at))
                    LabeledContent("限流重置", value: DateText.display(account.rate_limit_reset_at))
                    LabeledContent("临时不可调度至", value: DateText.display(account.temp_unschedulable_until))
                    if let reason = account.temp_unschedulable_reason, !reason.isEmpty {
                        Text(reason).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("操作") {
                Button {
                    Task { await vm.toggleStatus(account) }
                } label: {
                    Label(account.status == "active" ? "停用账号" : "启用账号",
                          systemImage: account.status == "active" ? "pause.circle" : "play.circle")
                }

                Button {
                    Task { await vm.test(account) }
                } label: {
                    Label("连通性测试", systemImage: "bolt.horizontal.circle")
                }

                Button {
                    Task { await vm.refreshCredentials(account) }
                } label: {
                    Label("刷新凭证", systemImage: "arrow.clockwise.circle")
                }

                Button {
                    Task { await vm.clearError(account) }
                } label: {
                    Label("清除错误", systemImage: "xmark.octagon")
                }

                Button {
                    Task { await vm.clearRateLimit(account) }
                } label: {
                    Label("清除限流", systemImage: "timer")
                }

                Button {
                    Task { await vm.recover(account) }
                } label: {
                    Label("恢复运行状态", systemImage: "arrow.uturn.backward.circle")
                }

                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("删除账号", systemImage: "trash")
                }
            }
            .disabled(vm.isActing)
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if vm.isActing {
                    ProgressView()
                }
            }
        }
        .task {
            await vm.select(item)
            if !didPrefillCredentials {
                editBaseURL = (vm.selected ?? item).currentBaseURL
                didPrefillCredentials = true
            }
        }
        .onChange(of: vm.selected?.id) { _ in
            if let selected = vm.selected, selected.id == item.id, editAPIKey.isEmpty {
                editBaseURL = selected.currentBaseURL
            }
        }
        .confirmationDialog("确认删除该账号？此操作不可恢复。", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                Task { await vm.delete(account) }
            }
            Button("取消", role: .cancel) {}
        }
    }
}

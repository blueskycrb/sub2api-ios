import SwiftUI

struct KeysView: View {
    @StateObject private var vm = KeysViewModel()

    var body: some View {
        List {
            if let error = vm.errorMessage {
                Section {
                    ErrorBanner(message: error) { Task { await vm.load() } }
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
                    TextField("搜索密钥", text: $vm.search)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("搜索") { Task { await vm.load() } }
                }
            }

            if vm.items.isEmpty && !vm.isLoading {
                Section {
                    EmptyStateView(title: "还没有 API 密钥", systemImage: "key", message: "创建一个密钥即可在 Claude Code / Codex 等工具中使用")
                }
            } else {
                Section("我的密钥 (\(vm.items.count))") {
                    ForEach(vm.items) { key in
                        KeyRow(key: key) {
                            Task { await vm.toggle(key) }
                        } onDelete: {
                            Task { await vm.delete(key) }
                        }
                    }
                }
            }
        }
        .navigationTitle("API 密钥")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    vm.showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Task { await vm.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $vm.showCreate) {
            NavigationStack {
                Form {
                    Section("基本信息") {
                        TextField("名称", text: $vm.newName)
                        Picker("分组", selection: $vm.selectedGroupId) {
                            Text("默认 / 不指定").tag(Optional<Int>.none)
                            ForEach(vm.groups) { group in
                                Text(group.name).tag(Optional(group.id))
                            }
                        }
                        TextField("自定义 Key（可选）", text: $vm.customKey)
                            .textInputAutocapitalization(.never)
                    }
                    Section("限额") {
                        TextField("额度 USD（0=不限）", text: $vm.quotaText)
                            .keyboardType(.decimalPad)
                        TextField("有效天数（空=永久）", text: $vm.expiresDaysText)
                            .keyboardType(.numberPad)
                    }
                }
                .navigationTitle("创建密钥")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { vm.showCreate = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("创建") { Task { await vm.create() } }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .overlay { if vm.isLoading && vm.items.isEmpty { LoadingView() } }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

private struct KeyRow: View {
    let key: ApiKey
    var onToggle: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(key.name).font(.headline)
                Spacer()
                StatusBadge(text: key.status, tone: StatusTone.forStatus(key.status))
            }
            HStack {
                Text(key.maskedKey)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                CopyButton(text: key.key)
            }
            HStack {
                Label(key.group?.name ?? "未分组", systemImage: "folder")
                Spacer()
                Text("额度 \((key.quota_used ?? 0).compactCurrencyText)/\((key.quota ?? 0) == 0 ? "∞" : (key.quota ?? 0).compactCurrencyText)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let last = key.last_used_at {
                Text("最近使用：\(DateText.display(last))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack {
                Button(key.isActive ? "停用" : "启用", action: onToggle)
                    .buttonStyle(.bordered)
                Button("删除", role: .destructive, action: onDelete)
                    .buttonStyle(.bordered)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var vm = ProfileViewModel()
    @State private var showServerEditor = false
    @State private var serverDraft = ""

    var body: some View {
        List {
            if let error = vm.errorMessage {
                Section { ErrorBanner(message: error) }
            }
            if let success = vm.successMessage {
                Section { Text(success).foregroundStyle(.green) }
            }

            Section("个人资料") {
                TextField("用户名", text: $vm.username)
                TextField("头像 URL", text: $vm.avatarURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if let user = session.user {
                    LabeledContent("邮箱", value: user.email)
                    LabeledContent("角色", value: user.role)
                    LabeledContent("余额", value: user.balance.compactCurrencyText)
                    LabeledContent("并发", value: "\(user.concurrency)")
                }
                Button("保存资料") {
                    Task { await vm.saveProfile() }
                }
            }

            Section("修改密码") {
                SecureField("当前密码", text: $vm.oldPassword)
                SecureField("新密码", text: $vm.newPassword)
                SecureField("确认新密码", text: $vm.confirmPassword)
                Button("更新密码") {
                    Task { await vm.changePassword() }
                }
            }

            if !vm.quotas.isEmpty {
                Section("平台配额") {
                    ForEach(vm.quotas) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.platform).font(.subheadline.weight(.semibold))
                            Text("已用 \((item.used ?? 0).compactCurrencyText) / 配额 \((item.quota ?? 0).compactCurrencyText)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("实例设置") {
                LabeledContent("服务器", value: session.serverURL)
                Button("修改服务器地址") {
                    serverDraft = session.serverURL
                    showServerEditor = true
                }
                if let doc = session.publicSettings?.doc_url, !doc.isEmpty {
                    Link("打开文档", destination: URL(string: doc) ?? URL(string: "https://github.com/Wei-Shaw/sub2api")!)
                }
            }

            Section {
                Button("退出登录", role: .destructive) {
                    Task { await session.logout() }
                }
            }
        }
        .navigationTitle("我的")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await vm.load() } } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .sheet(isPresented: $showServerEditor) {
            NavigationStack {
                Form {
                    TextField("服务器地址", text: $serverDraft)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    Text("修改后需要重新登录。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("服务器")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showServerEditor = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            session.updateServerURL(serverDraft)
                            showServerEditor = false
                            Task { await session.logout() }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .overlay { if vm.isLoading && session.user == nil { LoadingView() } }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

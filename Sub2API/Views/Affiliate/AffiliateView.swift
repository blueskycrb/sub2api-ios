import SwiftUI

struct AffiliateView: View {
    @StateObject private var vm = AffiliateViewModel()

    var body: some View {
        List {
            if let error = vm.errorMessage {
                Section { ErrorBanner(message: error) { Task { await vm.load() } } }
            }
            if let success = vm.successMessage {
                Section { Text(success).foregroundStyle(.green) }
            }

            if let detail = vm.detail {
                Section("推广信息") {
                    if let code = detail.aff_code {
                        HStack {
                            Text("邀请码")
                            Spacer()
                            Text(code).font(.body.monospaced())
                            CopyButton(text: code)
                        }
                    }
                    LabeledContent("邀请人数", value: "\(detail.aff_count ?? 0)")
                    LabeledContent("可转余额", value: (detail.aff_quota ?? 0).compactCurrencyText)
                    LabeledContent("冻结返利", value: (detail.aff_frozen_quota ?? 0).compactCurrencyText)
                    LabeledContent("历史返利", value: (detail.aff_history_quota ?? 0).compactCurrencyText)
                    LabeledContent("返利比例", value: String(format: "%.1f%%", detail.effective_rebate_rate_percent ?? 0))
                    Button {
                        Task { await vm.transfer() }
                    } label: {
                        Label("转入余额", systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section("邀请列表") {
                    if let invitees = detail.invitees, !invitees.isEmpty {
                        ForEach(invitees) { user in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.username ?? user.email ?? "#\(user.user_id)")
                                    .font(.subheadline.weight(.semibold))
                                HStack {
                                    Text(user.email ?? "")
                                    Spacer()
                                    Text((user.total_rebate ?? 0).compactCurrencyText)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("暂无邀请用户").foregroundStyle(.secondary)
                    }
                }
            } else if !vm.isLoading {
                Section {
                    EmptyStateView(title: "暂无推广数据", systemImage: "person.2")
                }
            }
        }
        .navigationTitle("推广返利")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await vm.load() } } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .overlay { if vm.isLoading && vm.detail == nil { LoadingView() } }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

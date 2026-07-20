import SwiftUI

struct SubscriptionsView: View {
    @StateObject private var vm = SubscriptionsViewModel()

    var body: some View {
        List {
            if let error = vm.errorMessage {
                Section { ErrorBanner(message: error) { Task { await vm.load() } } }
            }

            if vm.items.isEmpty && !vm.isLoading {
                Section {
                    EmptyStateView(title: "暂无订阅", systemImage: "rectangle.stack", message: "兑换码或购买计划后会显示在这里")
                }
            } else {
                ForEach(vm.items) { item in
                    Section(item.group?.name ?? "订阅 #\(item.id)") {
                        LabeledContent("状态") {
                            StatusBadge(text: item.status, tone: StatusTone.forStatus(item.status))
                        }
                        LabeledContent("开始", value: DateText.display(item.starts_at))
                        LabeledContent("到期", value: DateText.display(item.expires_at))
                        if let p = vm.progress[item.id] {
                            progressRow("日", p.daily)
                            progressRow("周", p.weekly)
                            progressRow("月", p.monthly)
                        } else {
                            LabeledContent("日用量", value: (item.daily_usage_usd ?? 0).compactCurrencyText)
                            LabeledContent("周用量", value: (item.weekly_usage_usd ?? 0).compactCurrencyText)
                            LabeledContent("月用量", value: (item.monthly_usage_usd ?? 0).compactCurrencyText)
                        }
                    }
                }
            }
        }
        .navigationTitle("我的订阅")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await vm.load() } } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .overlay { if vm.isLoading && vm.items.isEmpty { LoadingView() } }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    @ViewBuilder
    private func progressRow(_ title: String, _ bucket: ProgressBucket?) -> some View {
        if let bucket {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                    Spacer()
                    Text("\((bucket.used ?? 0).compactCurrencyText) / \(bucket.limit == nil ? "∞" : (bucket.limit ?? 0).compactCurrencyText)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: min(max((bucket.percentage ?? 0) / 100.0, 0), 1))
            }
        }
    }
}

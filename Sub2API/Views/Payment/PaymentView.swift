import SwiftUI

struct PaymentView: View {
    @StateObject private var vm = PaymentViewModel()

    var body: some View {
        List {
            if let error = vm.errorMessage {
                Section { ErrorBanner(message: error) { Task { await vm.load() } } }
            }
            if let success = vm.successMessage {
                Section { Text(success).foregroundStyle(.green) }
            }
            if let url = vm.createdPayURL, let payURL = URL(string: url) {
                Section("支付链接") {
                    Link("打开支付页面", destination: payURL)
                    CopyButton(text: url)
                }
            }

            Section("订阅计划") {
                if vm.plans.isEmpty {
                    Text("暂无计划").foregroundStyle(.secondary)
                } else {
                    ForEach(vm.plans) { plan in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(plan.name).font(.headline)
                                Spacer()
                                Text((plan.price ?? 0).compactCurrencyText)
                                    .font(.headline.monospacedDigit())
                            }
                            if let desc = plan.description, !desc.isEmpty {
                                Text(desc).font(.caption).foregroundStyle(.secondary)
                            }
                            if let days = plan.duration_days {
                                Text("有效期 \(days) 天").font(.caption2).foregroundStyle(.tertiary)
                            }
                            Button("购买") {
                                Task { await vm.purchase(plan) }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("我的订单") {
                if vm.orders.isEmpty {
                    Text("暂无订单").foregroundStyle(.secondary)
                } else {
                    ForEach(vm.orders) { order in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(order.plan_name ?? order.out_trade_no ?? "#\(order.id)")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                StatusBadge(text: order.status ?? "-", tone: StatusTone.forStatus(order.status))
                            }
                            HStack {
                                Text((order.amount ?? 0).compactCurrencyText)
                                Spacer()
                                Text(DateText.display(order.created_at))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("购买订阅")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await vm.load() } } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .overlay { if vm.isLoading && vm.plans.isEmpty && vm.orders.isEmpty { LoadingView() } }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

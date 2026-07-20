import SwiftUI

struct UsageView: View {
    @StateObject private var vm = UsageViewModel()

    var body: some View {
        List {
            if let error = vm.errorMessage {
                Section { ErrorBanner(message: error) { Task { await vm.load() } } }
            }

            if let stats = vm.stats {
                Section("今日摘要") {
                    LabeledContent("请求", value: "\(stats.today_requests ?? stats.total_requests ?? 0)")
                    LabeledContent("Tokens", value: (stats.today_tokens ?? stats.total_tokens ?? 0).compactText)
                    LabeledContent("费用", value: (stats.today_actual_cost ?? stats.today_cost ?? stats.total_actual_cost ?? 0).compactCurrencyText)
                }
            }

            Section("用量记录 (\(vm.total))") {
                if vm.items.isEmpty && !vm.isLoading {
                    EmptyStateView(title: "暂无用量", systemImage: "chart.bar", message: "发起 API 请求后会出现在这里")
                } else {
                    ForEach(vm.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.model ?? "unknown").font(.subheadline.weight(.semibold))
                                Spacer()
                                Text((item.actual_cost ?? item.total_cost ?? 0).compactCurrencyText)
                                    .font(.subheadline.monospacedDigit())
                            }
                            HStack {
                                Text("in \((item.input_tokens ?? 0).compactText)")
                                Text("out \((item.output_tokens ?? 0).compactText)")
                                if let ms = item.duration_ms {
                                    Text("\(ms)ms")
                                }
                                Spacer()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            Text(DateText.display(item.created_at))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if vm.total > vm.items.count || vm.page > 1 {
                Section {
                    HStack {
                        Button("上一页") { Task { await vm.prevPage() } }
                            .disabled(vm.page <= 1)
                        Spacer()
                        Text("第 \(vm.page) 页")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("下一页") { Task { await vm.nextPage() } }
                            .disabled(vm.items.count >= vm.total && vm.total > 0)
                    }
                }
            }
        }
        .navigationTitle("用量")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await vm.load() } } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .overlay { if vm.isLoading && vm.items.isEmpty { LoadingView() } }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

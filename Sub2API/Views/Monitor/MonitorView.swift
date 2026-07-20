import SwiftUI

struct MonitorView: View {
    @StateObject private var vm = MonitorViewModel()

    var body: some View {
        List {
            Section("整体状态") {
                HStack {
                    StatusBadge(
                        text: vm.overallStatus == "operational" ? "正常" : "降级",
                        tone: vm.overallStatus == "operational" ? .success : .warning
                    )
                    Spacer()
                    Text("\(vm.items.count) 个监控点")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = vm.errorMessage {
                Section {
                    ErrorBanner(message: error) {
                        Task { await vm.load() }
                    }
                }
            }

            if vm.items.isEmpty && !vm.isLoading {
                Section {
                    EmptyStateView(
                        title: "暂无渠道状态",
                        systemImage: "waveform.path.ecg",
                        message: "服务端开启渠道监控后会显示在这里"
                    )
                }
            } else {
                Section("渠道状态") {
                    ForEach(vm.items) { item in
                        Button {
                            vm.selected = item
                            Task { await vm.loadDetail(for: item) }
                        } label: {
                            MonitorRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("渠道状态")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await vm.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(item: $vm.selected) { item in
            NavigationStack {
                MonitorDetailView(item: item, detail: vm.details[item.id])
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("关闭") { vm.selected = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .task {
                await vm.loadDetail(for: item)
            }
        }
        .overlay {
            if vm.isLoading && vm.items.isEmpty {
                LoadingView()
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

private struct MonitorRow: View {
    let item: UserMonitorView

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                StatusBadge(
                    text: item.primary_status ?? "unknown",
                    tone: StatusTone.forStatus(item.primary_status)
                )
            }

            HStack {
                Text(item.group_name ?? item.provider ?? "-")
                Spacer()
                if let model = item.primary_model {
                    Text(model)
                        .font(.caption.monospaced())
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                if let latency = item.primary_latency_ms {
                    Label(String(format: "%.0f ms", latency), systemImage: "timer")
                }
                if let availability = item.availability_7d {
                    Label(String(format: "7d %.1f%%", availability * (availability <= 1 ? 100 : 1)), systemImage: "chart.line.uptrend.xyaxis")
                }
                Spacer()
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)

            if let extras = item.extra_models, !extras.isEmpty {
                Text(extras.prefix(3).map { "\($0.model): \($0.status ?? "-")" }.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MonitorDetailView: View {
    let item: UserMonitorView
    let detail: UserMonitorDetail?

    var body: some View {
        List {
            Section("概览") {
                LabeledContent("名称", value: item.name)
                LabeledContent("分组", value: item.group_name ?? "-")
                LabeledContent("提供商", value: item.provider ?? "-")
                LabeledContent("主模型", value: item.primary_model ?? "-")
                LabeledContent("状态", value: item.primary_status ?? "-")
                if let latency = item.primary_latency_ms {
                    LabeledContent("延迟", value: String(format: "%.0f ms", latency))
                }
                if let availability = item.availability_7d {
                    LabeledContent("7 日可用率", value: String(format: "%.2f%%", availability * (availability <= 1 ? 100 : 1)))
                }
            }

            if let models = detail?.models, !models.isEmpty {
                Section("模型详情") {
                    ForEach(models) { model in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(model.model)
                                    .font(.subheadline.monospaced())
                                Spacer()
                                StatusBadge(
                                    text: model.latest_status ?? "unknown",
                                    tone: StatusTone.forStatus(model.latest_status)
                                )
                            }
                            HStack {
                                if let latency = model.latest_latency_ms {
                                    Text(String(format: "%.0f ms", latency))
                                }
                                if let a7 = model.availability_7d {
                                    Text(String(format: "7d %.1f%%", a7 * (a7 <= 1 ? 100 : 1)))
                                }
                                if let a15 = model.availability_15d {
                                    Text(String(format: "15d %.1f%%", a15 * (a15 <= 1 ? 100 : 1)))
                                }
                                if let a30 = model.availability_30d {
                                    Text(String(format: "30d %.1f%%", a30 * (a30 <= 1 ? 100 : 1)))
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } else {
                Section {
                    Text("正在加载详情或暂无模型数据")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("监控详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

import SwiftUI

struct ChannelsView: View {
    @StateObject private var vm = ChannelsViewModel()

    var body: some View {
        List {
            if let error = vm.errorMessage {
                Section { ErrorBanner(message: error) { Task { await vm.load() } } }
            }

            if vm.items.isEmpty && !vm.isLoading {
                Section {
                    EmptyStateView(title: "暂无可用渠道", systemImage: "point.3.connected.trianglepath.dotted")
                }
            } else {
                ForEach(vm.items) { channel in
                    Section(channel.name) {
                        if let desc = channel.description, !desc.isEmpty {
                            Text(desc).font(.footnote).foregroundStyle(.secondary)
                        }
                        if let platforms = channel.platforms {
                            ForEach(Array(platforms.enumerated()), id: \.offset) { _, section in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(section.platform)
                                        .font(.subheadline.weight(.semibold))
                                    if let groups = section.groups, !groups.isEmpty {
                                        Text("分组：\(groups.map(\.name).joined(separator: " / "))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let models = section.supported_models, !models.isEmpty {
                                        ForEach(models.prefix(12)) { model in
                                            HStack {
                                                Text(model.name).font(.caption.monospaced())
                                                Spacer()
                                                if let pricing = model.pricing {
                                                    Text(priceText(pricing))
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                        if models.count > 12 {
                                            Text("还有 \(models.count - 12) 个模型...")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("可用渠道")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await vm.load() } } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .overlay { if vm.isLoading && vm.items.isEmpty { LoadingView() } }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    private func priceText(_ pricing: UserSupportedModelPricing) -> String {
        if let per = pricing.per_request_price {
            return "\(per.compactCurrencyText)/req"
        }
        let input = pricing.input_price.map { $0.compactCurrencyText } ?? "-"
        let output = pricing.output_price.map { $0.compactCurrencyText } ?? "-"
        return "in \(input) / out \(output)"
    }
}

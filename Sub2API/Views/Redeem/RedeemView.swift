import SwiftUI

struct RedeemView: View {
    @StateObject private var vm = RedeemViewModel()

    var body: some View {
        List {
            Section("兑换") {
                TextField("输入兑换码", text: $vm.code)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    Task { await vm.redeem() }
                } label: {
                    Text("立即兑换").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if let error = vm.errorMessage {
                Section { ErrorBanner(message: error) }
            }
            if let success = vm.successMessage {
                Section { Text(success).foregroundStyle(.green) }
            }

            Section("兑换历史") {
                if vm.history.isEmpty {
                    Text("暂无记录").foregroundStyle(.secondary)
                } else {
                    ForEach(vm.history) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.code).font(.subheadline.monospaced())
                                Spacer()
                                Text(item.value.compactCurrencyText)
                            }
                            Text("\(item.type) · \(DateText.display(item.used_at ?? item.created_at))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let notes = item.notes, !notes.isEmpty {
                                Text(notes).font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("兑换码")
        .overlay { if vm.isLoading && vm.history.isEmpty { LoadingView() } }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

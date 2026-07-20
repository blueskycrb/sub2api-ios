import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var vm = DashboardViewModel()

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error = vm.errorMessage {
                    ErrorBanner(message: error) {
                        Task { await vm.load() }
                    }
                }

                if let user = session.user {
                    SectionCard(title: "????", systemImage: "person.crop.circle.fill") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.username).font(.title3.bold())
                                Text(user.email).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusBadge(text: user.role, tone: user.isAdmin ? .warning : .success)
                        }
                        LazyVGrid(columns: columns, spacing: 12) {
                            StatCard("??", value: user.balance.compactCurrencyText, systemImage: "dollarsign.circle.fill")
                            StatCard("??", value: "\(user.concurrency)", systemImage: "bolt.fill")
                            if let admin = vm.adminStats {
                                StatCard(
                                    "??",
                                    value: "\(admin.total_accounts ?? 0)",
                                    subtitle: "\(admin.normal_accounts ?? 0) ??",
                                    systemImage: "person.2.fill"
                                )
                                StatCard(
                                    "??",
                                    value: "\(admin.total_users ?? 0)",
                                    subtitle: "\(admin.active_users ?? 0) ??",
                                    systemImage: "person.crop.circle.badge.checkmark"
                                )
                            }
                        }
                        if user.isAdmin {
                            Text("???????????????????????")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let stats = vm.stats {
                    SectionCard(title: "????", systemImage: "chart.bar.fill") {
                        LazyVGrid(columns: columns, spacing: 12) {
                            StatCard("????", value: (stats.today_requests ?? 0).compactText, systemImage: "arrow.triangle.2.circlepath")
                            StatCard("????", value: (stats.today_actual_cost ?? stats.today_cost ?? 0).compactCurrencyText, systemImage: "yensign.circle.fill")
                            StatCard("????", value: (stats.total_requests ?? 0).compactText, systemImage: "sum")
                            StatCard("????", value: (stats.total_actual_cost ?? stats.total_cost ?? 0).compactCurrencyText, systemImage: "creditcard.fill")
                            StatCard("API ??", value: "\(stats.active_api_keys ?? 0)/\(stats.total_api_keys ?? 0)", subtitle: "??/??", systemImage: "key.fill")
                            StatCard("RPM / TPM", value: String(format: "%.1f / %.0f", stats.rpm ?? 0, stats.tpm ?? 0), systemImage: "speedometer")
                        }
                    }
                }

                if let summary = vm.summary {
                    SectionCard(title: "????", systemImage: "rectangle.stack.fill") {
                        Text("?????\(summary.active_count ?? 0)")
                            .font(.subheadline)
                        if let items = summary.subscriptions, !items.isEmpty {
                            ForEach(items) { item in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.group_name ?? "?? #\(item.id)").font(.subheadline.weight(.semibold))
                                        Text("???\(DateText.display(item.expires_at))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    StatusBadge(text: item.status ?? "-", tone: StatusTone.forStatus(item.status))
                                }
                                .padding(.vertical, 4)
                            }
                        } else {
                            Text("????").foregroundStyle(.secondary).font(.subheadline)
                        }
                    }
                }

                SectionCard(title: "??", systemImage: "megaphone.fill") {
                    if vm.announcements.isEmpty {
                        Text("????").foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.announcements.prefix(5)) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.title).font(.subheadline.weight(.semibold))
                                    Spacer()
                                    if item.isUnread {
                                        StatusBadge(text: "??", tone: .warning)
                                    }
                                }
                                Text(item.content)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(4)
                                if item.isUnread {
                                    Button("????") {
                                        Task { await vm.markRead(item) }
                                    }
                                    .font(.caption.weight(.semibold))
                                }
                            }
                            .padding(.vertical, 6)
                            Divider()
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("???")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await vm.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .overlay { if vm.isLoading && vm.stats == nil { LoadingView() } }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

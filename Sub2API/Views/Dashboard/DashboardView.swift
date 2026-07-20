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
                    SectionCard(title: "账户概览", systemImage: "person.crop.circle") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.username).font(.title3.bold())
                                Text(user.email).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusBadge(text: user.role, tone: user.isAdmin ? .warning : .success)
                        }
                        LazyVGrid(columns: columns, spacing: 12) {
                            StatCard("余额", value: user.balance.compactCurrencyText, systemImage: "dollarsign.circle")
                            StatCard("并发", value: "\(user.concurrency)", systemImage: "bolt.horizontal.circle")
                        }
                        if user.isAdmin {
                            Text("当前账号具备管理员权限。iOS 客户端优先覆盖用户中心功能，管理后台请使用网页端。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let stats = vm.stats {
                    SectionCard(title: "用量统计", systemImage: "chart.line.uptrend.xyaxis") {
                        LazyVGrid(columns: columns, spacing: 12) {
                            StatCard("今日请求", value: (stats.today_requests ?? 0).compactText, systemImage: "arrow.triangle.2.circlepath")
                            StatCard("今日费用", value: (stats.today_actual_cost ?? stats.today_cost ?? 0).compactCurrencyText, systemImage: "yensign.circle")
                            StatCard("累计请求", value: (stats.total_requests ?? 0).compactText, systemImage: "sum")
                            StatCard("累计费用", value: (stats.total_actual_cost ?? stats.total_cost ?? 0).compactCurrencyText, systemImage: "creditcard")
                            StatCard("API 密钥", value: "\(stats.active_api_keys ?? 0)/\(stats.total_api_keys ?? 0)", subtitle: "活跃/全部", systemImage: "key")
                            StatCard("RPM / TPM", value: String(format: "%.1f / %.0f", stats.rpm ?? 0, stats.tpm ?? 0), systemImage: "speedometer")
                        }
                    }
                }

                if let summary = vm.summary {
                    SectionCard(title: "订阅摘要", systemImage: "rectangle.stack") {
                        Text("活跃订阅：\(summary.active_count ?? 0)")
                            .font(.subheadline)
                        if let items = summary.subscriptions, !items.isEmpty {
                            ForEach(items) { item in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.group_name ?? "订阅 #\(item.id)").font(.subheadline.weight(.semibold))
                                        Text("到期：\(DateText.display(item.expires_at))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    StatusBadge(text: item.status ?? "-", tone: StatusTone.forStatus(item.status))
                                }
                                .padding(.vertical, 4)
                            }
                        } else {
                            Text("暂无订阅").foregroundStyle(.secondary).font(.subheadline)
                        }
                    }
                }

                SectionCard(title: "公告", systemImage: "megaphone.fill") {
                    if vm.announcements.isEmpty {
                        Text("暂无公告").foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.announcements.prefix(5)) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.title).font(.subheadline.weight(.semibold))
                                    Spacer()
                                    if item.isUnread {
                                        StatusBadge(text: "未读", tone: .warning)
                                    }
                                }
                                Text(item.content)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(4)
                                if item.isUnread {
                                    Button("标记已读") {
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
        .navigationTitle("仪表盘")
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

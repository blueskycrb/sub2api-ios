import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var vm = DashboardViewModel()

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private let modelColors: [Color] = [
        Color(red: 0.231, green: 0.510, blue: 0.965), // #3b82f6
        Color(red: 0.063, green: 0.725, blue: 0.506), // #10b981
        Color(red: 0.961, green: 0.620, blue: 0.043), // #f59e0b
        Color(red: 0.937, green: 0.267, blue: 0.267), // #ef4444
        Color(red: 0.545, green: 0.361, blue: 0.965), // #8b5cf6
        Color(red: 0.925, green: 0.286, blue: 0.600), // #ec4899
        Color(red: 0.024, green: 0.714, blue: 0.831), // #06b6d4
        Color(red: 0.518, green: 0.757, blue: 0.086)  // #84cc16
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let error = vm.errorMessage {
                    ErrorBanner(message: error) {
                        Task { await vm.refresh() }
                    }
                }

                if let user = session.user {
                    SectionCard(title: "账户概览", systemImage: "person.crop.circle.fill") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.username).font(.title3.bold())
                                Text(user.email).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusBadge(text: user.role, tone: user.isAdmin ? .warning : .success)
                        }
                        LazyVGrid(columns: columns, spacing: 12) {
                            StatCard("余额", value: user.balance.compactCurrencyText, systemImage: "dollarsign.circle.fill")
                            StatCard("并发", value: "\(user.concurrency)", systemImage: "bolt.fill")
                            if let admin = vm.adminStats {
                                StatCard(
                                    "账号",
                                    value: "\(admin.total_accounts ?? 0)",
                                    subtitle: "\(admin.normal_accounts ?? 0) 启用",
                                    systemImage: "person.2.fill"
                                )
                                StatCard(
                                    "用户",
                                    value: "\(admin.total_users ?? 0)",
                                    subtitle: "\(admin.active_users ?? 0) 活跃",
                                    systemImage: "person.crop.circle.badge.checkmark"
                                )
                            }
                        }
                        if user.isAdmin {
                            Text("当前账号具备管理员权限，已显示账号与用户统计。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let stats = vm.stats {
                    SectionCard(title: "用量统计", systemImage: "chart.bar.fill") {
                        LazyVGrid(columns: columns, spacing: 12) {
                            StatCard("今日请求", value: (stats.today_requests ?? 0).compactText, systemImage: "arrow.triangle.2.circlepath")
                            StatCard("今日费用", value: (stats.today_actual_cost ?? stats.today_cost ?? 0).compactCurrencyText, systemImage: "yensign.circle.fill")
                            StatCard("累计请求", value: (stats.total_requests ?? 0).compactText, systemImage: "sum")
                            StatCard("累计费用", value: (stats.total_actual_cost ?? stats.total_cost ?? 0).compactCurrencyText, systemImage: "creditcard.fill")
                            StatCard("API 密钥", value: "\(stats.active_api_keys ?? 0)/\(stats.total_api_keys ?? 0)", subtitle: "活跃/全部", systemImage: "key.fill")
                            StatCard("RPM / TPM", value: String(format: "%.1f / %.0f", stats.rpm ?? 0, stats.tpm ?? 0), systemImage: "speedometer")
                        }
                    }
                }

                SectionCard(title: "模型分布", systemImage: "chart.pie.fill") {
                    if !vm.modelRangeStart.isEmpty {
                        Text("\(vm.modelRangeStart) ~ \(vm.modelRangeEnd)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if vm.models.isEmpty {
                        Text("暂无模型用量数据")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                    } else {
                        HStack(alignment: .center, spacing: 16) {
                            ModelDonutChart(models: vm.models, colors: modelColors)
                                .frame(width: 140, height: 140)

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(vm.models.prefix(6).enumerated()), id: \.element.id) { index, item in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(modelColors[index % modelColors.count])
                                            .frame(width: 8, height: 8)
                                        Text(item.model)
                                            .font(.caption2.weight(.medium))
                                            .lineLimit(1)
                                    }
                                }
                                if vm.models.count > 6 {
                                    Text("+\(vm.models.count - 6) 个模型")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        VStack(spacing: 0) {
                            HStack {
                                Text("模型").frame(maxWidth: .infinity, alignment: .leading)
                                Text("请求").frame(width: 48, alignment: .trailing)
                                Text("Token").frame(width: 52, alignment: .trailing)
                                Text("实际").frame(width: 58, alignment: .trailing)
                                Text("标准").frame(width: 58, alignment: .trailing)
                            }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)

                            Divider()

                            ForEach(Array(vm.models.enumerated()), id: \.element.id) { index, item in
                                HStack(alignment: .center, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(modelColors[index % modelColors.count])
                                            .frame(width: 7, height: 7)
                                        Text(item.model)
                                            .font(.caption.weight(.medium))
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    Text((item.requests ?? 0).compactText)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 48, alignment: .trailing)

                                    Text((item.total_tokens ?? 0).compactText)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 52, alignment: .trailing)

                                    Text((item.actual_cost ?? 0).compactCurrencyText)
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                        .frame(width: 58, alignment: .trailing)
                                        .minimumScaleFactor(0.7)
                                        .lineLimit(1)

                                    Text((item.cost ?? 0).compactCurrencyText)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 58, alignment: .trailing)
                                        .minimumScaleFactor(0.7)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 8)

                                if index < vm.models.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("仪表盘")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // 保持按钮结构稳定，避免刷新中替换为 ProgressView 触发 refreshable 取消
                Button {
                    Task { await vm.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .opacity(vm.isRefreshing || vm.isLoading ? 0.35 : 1)
                }
                .disabled(vm.isRefreshing || vm.isLoading)
                .accessibilityLabel("刷新")
            }
        }
        .overlay { if vm.isLoading && !vm.hasContent { LoadingView() } }
        .task { await vm.loadIfNeeded() }
        .refreshable {
            // 交给 ViewModel 做“抗取消”加载；此处只等待其完成以驱动系统刷新控件
            await vm.refresh()
        }
    }
}

struct ModelDonutChart: View {
    let models: [ModelStat]
    let colors: [Color]
    var lineWidth: CGFloat = 22

    private var values: [Double] {
        models.map { Double($0.total_tokens ?? 0) }
    }

    private var total: Double {
        max(values.reduce(0, +), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.06), lineWidth: lineWidth)

            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
                var start = Angle.degrees(-90)
                for (index, value) in values.enumerated() {
                    guard value > 0 else { continue }
                    let delta = Angle.degrees(360 * value / total)
                    var path = Path()
                    path.addArc(center: CGPoint(x: size.width / 2, y: size.height / 2),
                                radius: min(rect.width, rect.height) / 2,
                                startAngle: start,
                                endAngle: start + delta,
                                clockwise: false)
                    context.stroke(
                        path,
                        with: .color(colors[index % colors.count]),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                    )
                    start += delta
                }
            }

            VStack(spacing: 2) {
                Text("\(models.count)")
                    .font(.title3.bold())
                Text("模型")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

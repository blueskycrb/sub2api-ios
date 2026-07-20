import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var session: AppSession
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { DashboardView() }
                .tabItem { Label("仪表盘", systemImage: "chart.bar.fill") }
                .tag(0)

            NavigationStack { KeysView() }
                .tabItem { Label("密钥", systemImage: "key.fill") }
                .tag(1)

            NavigationStack { UsageView() }
                .tabItem { Label("用量", systemImage: "chart.bar.fill") }
                .tag(2)

            NavigationStack { MoreView() }
                .tabItem { Label("更多", systemImage: "square.grid.2x2.fill") }
                .tag(3)

            NavigationStack { ProfileView() }
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(4)
        }
    }
}

struct MoreView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        List {
            Section("账户") {
                NavigationLink {
                    SubscriptionsView()
                } label: {
                    Label("我的订阅", systemImage: "rectangle.stack.fill")
                }
                NavigationLink {
                    RedeemView()
                } label: {
                    Label("兑换码", systemImage: "giftcard.fill")
                }
                NavigationLink {
                    AffiliateView()
                } label: {
                    Label("推广返利", systemImage: "person.2.fill")
                }
            }

            Section("资源") {
                NavigationLink {
                    ChannelsView()
                } label: {
                    Label("可用渠道", systemImage: "point.3.connected.trianglepath.dotted")
                }
                if session.channelMonitorEnabled {
                    NavigationLink {
                        MonitorView()
                    } label: {
                        Label("渠道状态", systemImage: "waveform.path.ecg")
                    }
                }
            }

            if session.paymentEnabled {
                Section("支付") {
                    NavigationLink {
                        PaymentView()
                    } label: {
                        Label("购买订阅", systemImage: "cart.fill")
                    }
                }
            }

            Section("实例") {
                LabeledContent("服务器", value: session.serverURL)
                LabeledContent("站点", value: session.siteName)
            }
        }
        .navigationTitle("更多")
    }
}

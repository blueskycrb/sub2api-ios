import SwiftUI
import UIKit

struct LoginView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var vm = AuthViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    SectionCard(title: "服务器", systemImage: "server.rack") {
                        TextField("https://your-sub2api.example.com", text: $vm.serverURL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Button {
                            Task { await vm.saveServerAndLoad() }
                        } label: {
                            Label("连接并加载公开设置", systemImage: "link")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if vm.requires2FA {
                        twoFACard
                    } else if vm.isRegisterMode {
                        registerCard
                    } else {
                        loginCard
                    }

                    if let error = vm.errorMessage ?? session.authExpiredMessage {
                        ErrorBanner(message: error)
                    }
                    if let info = vm.infoMessage {
                        Text(info)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .navigationTitle(session.siteName)
            .overlay {
                if vm.isLoading {
                    ProgressView().padding().background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .task { await vm.prepare() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.siteName)
                .font(.largeTitle.bold())
            Text(session.publicSettings?.site_subtitle?.nilIfEmpty ?? "连接你的 Sub2API 实例，管理密钥、用量与订阅")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var loginCard: some View {
        SectionCard(title: "登录", systemImage: "person.badge.key.fill") {
            field("邮箱", text: $vm.email, keyboard: .emailAddress)
            secure("密码", text: $vm.password)

            Button {
                Task { await vm.login() }
            } label: {
                Text("登录").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.email.isEmpty || vm.password.isEmpty)

            HStack {
                if session.publicSettings?.registration_enabled != false {
                    Button("注册账号") { vm.isRegisterMode = true }
                }
                Spacer()
                if session.publicSettings?.password_reset_enabled != false {
                    Button("忘记密码") {
                        Task { await vm.forgotPassword() }
                    }
                }
            }
            .font(.subheadline)
        }
    }

    private var registerCard: some View {
        SectionCard(title: "注册", systemImage: "person.crop.circle.badge.plus") {
            field("邮箱", text: $vm.email, keyboard: .emailAddress)
            secure("密码", text: $vm.password)
            secure("确认密码", text: $vm.confirmPassword)

            if session.publicSettings?.email_verify_enabled == true {
                HStack {
                    field("邮箱验证码", text: $vm.verifyCode)
                    Button("发送") { Task { await vm.sendCode() } }
                        .buttonStyle(.bordered)
                }
            }
            if session.publicSettings?.invitation_code_enabled == true {
                field("邀请码", text: $vm.invitationCode)
            }
            if session.publicSettings?.promo_code_enabled == true {
                field("优惠码", text: $vm.promoCode)
            }
            field("推广码（可选）", text: $vm.affCode)

            Button {
                Task { await vm.register() }
            } label: {
                Text("创建账号").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button("返回登录") { vm.isRegisterMode = false }
                .font(.subheadline)
        }
    }

    private var twoFACard: some View {
        SectionCard(title: "二次验证", systemImage: "lock.shield.fill") {
            if let masked = vm.maskedEmail {
                Text("账号 \(masked)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            field("6 位验证码", text: $vm.totpCode, keyboard: .numberPad)
            Button {
                Task { await vm.submit2FA() }
            } label: {
                Text("验证并登录").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button("返回") {
                vm.requires2FA = false
                vm.tempToken = nil
                vm.totpCode = ""
            }
        }
    }

    private func field(_ title: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboard)
                .padding(12)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func secure(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            SecureField(title, text: text)
                .padding(12)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

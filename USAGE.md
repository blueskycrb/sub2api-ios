# Sub2API iOS 使用说明

## 一句话

这是对接官方 [Sub2API](https://github.com/Wei-Shaw/sub2api) 的 **iOS 用户端 App**，功能对齐网页版用户中心，支持用 GitHub Actions 在 macOS runner 上构建。

## 已覆盖功能（对照网页）

- 登录 / 注册 / 2FA
- 仪表盘（余额、并发、今日与累计用量、公告）
- API 密钥（创建 / 启停 / 删除 / 复制）
- 用量记录
- 我的订阅与进度
- 兑换码
- 推广返利
- 可用渠道（模型与定价）
- 渠道状态监控（`/channel-monitors`）
- 个人资料与改密
- 购买订阅 / 订单（当服务端 `payment_enabled=true`）
- 自定义服务器地址

## 本地打开

1. 用 Mac + Xcode 15+ 打开：

```bash
open Sub2API.xcodeproj
```

2. 选择 iPhone 模拟器，Run
3. 输入你的 Sub2API 地址，如 `https://your.domain` 或 `http://192.168.x.x:8080`
4. 登录后即可管理密钥与查看用量

## GitHub 构建

仓库已包含：

```
.github/workflows/ios-build.yml
```

推送后自动：

1. `macos-14` runner
2. `xcodebuild` 编译 iOS Simulator
3. 上传 `Sub2API.app` artifact

### 可选：签名 IPA

在 GitHub Secrets 配置：

- `IOS_CERTIFICATE_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISION_PROFILE_BASE64`
- `IOS_TEAM_ID`
- `IOS_BUNDLE_ID`（可选，默认 `org.sub2api.app`）

然后 `Actions` → `iOS Build` → `Run workflow`，把 `sign` 设为 `true`。

## 与官方 API 的关系

客户端调用与网页前端相同的 `/api/v1` 接口，例如：

- `POST /auth/login`
- `GET /usage/dashboard/stats`
- `GET/POST /keys`
- `GET /usage`
- `GET /subscriptions`
- `POST /redeem`
- `GET /channels/available`
- `GET /user/profile`

因此只要你的 Sub2API 实例可被手机访问，App 就能用。

## 说明

- 当前版本完整覆盖 **用户中心**；网页管理后台（账号池、运维监控、系统设置等）仍建议用桌面浏览器。
- 本项目可直接推到你自己的 GitHub 仓库启用 CI。

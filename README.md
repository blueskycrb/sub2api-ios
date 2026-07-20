# Sub2API iOS

原生 SwiftUI 客户端，对齐 [Sub2API](https://github.com/Wei-Shaw/sub2api) 网页用户端能力，可连接任意自托管实例。

## 功能对齐

| 网页路由 | iOS 页面 | 说明 |
|---|---|---|
| `/login` `/register` | 登录 / 注册 | 支持邮箱密码、2FA、公开设置开关 |
| `/dashboard` | 仪表盘 | 余额、并发、今日/累计用量、公告 |
| `/keys` | API 密钥 | 列表、创建、启停、删除、复制 |
| `/usage` | 用量记录 | 分页日志 + 费用摘要 |
| `/subscriptions` | 我的订阅 | 状态与额度进度 |
| `/redeem` | 兑换码 | 兑换与历史 |
| `/affiliate` | 推广返利 | 邀请码、配额、一键转入余额 |
| `/available-channels` | 可用渠道 | 渠道 / 分组 / 模型与定价 |
| `/profile` | 个人资料 | 资料、改密、会话退出 |
| `/purchase` `/orders` | 购买 / 订单 | 受 `payment_enabled` 控制 |
| `/monitor` | 渠道状态 | 列表 + 延迟/可用率详情 |
| 设置 | 服务器地址 | 可配置 `https://your-host` |

> 管理后台（账号池、分组、运维监控等）体量很大，本客户端优先完整覆盖**用户中心**；若账号是 `admin`，仪表盘会显示管理入口提示。

## 技术栈

- iOS 16+ / SwiftUI / async-await
- `URLSession` REST 客户端，对接 `/api/v1`
- Keychain 保存 access / refresh token
- GitHub Actions (`macos-14`) 构建模拟器包与 TrollStore IPA

## 本地运行

1. 安装 Xcode 15+
2. 打开 `Sub2API.xcodeproj`
3. 选择 iPhone 模拟器运行
4. 首次启动填写你的 Sub2API 服务器地址，例如：
   - `https://api.example.com`
   - `http://192.168.1.10:8080`

应用会自动拼接 `/api/v1`。

## GitHub 构建

推送到 GitHub 后，workflow `.github/workflows/ios-build.yml` 会：

1. 检出代码
2. 使用 Xcode 选择最新稳定版
3. `xcodebuild` 构建 iPhone 模拟器
4. 额外构建 **真机 unsigned IPA**（TrollStore 可装）
5. 上传 build 产物

### 下载 TrollStore IPA（手机直接装）

1. 打开仓库 Actions
2. 进入最新成功的 `iOS Build`
3. 下载 `sub2api-ios-trollstore-ipa`
4. 解压得到 `Sub2API.ipa`
5. 传到 iPhone，用 **TrollStore → Install** 安装

### 可选：正式签名 IPA

在仓库 Secrets 中配置：

- `IOS_CERTIFICATE_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISION_PROFILE_BASE64`
- `IOS_TEAM_ID`
- `IOS_BUNDLE_ID`（默认 `org.sub2api.app`）

然后手动触发 workflow，并把输入 `sign` 设为 `true`。

## API 约定

与官方前端一致：

- Base URL: `{server}/api/v1`
- Auth header: `Authorization: Bearer <access_token>`
- 响应包装：`{ "code": 0, "message": "...", "data": ... }`
- Token 刷新：`POST /auth/refresh`

## License

客户端代码可自由用于对接你自己的 Sub2API 实例。Sub2API 服务端本身遵循其上游 LGPL-3.0。
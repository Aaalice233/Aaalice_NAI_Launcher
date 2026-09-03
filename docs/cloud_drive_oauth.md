# Google Drive / OneDrive OAuth 开发者配置

本文只描述云盘 OAuth 基础设施和人工控制台配置。仓库中不得提交真实 client ID、Google Windows Desktop client secret、token、`google-services.json` 或下载的 Google plist。

## 安全模型

- Android Google Drive 使用 Google 官方 [`google_sign_in`](https://pub.dev/packages/google_sign_in) SDK；Google 已停止支持 Android 上自建 custom-scheme OAuth redirect。macOS Google Drive 与 Android/macOS OneDrive 使用 [`flutter_appauth`](https://pub.dev/packages/flutter_appauth)（AppAuth system browser + authorization code + PKCE）。Google 唯一文件业务权限是 [`drive.appdata`](https://developers.google.com/workspace/drive/api/guides/appdata)；Microsoft 唯一文件业务权限是 `Files.ReadWrite.AppFolder`。OIDC 身份权限用于稳定账号 ID，应用直接持有的 refresh token 只进入系统安全存储；Android Google 的续期凭据由官方 SDK 管理。
- Windows 对两个 provider 都使用系统默认浏览器、`127.0.0.1` 随机端口、authorization code、PKCE S256、state 和 nonce。Google Desktop client 的 token endpoint 还要求该注册项附带的 client secret；它只能从开发或 CI 环境注入，不得提交。OneDrive 仍按 public client 运行，不创建 client secret。
- scope 和 OAuth endpoint 固定在代码中，不能通过 `--dart-define` 扩大。session 是严格版本化 JSON，只能写入 `flutter_secure_storage`；secure-storage key 由 provider 和 account ID 哈希共同隔离。
- redirect URI、state、nonce、PKCE verifier/audience/expiry 均会校验。loopback 仅绑定 IPv4 loopback，回调有三分钟超时，只接受一次正确路径的回调。
- `toString`、异常和诊断不输出 access/refresh token。不要记录 package 返回的原始 token 对象；部分上游 package 的默认 `toString` 会包含 token。

官方协议依据：

- Google native/desktop OAuth：[OAuth 2.0 for Mobile & Desktop Apps](https://developers.google.com/identity/protocols/oauth2/native-app)
- Google OAuth scope 列表：[OAuth 2.0 Scopes for Google APIs](https://developers.google.com/identity/protocols/oauth2/scopes#drive)
- AppAuth 原生应用安全要求：[AppAuth](https://appauth.io/) 与 [RFC 8252](https://www.rfc-editor.org/rfc/rfc8252)
- Microsoft authorization code + PKCE：[Microsoft identity platform OAuth 2.0 authorization code flow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-auth-code-flow)
- Microsoft permissions：[Microsoft identity platform scopes and permissions](https://learn.microsoft.com/en-us/entra/identity-platform/scopes-oidc)

文件 API 与并发依据全部使用官方参考：

- Google `appDataFolder` 的创建与列表规则：[Store application-specific data](https://developers.google.com/workspace/drive/api/guides/appdata)；列表必须带 `spaces=appDataFolder`，创建必须把 `appDataFolder` 放入 `parents`。
- Google Drive v3：[files.list](https://developers.google.com/workspace/drive/api/reference/rest/v3/files/list)、[files.create](https://developers.google.com/workspace/drive/api/reference/rest/v3/files/create)、[files.update](https://developers.google.com/workspace/drive/api/reference/rest/v3/files/update)、[files.get / `alt=media`](https://developers.google.com/workspace/drive/api/guides/manage-downloads)、[files.delete](https://developers.google.com/workspace/drive/api/reference/rest/v3/files/delete)。列表消费全部 `nextPageToken`；上传后校验版本与内容哈希；Google 的 HEAD/KEY 条件更新按弱一致性能力显式降级，不能声称强 CAS。
- Microsoft app folder：[`/special/approot`](https://learn.microsoft.com/en-us/graph/onedrive-sharepoint-appfolder) 与最小委托权限 `Files.ReadWrite.AppFolder`。
- Microsoft Graph DriveItem：[列举 children](https://learn.microsoft.com/en-us/graph/api/driveitem-list-children)、[下载 content](https://learn.microsoft.com/en-us/graph/api/driveitem-get-content)、[上传/替换 content](https://learn.microsoft.com/en-us/graph/api/driveitem-put-content)、[大文件 upload session](https://learn.microsoft.com/en-us/graph/api/driveitem-createuploadsession)、[删除与 `If-Match`](https://learn.microsoft.com/en-us/graph/api/driveitem-delete)。所有 `@odata.nextLink` 都要消费；`eTag` 用于文件内容的条件更新，`412` 映射为同步冲突，不能覆盖重试。
- 两家服务的 `429`/临时 `5xx` 仅在操作可安全重放时按 `Retry-After` 有界退避；响应丢失后结果不确定的可变写入必须回到重新读取/对账流程，不能盲目重放。

`google_sign_in 7.2.0` 与 `flutter_appauth 12.1.0` 均兼容项目的 Dart 3.10.7+、Flutter 3.44.2。`flutter_appauth` 不支持 Windows，因此 Windows 使用仓库内有界 loopback 实现。

## Google Cloud Console

1. 在 [Google Cloud Console](https://console.cloud.google.com/apis/credentials) 创建/选择项目，启用 Google Drive API。
2. 配置 [OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent)，只声明本应用使用的 `drive.appdata` 文件业务 scope。按 Google 当前规则设置测试用户、隐私政策、应用域名和发布状态；在对外发布前完成品牌/权限审核前置工作。`drive.appdata` 当前属于 non-sensitive scope，但 Console 要求与审核政策可能变化，发布前必须复核官方页面。
3. Android：注册 package `com.aaalice.nai_launcher` 的 Android OAuth client，并登记 debug/release/CI 签名证书 SHA-1/SHA-256；再创建 Web OAuth client，将其 client ID 作为 `GOOGLE_DRIVE_ANDROID_CLIENT_ID`（官方 SDK 的 `serverClientId`）。Google SDK 自行完成 Android 回调，不配置 `GOOGLE_DRIVE_ANDROID_REDIRECT_URI`，仓库也不提交 `google-services.json`。
4. macOS：创建与 bundle ID `com.aaalice.naiLauncher` 对应的 OAuth client。redirect URI 的 scheme 必须是 Console 提供的 reversed client ID（`com.googleusercontent.apps.…`）。macOS 构建脚本从 `GOOGLE_DRIVE_MACOS_REDIRECT_URI` 注入该 URL scheme。
5. Windows：创建 Desktop app OAuth client。Google 的 Desktop client 原生应用策略允许 loopback IP redirect；应用以 `http://127.0.0.1` 为基值，在运行时追加随机端口和 `/oauth2/callback`。将该 Desktop client 下载凭据中的 client secret 作为构建环境配置传入；不要使用 Web client 的 ID/secret 或 redirect 配置。桌面二进制无法把该值视为机密，因此仍必须依赖 PKCE、state 和 nonce，且不得把它当作服务端凭据。

Google disconnect 在 Android 调用官方 SDK `disconnect`，在 macOS/Windows 调用 Google [revocation endpoint](https://developers.google.com/identity/protocols/oauth2/web-server#tokenrevoke)，随后无论远端撤销结果如何都删除本地 secure-storage session。

## Microsoft Entra 管理中心

1. 在 [Microsoft Entra app registrations](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade) 注册 public client/native application。正式发布的应用必须选择“任何组织目录中的帐户和个人 Microsoft 帐户”，其 manifest `signInAudience` 为 `AzureADandPersonalMicrosoftAccount`，并使用 `ONEDRIVE_TENANT_ID=common`。仅组织目录或单租户注册会让个人 OneDrive 登录返回 `unauthorized_client`，不能作为本项目的发布配置。
2. 在 API permissions 中只添加委托权限 `Files.ReadWrite.AppFolder`。OIDC 的 `openid profile email offline_access` 用于登录身份和续期；不要添加 `Files.ReadWrite.All`、`User.ReadWrite.All` 或 `User.RevokeSessions.All`。按租户政策完成管理员同意和发布审核。
3. manifest 中把 `api.requestedAccessTokenVersion` 设为 `2`。当 `signInAudience` 包含个人 Microsoft 帐户时，Microsoft 要求访问令牌版本为 2。
4. Android/macOS 注册 redirect：`com.aaalice.nailauncher.oauth://oauth2redirect/microsoft`。Entra 自定义 redirect URI 必须使用 `customScheme://` 形式；Android 的 AppAuth receiver scheme 和 macOS `CFBundleURLTypes` 已登记，redirect define 必须逐字符一致。
5. Windows 在应用 manifest 的 `replyUrlsWithType` 中注册 `http://127.0.0.1/oauth2/callback`，类型为 `InstalledClient`；构建 define 仍填基值 `ONEDRIVE_WINDOWS_REDIRECT_URI=http://127.0.0.1`，运行时会追加随机端口和固定 `/oauth2/callback` 路径。Microsoft 官方说明 `127.0.0.1` 比 `localhost` 更不易受主机名/防火墙配置影响，但 Portal 的普通 Redirect URIs 文本框目前不能配置 HTTP IP loopback，必须编辑 manifest。参考 [Redirect URI 限制](https://learn.microsoft.com/en-us/entra/identity-platform/reply-url)。启用 public client flow，不创建 client secret。

Microsoft 没有适合本最小权限流程的单 token revoke 调用。断开只删除本地 secure-storage token，不申请或调用 `User.RevokeSessions.All`。如产品未来提供“退出浏览器中的 Microsoft 账号”，应作为明确可选操作打开 Microsoft logout endpoint；它会影响共享系统浏览器 SSO，不应与普通断开绑定。

## Dart defines

任何示例值都只是占位符，不能直接用于生产：

| 平台 | Google | OneDrive |
| --- | --- | --- |
| Android | `GOOGLE_DRIVE_ANDROID_CLIENT_ID` | `ONEDRIVE_ANDROID_CLIENT_ID`、`ONEDRIVE_ANDROID_REDIRECT_URI` |
| macOS | `GOOGLE_DRIVE_MACOS_CLIENT_ID`、`GOOGLE_DRIVE_MACOS_REDIRECT_URI` | `ONEDRIVE_MACOS_CLIENT_ID`、`ONEDRIVE_MACOS_REDIRECT_URI` |
| Windows | `GOOGLE_DRIVE_WINDOWS_CLIENT_ID`、`GOOGLE_DRIVE_WINDOWS_CLIENT_SECRET`、`GOOGLE_DRIVE_WINDOWS_REDIRECT_URI=http://127.0.0.1` | `ONEDRIVE_WINDOWS_CLIENT_ID`、`ONEDRIVE_WINDOWS_REDIRECT_URI=http://127.0.0.1` |
| 全平台 OneDrive | — | `ONEDRIVE_TENANT_ID=common` |

PowerShell 构建示例：

```powershell
flutter run -d windows `
  --dart-define=GOOGLE_DRIVE_WINDOWS_CLIENT_ID=<google-desktop-client-id> `
  --dart-define=GOOGLE_DRIVE_WINDOWS_CLIENT_SECRET=<google-desktop-client-secret> `
  --dart-define=GOOGLE_DRIVE_WINDOWS_REDIRECT_URI=http://127.0.0.1 `
  --dart-define=ONEDRIVE_WINDOWS_CLIENT_ID=<entra-public-client-id> `
  --dart-define=ONEDRIVE_WINDOWS_REDIRECT_URI=http://127.0.0.1 `
  --dart-define=ONEDRIVE_TENANT_ID=common
```

Android/macOS 用表中的平台键替换；OneDrive mobile redirect 使用上节固定 URI，Google macOS redirect 使用 reversed client ID URI。Android Google 不使用 redirect define。Release 构建也必须传同一组 define。Google Windows Desktop client secret 只存放在受保护的开发环境或 GitHub Actions secret 中；client ID/redirect URI 由 CI 环境管理，access/refresh token 绝不能作为 define。

## 配置诊断与验证

`CloudDriveOAuthConfig.fromDartDefines().diagnose(provider)` 返回 `isConfigured` 和明确 `reasons`，包括缺失键、错误平台、错误 loopback host/port、移动 scheme 错误。调用 `requireProvider` 时配置不完整会立即失败，而不是启动半配置授权。

```dart
final config = CloudDriveOAuthConfig.fromDartDefines();
for (final provider in CloudDriveOAuthProvider.values) {
  print(config.diagnose(provider)); // 仅输出配置状态，不输出 token
}
```

提交前运行；OAuth 注册环境可通过环境变量传值，脚本只输出配置状态，不输出 token：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify_cloud_drive_oauth_config.ps1 -Platform windows -RequireConfigured
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify_flutter_sources.ps1
flutter pub get --enforce-lockfile
flutter test test/core/cloud_sync/oauth/cloud_drive_oauth_test.dart test/core/storage/cloud_drive_oauth_secure_storage_test.dart
flutter analyze lib/core/cloud_sync/oauth lib/core/storage/secure_storage_service.dart lib/core/constants/storage_keys.dart
```

真机诊断还必须分别检查：Google Android debug/release SHA 是否登记；macOS 构建产物 `Info.plist` 是否出现实际 reversed client ID scheme；OneDrive redirect 是否逐字符匹配 Entra；Windows 浏览器是否回到随机 `127.0.0.1` 端口。

Release workflow 要求先设置 GitHub Actions repository variables：`GOOGLE_DRIVE_WINDOWS_CLIENT_ID`、`GOOGLE_DRIVE_MACOS_CLIENT_ID`、`GOOGLE_DRIVE_MACOS_REDIRECT_URI`、`GOOGLE_DRIVE_ANDROID_CLIENT_ID`、`ONEDRIVE_CLIENT_ID`、`ONEDRIVE_MACOS_REDIRECT_URI`、`ONEDRIVE_ANDROID_REDIRECT_URI`，以及 `ONEDRIVE_TENANT_ID=common`；Google Windows Desktop client secret 单独存入 repository secret `GOOGLE_DRIVE_WINDOWS_CLIENT_SECRET`。正式发布缺少任一平台必需值时会在构建前失败，避免发布一个静默缺失云盘登录能力的安装包。这些值来自外部 Google/Entra 应用注册与审核，不在仓库中提供真实值。

## 数据与账号隔离

- Google 只写隐藏 `appDataFolder`，OneDrive 只写 `/special/approot` 下的 `aaalice-sync`；两者都不会请求或扫描普通网盘文件。
- 两个 provider 复用同一套明文不可变 object/manifest + 小型 HEAD 协议和现有同步数据 allowlist，不创建 `KEY.json`，也不要求恢复密钥。
- 保存连接只验证并保存配置，不会自动上传、拉取或恢复待处理同步；所有数据传输都必须由用户点击对应操作触发。
- OAuth token、WebDAV/GitHub 凭据、设备配置、缓存、索引、队列和日志都不进入备份。断开账号会撤销（Google）或删除（Microsoft）OAuth session，但不会删除远端数据；“删除云端备份”始终使用独立高风险确认。

## 云同步并发语义

- OneDrive/Graph `driveItem` 提供 eTag/cTag，并在条件请求的 `If-Match` 不匹配时返回 `412 Precondition Failed`，可作为 CAS/乐观并发依据。参考 [`driveItem` resource](https://learn.microsoft.com/en-us/graph/api/resources/driveitem?view=graph-rest-1.0) 和 [`driveItem: delete`](https://learn.microsoft.com/en-us/graph/api/driveitem-delete?view=graph-rest-1.0) 的 `If-Match` 说明。
- Google Drive v3 的官方 `files.update` 文档没有为该写入路径承诺可依赖的强 `If-Match` CAS 语义。参考 [`files.update`](https://developers.google.com/drive/api/reference/rest/v3/files/update)。Google backend 不能把普通更新后的版本信息当成强 CAS 保证，因此显式降级为手动推送/手动拉取：允许用户确认后上传或只读拉取最新备份，但不启用自动双向合并，也不把历史恢复伪装成安全的条件写。

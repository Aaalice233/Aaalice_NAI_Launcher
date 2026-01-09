# 修复计划：双登录系统账号切换适配

## 问题描述

当选择**邮箱密码登录方式注册的账号**时，系统提示"Token 格式无效"，无法正常切换账号。

**根本原因**：Credentials 类型账号存储的是 JWT 格式的 accessToken，而 `switchAccount` 和 `loginWithToken` 方法强制检查 `pst-` 前缀格式。

---

## 解决方案

### 核心策略

| 账号类型 | Token 格式 | 验证方式 |
|----------|-----------|----------|
| Token | `pst-xxxx...` | `isValidTokenFormat()` 检查前缀 |
| Credentials | `eyJ...` (JWT) | 直接调用 `validateToken()` |

---

## 任务清单

### 阶段 1: 添加内部登录方法

- [ ] 1.1 在 `auth_provider.dart` 添加 `_loginWithAccessToken` 私有方法

### 阶段 2: 修改账号切换方法

- [ ] 2.1 修改 `switchAccount` 方法签名 - 添加 `required AccountType accountType` 参数
- [ ] 2.2 实现类型分发逻辑

### 阶段 3: 修改自动登录逻辑

- [ ] 3.1 修改 `_checkExistingAuth` 方法

### 阶段 4: 更新调用方

- [ ] 4.1 修改 `account_quick_switch.dart` - 传递 `account.accountType`
- [ ] 4.2 检查 `login_screen.dart` 是否有其他调用方

### 阶段 5: 验证与测试

- [ ] 5.1 运行 flutter analyze 确保零错误
- [ ] 5.2 测试所有场景

---

## 关键代码修改

### 任务 1.1: 添加 `_loginWithAccessToken` 方法

**文件**: `lib/presentation/providers/auth_provider.dart`
**位置**: 在 `loginWithCredentials` 方法之后

```dart
Future<bool> _loginWithAccessToken(
  String accessToken, {
  String? accountId,
  String? displayName,
}) async {
  state = state.copyWith(status: AuthStatus.loading);
  
  try {
    final apiService = ref.read(naiApiServiceProvider);
    final storage = ref.read(secureStorageServiceProvider);
    
    AppLogger.auth('Validating access token for credentials account...');
    final subscriptionInfo = await apiService.validateToken(accessToken);
    AppLogger.auth('Access token validation successful');
    
    await storage.saveAuth(
      accessToken: accessToken,
      expiry: DateTime.now().add(const Duration(days: 30)),
      email: displayName ?? '',
    );
    
    state = AuthState(
      status: AuthStatus.authenticated,
      accountId: accountId,
      displayName: displayName,
      subscriptionInfo: subscriptionInfo,
    );
    
    return true;
  } catch (e) {
    AppLogger.e('Credentials account login failed: $e');
    final (errorCode, httpStatusCode) = AuthState.parseError(e);
    state = AuthState(
      status: AuthStatus.error,
      errorCode: errorCode,
      httpStatusCode: httpStatusCode,
    );
    return false;
  }
}
```

### 任务 2.1-2.2: 修改 `switchAccount` 方法

**文件**: `lib/presentation/providers/auth_provider.dart`
**位置**: 约第315行

```dart
Future<bool> switchAccount(
  String accountId,
  String token, {
  String? displayName,
  required AccountType accountType,
}) async {
  AppLogger.auth('Switching account: $displayName (type: $accountType)');
  
  if (accountType == AccountType.credentials) {
    return _loginWithAccessToken(
      token,
      accountId: accountId,
      displayName: displayName,
    );
  } else {
    return loginWithToken(
      token,
      accountId: accountId,
      displayName: displayName,
    );
  }
}
```

### 任务 3.1: 修改 `_checkExistingAuth`

**文件**: `lib/presentation/providers/auth_provider.dart`
**位置**: 约第200行

获取账号类型后，根据类型选择验证方式：
- `AccountType.credentials` → 直接 `validateToken`
- `AccountType.token` → 先 `isValidTokenFormat` 再 `validateToken`

### 任务 4.1: 修改 `account_quick_switch.dart`

**文件**: `lib/presentation/widgets/auth/account_quick_switch.dart`
**位置**: 约第42行

```dart
await ref.read(authNotifierProvider.notifier).switchAccount(
  account.id,
  token,
  displayName: account.displayName,
  accountType: account.accountType,  // 添加这行
);
```

---

## 验证测试

| 用例 | 预期结果 |
|------|----------|
| Token 账号切换 | 正常登录 |
| Credentials 账号切换 | 正常登录，无"Token 格式无效"错误 |
| 混合切换 | 两种类型都能正常切换 |
| 自动登录 | 根据账号类型正确自动登录 |

---

## 依赖关系

任务 1.1 → 任务 2.1-2.2 → 任务 3.1 → 任务 4.1-4.2 → 任务 5

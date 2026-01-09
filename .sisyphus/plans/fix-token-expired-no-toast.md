# 修复 Token 过期登录无提示问题

## 问题描述

用户在 token 过期后点击登录，没有任何提示就自动跳转到登录页，用户体验不好。

## 问题根因

当 token 验证失败（401）时：

1. AuthInterceptor 捕获 401 → 调用 logout() → 状态变 unauthenticated
2. loginWithToken() catch 块 → 状态变 error (errorCode: authFailed)
3. 同时 GoRouter 守卫检测到 unauthenticated → 立即重定向到 /login
4. 登录页面刚开始构建，ref.listen 还没注册
5. clearError() 被调用 → 状态又变回 unauthenticated
6. 结果：Toast 根本没机会显示

## 修复方案

在 loginWithToken() 的 catch 块中直接显示 Toast，不依赖 ref.listen。

## 任务清单

### 任务1：修改 auth_provider.dart

- [ ] 添加 _getErrorText 辅助方法
- [ ] 在 loginWithToken() catch 块中添加 Toast 显示逻辑
- [ ] 使用 ref.context 获取 BuildContext

### 任务2：更新国际化文件

- [ ] 确认 app_zh.arb 已有 api_error_401_hint
- [ ] 确认 app_en.arb 已有对应英文

### 任务3：验证

- [ ] 运行 flutter analyze
- [ ] 测试编译

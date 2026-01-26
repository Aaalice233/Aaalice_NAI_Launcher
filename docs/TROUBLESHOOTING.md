# 故障排除指南 | Troubleshooting Guide

**Last Updated:** 2026-01-26
**Version:** 1.0.0

---

## 目录 | Table of Contents

1. [安装与构建问题 | Installation & Build Issues](#安装与构建问题--installation--build-issues)
2. [运行时错误 | Runtime Errors](#运行时错误--runtime-errors)
3. [API 与网络问题 | API & Network Issues](#api-与网络问题--api--network-issues)
4. [功能特定问题 | Feature-Specific Issues](#功能特定问题--feature-specific-issues)
5. [性能问题 | Performance Issues](#性能问题--performance-issues)
6. [开发环境问题 | Development Environment Issues](#开发环境问题--development-environment-issues)
7. [常见错误代码 | Common Error Codes](#常见错误代码--common-error-codes)

---

## 安装与构建问题 | Installation & Build Issues

### Flutter 版本不兼容 | Flutter Version Incompatible

#### 中文 | Chinese

**问题描述：**
运行 `flutter run` 或 `flutter build` 时出现版本不兼容错误。

**解决方案：**
```bash
# 检查当前 Flutter 版本
flutter --version

# 如果版本低于 3.16，升级 Flutter
flutter upgrade

# 清理并重新获取依赖
flutter clean
flutter pub get
```

#### English

**Problem:**
Version incompatibility error when running `flutter run` or `flutter build`.

**Solution:**
```bash
# Check current Flutter version
flutter --version

# If version is below 3.16, upgrade Flutter
flutter upgrade

# Clean and reinstall dependencies
flutter clean
flutter pub get
```

---

### 依赖解析失败 | Dependency Resolution Failed

#### 中文 | Chinese

**问题描述：**
`flutter pub get` 失败，显示依赖冲突。

**解决方案：**
```bash
# 清理 pub 缓存
flutter pub cache repair

# 删除 pubspec.lock 文件
rm pubspec.lock

# 重新获取依赖
flutter pub get

# 如果仍然失败，尝试升级依赖
flutter pub upgrade
```

#### English

**Problem:**
`flutter pub get` fails with dependency conflicts.

**Solution:**
```bash
# Clean pub cache
flutter pub cache repair

# Remove pubspec.lock file
rm pubspec.lock

# Re-fetch dependencies
flutter pub get

# If still failing, try upgrading dependencies
flutter pub upgrade
```

---

### 代码生成失败 | Code Generation Failed

#### 中文 | Chinese

**问题描述：**
`build_runner` 生成代码失败或生成的代码不完整。

**常见错误：**
- `Could not resolve package`
- `Freezed` 或 `JsonSerializable` 注解不工作

**解决方案：**
```bash
# 清理之前的生成
dart run build_runner clean

# 删除生成冲突
dart run build_runner build --delete-conflicting-outputs

# 如果仍然失败，完全重新生成
dart run build_runner build --delete-conflicting-outputs --build-filter="**/*.dart"
```

**检查清单：**
- [ ] 确保所有模型类都有 `@freezed` 或 `@JsonSerializable` 注解
- [ ] 检查 `part` 语句是否正确（如 `part 'model.freezed.dart'`）
- [ ] 确保导入的包版本兼容

#### English

**Problem:**
`build_runner` code generation fails or generates incomplete code.

**Common Errors:**
- `Could not resolve package`
- `Freezed` or `JsonSerializable` annotations not working

**Solution:**
```bash
# Clean previous generation
dart run build_runner clean

# Delete conflicting outputs
dart run build_runner build --delete-conflicting-outputs

# If still failing, completely regenerate
dart run build_runner build --delete-conflicting-outputs --build-filter="**/*.dart"
```

**Checklist:**
- [ ] Ensure all model classes have `@freezed` or `@JsonSerializable` annotations
- [ ] Check that `part` statements are correct (e.g., `part 'model.freezed.dart'`)
- [ ] Ensure imported package versions are compatible

---

### Windows 构建失败 | Windows Build Failed

#### 中文 | Chinese

**问题描述：**
`flutter build windows` 失败，提示缺少 Visual Studio 或 C++ 构建工具。

**解决方案：**
```bash
# 检查 Windows 桌面开发环境
flutter doctor

# 如果显示 "Visual Studio - not installed":
# 1. 下载 Visual Studio 2019 或更新版本
# 2. 安装时选择 "Desktop development with C++" 工作负载
# 3. 包含 Windows 10/11 SDK

# 重新运行
flutter build windows --release
```

#### English

**Problem:**
`flutter build windows` fails with missing Visual Studio or C++ build tools.

**Solution:**
```bash
# Check Windows desktop development environment
flutter doctor

# If shows "Visual Studio - not installed":
# 1. Download Visual Studio 2019 or later
# 2. Install "Desktop development with C++" workload
# 3. Include Windows 10/11 SDK

# Re-run
flutter build windows --release
```

---

## 运行时错误 | Runtime Errors

### 图标显示为色块 | Icons Render as Color Blocks

#### 中文 | Chinese

**问题描述：**
Material Icons 显示为纯色方块，而不是图标图形。

**原因：**
图标颜色与背景色相同或对比度不足。

**解决方案：**

**1. 检查主题配置：**
```dart
// 确保主题中设置了 iconTheme
ThemeData(
  iconTheme: IconThemeData(
    color: colorScheme.onPrimary, // 高对比度颜色
  ),
)
```

**2. 使用显式颜色：**
```dart
// ❌ 错误：可能对比度不足
Icon(Icons.star, color: theme.colorScheme.primary)

// ✅ 正确：使用高对比度颜色
Icon(Icons.star, color: theme.colorScheme.onPrimary)
```

**3. 检查父容器的颜色继承：**
```dart
IconTheme(
  data: IconThemeData(
    color: theme.colorScheme.onSurface,
  ),
  child: Icon(Icons.add),
)
```

#### English

**Problem:**
Material Icons render as solid color blocks instead of icon graphics.

**Cause:**
Icon color matches or has insufficient contrast with background color.

**Solution:**

**1. Check theme configuration:**
```dart
// Ensure iconTheme is set in theme
ThemeData(
  iconTheme: IconThemeData(
    color: colorScheme.onPrimary, // High contrast color
  ),
)
```

**2. Use explicit colors:**
```dart
// ❌ Wrong: May have insufficient contrast
Icon(Icons.star, color: theme.colorScheme.primary)

// ✅ Correct: Use high contrast color
Icon(Icons.star, color: theme.colorScheme.onPrimary)
```

**3. Check parent container color inheritance:**
```dart
IconTheme(
  data: IconThemeData(
    color: theme.colorScheme.onSurface,
  ),
  child: Icon(Icons.add),
)
```

---

### Hive 存储初始化失败 | Hive Storage Initialization Failed

#### 中文 | Chinese

**问题描述：**
应用启动时出现 Hive 初始化错误，无法加载收藏或模板。

**错误示例：**
```
HiveError: Box not found. Did you forget to call Hive.openBox()?
```

**解决方案：**

**1. 检查初始化顺序：**
```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive
  await Hive.initFlutter();

  // 注册适配器（如果有自定义类型）
  Hive.registerAdapter(TagFavoriteAdapter());
  Hive.registerAdapter(TagTemplateAdapter());

  // 打开所需的 box
  await Hive.openBox<TagFavorite>('tag_favorites');
  await Hive.openBox<TagTemplate>('tag_templates');

  runApp(const MyApp());
}
```

**2. 检查存储路径权限：**
- Android: 确保应用有存储权限
- Windows: 检查应用目录是否可写
- Linux: 检查用户目录权限

**3. 清除损坏的存储：**
```dart
// 如果存储损坏，删除并重建
await Hive.deleteBoxFromDisk('tag_favorites');
await Hive.deleteBoxFromDisk('tag_templates');
// 重启应用重新创建
```

#### English

**Problem:**
Hive initialization error on app startup, unable to load favorites or templates.

**Error Example:**
```
HiveError: Box not found. Did you forget to call Hive.openBox()?
```

**Solution:**

**1. Check initialization order:**
```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register adapters (if using custom types)
  Hive.registerAdapter(TagFavoriteAdapter());
  Hive.registerAdapter(TagTemplateAdapter());

  // Open required boxes
  await Hive.openBox<TagFavorite>('tag_favorites');
  await Hive.openBox<TagTemplate>('tag_templates');

  runApp(const MyApp());
}
```

**2. Check storage path permissions:**
- Android: Ensure app has storage permissions
- Windows: Check if app directory is writable
- Linux: Check user directory permissions

**3. Clear corrupted storage:**
```dart
// If storage is corrupted, delete and recreate
await Hive.deleteBoxFromDisk('tag_favorites');
await Hive.deleteBoxFromDisk('tag_templates');
// Restart app to recreate
```

---

### 热重载失败 | Hot Reload Failed

#### 中文 | Chinese

**问题描述：**
修改代码后 `flutter run` 的热重载失败，需要完全重启。

**解决方案：**

**1. 尝试热重启：**
```bash
# 在运行的终端中按
r  # 热重启
R  # 完全重启
```

**2. 如果仍然失败，检查：**
- 是否修改了 `main.dart` 或全局初始化代码
- 是否添加了新的依赖（需要 `flutter pub get`）
- 是否修改了枚举或常量定义

**3. 完全重新运行：**
```bash
# 停止当前运行（按 Ctrl+C）
flutter clean
flutter pub get
flutter run
```

#### English

**Problem:**
Hot reload fails after code changes during `flutter run`, requiring full restart.

**Solution:**

**1. Try hot restart:**
```bash
# In running terminal press
r  # Hot restart
R  # Full restart
```

**2. If still failing, check:**
- Did you modify `main.dart` or global initialization code
- Did you add new dependencies (need `flutter pub get`)
- Did you modify enum or constant definitions

**3. Completely re-run:**
```bash
# Stop current run (press Ctrl+C)
flutter clean
flutter pub get
flutter run
```

---

## API 与网络问题 | API & Network Issues

### API 认证失败 | API Authentication Failed

#### 中文 | Chinese

**问题描述：**
调用 NovelAI API 时返回 401 或 403 错误。

**错误示例：**
```
HTTP 401: Unauthorized
HTTP 403: Forbidden
```

**解决方案：**

**1. 检查 API Token：**
- 确保在设置中输入了正确的 NovelAI API Token
- Token 是否过期（登录 NovelAI 网站重新获取）
- 检查 Token 前后是否有空格

**2. 验证网络连接：**
```bash
# 测试是否能访问 NovelAI
curl -I https://api.novelai.net
```

**3. 检查请求头：**
```dart
// 确保请求头包含正确的认证信息
headers: {
  'Authorization': 'Bearer $yourToken',
  'Content-Type': 'application/json',
}
```

#### English

**Problem:**
Calling NovelAI API returns 401 or 403 error.

**Error Example:**
```
HTTP 401: Unauthorized
HTTP 403: Forbidden
```

**Solution:**

**1. Check API Token:**
- Ensure correct NovelAI API Token is entered in settings
- Token might be expired (re-login to NovelAI website to get new token)
- Check for extra spaces before or after token

**2. Verify network connection:**
```bash
# Test if NovelAI is accessible
curl -I https://api.novelai.net
```

**3. Check request headers:**
```dart
// Ensure request headers contain correct authentication
headers: {
  'Authorization': 'Bearer $yourToken',
  'Content-Type': 'application/json',
}
```

---

### 网络超时 | Network Timeout

#### 中文 | Chinese

**问题描述：**
图像生成请求超时或长时间无响应。

**解决方案：**

**1. 增加超时时间：**
```dart
final client = http.Client();
try {
  final response = await client.post(
    Uri.parse('https://api.novelai.net/ai/generate-image'),
    headers: headers,
    body: body,
  ).timeout(
    const Duration(seconds: 120), // 增加到 120 秒
  );
} catch (e) {
  // 处理超时
}
```

**2. 检查网络稳定性：**
- 切换到更稳定的网络（如以太网）
- 检查防火墙是否阻止了请求
- 尝试使用 VPN（如果在受限地区）

**3. 减少并发请求：**
- 避免同时生成多个图像
- 降低图像分辨率或步数

#### English

**Problem:**
Image generation request times out or has no response for a long time.

**Solution:**

**1. Increase timeout duration:**
```dart
final client = http.Client();
try {
  final response = await client.post(
    Uri.parse('https://api.novelai.net/ai/generate-image'),
    headers: headers,
    body: body,
  ).timeout(
    const Duration(seconds: 120), // Increase to 120 seconds
  );
} catch (e) {
  // Handle timeout
}
```

**2. Check network stability:**
- Switch to more stable network (e.g., Ethernet)
- Check if firewall is blocking requests
- Try using VPN (if in restricted region)

**3. Reduce concurrent requests:**
- Avoid generating multiple images simultaneously
- Lower image resolution or step count

---

## 功能特定问题 | Feature-Specific Issues

### 标签模式切换缓慢 | Tag Mode Switching Slow

#### 中文 | Chinese

**问题描述：**
从文本模式切换到标签模式需要超过 100ms，感觉卡顿。

**解决方案：**

**1. 检查缓存是否启用：**
```dart
// 确保启用了解析缓存
bool _parseTextToTags(String text) {
  // 检查缓存
  if (_lastParsedText == text) {
    return false; // 无需重新解析
  }
  // ... 解析逻辑
}
```

**2. 减少标签数量：**
- 避免在单个提示词中使用过多标签
- 使用标签模板批量管理

**3. 优化性能：**
```bash
# 运行性能分析
flutter run --profile

# 使用 Flutter DevTools 分析性能瓶颈
flutter pub global activate devtools
flutter pub global run devtools
```

#### English

**Problem:**
Switching from text mode to tag mode takes more than 100ms, feels laggy.

**Solution:**

**1. Check if caching is enabled:**
```dart
// Ensure parsing cache is enabled
bool _parseTextToTags(String text) {
  // Check cache
  if (_lastParsedText == text) {
    return false; // No need to re-parse
  }
  // ... parsing logic
}
```

**2. Reduce tag count:**
- Avoid using too many tags in a single prompt
- Use tag templates for batch management

**3. Optimize performance:**
```bash
# Run performance profiling
flutter run --profile

# Use Flutter DevTools to analyze performance bottlenecks
flutter pub global activate devtools
flutter pub global run devtools
```

---

### 画布模式卡顿 | Canvas Mode Lagging

#### 中文 | Chinese

**问题描述：**
在图像到图像（Img2Img）画布模式下操作时卡顿或延迟。

**解决方案：**

**1. 降低画布分辨率：**
- 在设置中选择较低的画布分辨率
- 避免使用超高分辨率输入图像

**2. 关闭不必要的视觉效果：**
- 减少阴影和模糊效果
- 禁用动画（在辅助功能设置中）

**3. 检查内存使用：**
```dart
// 监控内存使用
import 'dart:developer';

void logMemoryUsage() {
  final info = VMInfo.getCurrentMemoryInfo();
  developer.log('Memory usage: ${info.heapUsage}');
}
```

#### English

**Problem:**
Lag or delay when operating in image-to-image (Img2Img) canvas mode.

**Solution:**

**1. Lower canvas resolution:**
- Choose lower canvas resolution in settings
- Avoid using ultra-high resolution input images

**2. Disable unnecessary visual effects:**
- Reduce shadows and blur effects
- Disable animations (in accessibility settings)

**3. Check memory usage:**
```dart
// Monitor memory usage
import 'dart:developer';

void logMemoryUsage() {
  final info = VMInfo.getCurrentMemoryInfo();
  developer.log('Memory usage: ${info.heapUsage}');
}
```

---

### 多字符规则不工作 | Multi-Character Rules Not Working

#### 中文 | Chinese

**问题描述：**
在使用 V4 模型的多字符提示词时，输出不符合预期。

**解决方案：**

**1. 检查模型类型：**
- 确保使用的是支持 `characterPrompts` 的模型（如 NAI Diffusion V4）
- 其他模型使用单字符规则

**2. 验证提示词格式：**
```dart
// V4 模型多字符格式正确
[
  {
    "name": "character1",
    "prompt": "description1"
  },
  {
    "name": "character2",
    "prompt": "description2"
  }
]

// ❌ 错误：在非 V4 模型中使用多字符
// ✅ 正确：V3 使用简单字符串
"character1: description1, character2: description2"
```

**3. 参考 NAI 官方规则：**
- 查看 `docs/NAI_Multi_Character_Rules.md` 了解详细规则
- 测试简单示例验证行为

#### English

**Problem:**
Multi-character prompts in V4 model don't produce expected output.

**Solution:**

**1. Check model type:**
- Ensure using a model that supports `characterPrompts` (e.g., NAI Diffusion V4)
- Other models use single-character rules

**2. Verify prompt format:**
```dart
// V4 model multi-character format correct
[
  {
    "name": "character1",
    "prompt": "description1"
  },
  {
    "name": "character2",
    "prompt": "description2"
  }
]

// ❌ Wrong: Using multi-character in non-V4 model
// ✅ Correct: V3 uses simple string
"character1: description1, character2: description2"
```

**3. Reference NAI official rules:**
- See `docs/NAI_Multi_Character_Rules.md` for detailed rules
- Test simple examples to verify behavior

---

## 性能问题 | Performance Issues

### 应用启动缓慢 | App Startup Slow

#### 中文 | Chinese

**问题描述：**
应用从启动到可用状态需要超过 3 秒。

**解决方案：**

**1. 使用延迟初始化：**
```dart
// 延迟加载非关键资源
Future<void> initLazyResources() async {
  await Future.delayed(const Duration(seconds: 1));
  // 初始化非关键功能
}
```

**2. 优化 Hive 初始化：**
```dart
// 只打开需要的 box
await Hive.openBox<TagFavorite>('tag_favorites');
// 延迟打开其他 box
```

**3. 减少初始化工作：**
- 移除不必要的同步操作
- 使用异步加载替代同步加载

#### English

**Problem:**
App takes more than 3 seconds from launch to usable state.

**Solution:**

**1. Use deferred initialization:**
```dart
// Lazy load non-critical resources
Future<void> initLazyResources() async {
  await Future.delayed(const Duration(seconds: 1));
  // Initialize non-critical features
}
```

**2. Optimize Hive initialization:**
```dart
// Only open needed boxes
await Hive.openBox<TagFavorite>('tag_favorites');
// Defer opening other boxes
```

**3. Reduce initialization work:**
- Remove unnecessary synchronous operations
- Use asynchronous loading instead of synchronous

---

### 内存占用过高 | High Memory Usage

#### 中文 | Chinese

**问题描述：**
应用内存占用持续增长或超过 500MB。

**解决方案：**

**1. 清理未使用的资源：**
```dart
@override
void dispose() {
  // 清理控制器
  _tabController.dispose();
  _scrollController.dispose();

  // 清理流订阅
  _subscription.cancel();

  super.dispose();
}
```

**2. 优化图像缓存：**
```dart
// 限制缓存大小
final imageCache = PaintingBinding.instance.imageCache;
imageCache.maximumSize = 50; // 限制缓存 50 张图片
imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB
```

**3. 使用 `const` 构造函数：**
```dart
// ✅ 更好的内存效率
const Text('Hello');

// ❌ 每次都创建新实例
Text('Hello');
```

#### English

**Problem:**
App memory usage continuously grows or exceeds 500MB.

**Solution:**

**1. Clean up unused resources:**
```dart
@override
void dispose() {
  // Clean up controllers
  _tabController.dispose();
  _scrollController.dispose();

  // Clean up stream subscriptions
  _subscription.cancel();

  super.dispose();
}
```

**2. Optimize image caching:**
```dart
// Limit cache size
final imageCache = PaintingBinding.instance.imageCache;
imageCache.maximumSize = 50; // Limit to 50 images
imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB
```

**3. Use `const` constructors:**
```dart
// ✅ Better memory efficiency
const Text('Hello');

// ❌ Creates new instance every time
Text('Hello');
```

---

## 开发环境问题 | Development Environment Issues

### 测试失败 | Tests Failing

#### 中文 | Chinese

**问题描述：**
运行 `flutter test` 时测试失败。

**解决方案：**

**1. 检查测试环境：**
```bash
# 确保所有依赖已安装
flutter pub get

# 重新生成测试代码
dart run build_runner build --delete-conflicting-outputs
```

**2. 运行特定测试：**
```bash
# 运行单个测试文件
flutter test test/widget/tag_view_test.dart

# 运行特定测试组
flutter test --name="TagFavorite"
```

**3. 查看详细错误：**
```bash
# 运行测试并显示详细输出
flutter test --verbose

# 运行测试并生成覆盖率报告
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

#### English

**Problem:**
Tests fail when running `flutter test`.

**Solution:**

**1. Check test environment:**
```bash
# Ensure all dependencies are installed
flutter pub get

# Regenerate test code
dart run build_runner build --delete-conflicting-outputs
```

**2. Run specific tests:**
```bash
# Run single test file
flutter test test/widget/tag_view_test.dart

# Run specific test group
flutter test --name="TagFavorite"
```

**3. View detailed errors:**
```bash
# Run tests with verbose output
flutter test --verbose

# Run tests and generate coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

---

### 代码格式不一致 | Code Format Inconsistent

#### 中文 | Chinese

**问题描述：**
代码风格不一致，导致 `flutter analyze` 有大量警告。

**解决方案：**

**1. 运行格式化工具：**
```bash
# 格式化所有代码
dart format .

# 格式化特定文件
dart format lib/models/tag_favorite.dart
```

**2. 修复 lint 警告：**
```bash
# 自动修复可修复的问题
dart fix --apply

# 查看所有问题
flutter analyze
```

**3. 配置编辑器：**
- VS Code: 安装 Flutter 扩展，启用 "Format on Save"
- Android Studio/IntelliJ: 启用 "Reformat on Save"

#### English

**Problem:**
Inconsistent code style causing many `flutter analyze` warnings.

**Solution:**

**1. Run formatting tools:**
```bash
# Format all code
dart format .

# Format specific file
dart format lib/models/tag_favorite.dart
```

**2. Fix lint warnings:**
```bash
# Auto-fix fixable issues
dart fix --apply

# View all issues
flutter analyze
```

**3. Configure editor:**
- VS Code: Install Flutter extension, enable "Format on Save"
- Android Studio/IntelliJ: Enable "Reformat on Save"

---

## 常见错误代码 | Common Error Codes

### HTTP 状态码 | HTTP Status Codes

| 状态码 | 含义 | 可能原因 | 解决方案 |
|-------|------|---------|---------|
| 400 | Bad Request | 请求参数错误 | 检查请求体格式和参数 |
| 401 | Unauthorized | 认证失败 | 检查 API Token 是否正确 |
| 403 | Forbidden | 权限不足 | 确认账户有 API 访问权限 |
| 404 | Not Found | 资源不存在 | 检查 API 端点 URL |
| 429 | Too Many Requests | 请求过于频繁 | 减少请求频率，等待一段时间 |
| 500 | Internal Server Error | 服务器错误 | 稍后重试，或联系 NovelAI 支持 |
| 502 | Bad Gateway | 网关错误 | 稍后重试 |
| 503 | Service Unavailable | 服务不可用 | 稍后重试，可能正在维护 |

### Dart 异常 | Dart Exceptions

| 异常类型 | 含义 | 常见原因 | 解决方案 |
|---------|------|---------|---------|
| `FormatException` | 格式错误 | JSON 解析失败 | 检查响应数据格式 |
| `NullPointerException` | 空指针 | 访问空对象 | 添加空值检查 |
| `StateError` | 状态错误 | 在错误状态使用方法 | 检查对象生命周期 |
| `RangeError` | 范围错误 | 数组越界 | 检查索引值 |
| `HiveError` | Hive 错误 | 存储初始化失败 | 检查 Hive 初始化代码 |

---

## 获取更多帮助 | Getting More Help

### 中文 | Chinese

如果以上解决方案无法解决您的问题：

1. **查看文档：**
   - [README.md](../README.md) - 项目概述和快速开始
   - [CONTRIBUTING.md](../CONTRIBUTING.md) - 贡献指南
   - [docs/](./) - 更多技术文档

2. **搜索已知问题：**
   - 查看 [GitHub Issues](https://github.com/your-username/nai-launcher/issues)
   - 使用关键词搜索类似问题

3. **提交新问题：**
   - 在 GitHub 创建新 Issue
   - 包含详细的错误信息和重现步骤
   - 提供系统信息（操作系统、Flutter 版本等）

4. **加入社区：**
   - 加入讨论组获取实时帮助
   - 分享您的使用经验

### English

If the above solutions don't solve your problem:

1. **Check documentation:**
   - [README.md](../README.md) - Project overview and quick start
   - [CONTRIBUTING.md](../CONTRIBUTING.md) - Contribution guide
   - [docs/](./) - More technical documentation

2. **Search known issues:**
   - Check [GitHub Issues](https://github.com/your-username/nai-launcher/issues)
   - Use keywords to search for similar problems

3. **Submit a new issue:**
   - Create a new Issue on GitHub
   - Include detailed error information and reproduction steps
   - Provide system information (OS, Flutter version, etc.)

4. **Join the community:**
   - Join discussion groups for real-time help
   - Share your experience

---

**文档版本：** 1.0.0
**最后更新：** 2026-01-26
**维护者：** NAI Launcher Team

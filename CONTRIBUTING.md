# 贡献指南 | Contributing Guidelines

**感谢您对 NAI Launcher 的关注！我们欢迎并感谢任何形式的贡献。**

**Thank you for your interest in NAI Launcher! We welcome and appreciate any form of contribution.**

---

## 目录 | Table of Contents

- [行为准则 | Code of Conduct](#行为准则--code-of-conduct)
- [开发环境设置 | Development Setup](#开发环境设置--development-setup)
- [代码规范 | Coding Standards](#代码规范--coding-standards)
- [提交信息规范 | Commit Message Guidelines](#提交信息规范--commit-message-guidelines)
- [Pull Request 流程 | Pull Request Process](#pull-request-流程--pull-request-process)
- [测试要求 | Testing Requirements](#测试要求--testing-requirements)
- [添加翻译 | Adding Translations](#添加翻译--adding-translations)
- [报告问题 | Reporting Issues](#报告问题--reporting-issues)

---

## 行为准则 | Code of Conduct

### 中文 | Chinese

- 尊重所有贡献者
- 建设性反馈和讨论
- 专注于对项目最有利的事情
- 对不同观点保持开放态度

### English

- Respect all contributors
- Provide constructive feedback and discussions
- Focus on what is best for the project
- Be open to different viewpoints

---

## 开发环境设置 | Development Setup

### 中文 | Chinese

#### 环境要求 | Requirements

- **Flutter SDK:** 3.16 或更高版本
- **Dart SDK:** 3.2 或更高版本
- **Git:** 最新版本
- **IDE:** VS Code / Android Studio / IntelliJ IDEA (推荐使用 VS Code)

#### 安装步骤 | Installation Steps

1. **Fork 并克隆仓库**

```bash
# Fork 仓库到您的 GitHub 账户
# 然后克隆您的 fork
git clone https://github.com/YOUR_USERNAME/nai-launcher.git
cd nai-launcher

# 添加上游仓库
git remote add upstream https://github.com/original-owner/nai-launcher.git
```

2. **安装依赖**

```bash
# 获取 Flutter 依赖
flutter pub get

# 生成代码 (Freezed, Riverpod, etc.)
dart run build_runner build --delete-conflicting-outputs
```

3. **验证安装**

```bash
# 运行所有测试
flutter test

# 检查代码格式
flutter analyze

# 运行应用
flutter run
```

4. **创建功能分支**

```bash
# 从 main 分支创建新分支
git checkout -b feature/your-feature-name

# 或修复 bug
git checkout -b fix/bug-description
```

### English

#### Requirements

- **Flutter SDK:** 3.16 or higher
- **Dart SDK:** 3.2 or higher
- **Git:** Latest version
- **IDE:** VS Code / Android Studio / IntelliJ IDEA (VS Code recommended)

#### Installation Steps

1. **Fork and Clone Repository**

```bash
# Fork the repository to your GitHub account
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/nai-launcher.git
cd nai-launcher

# Add upstream repository
git remote add upstream https://github.com/original-owner/nai-launcher.git
```

2. **Install Dependencies**

```bash
# Get Flutter dependencies
flutter pub get

# Generate code (Freezed, Riverpod, etc.)
dart run build_runner build --delete-conflicting-outputs
```

3. **Verify Installation**

```bash
# Run all tests
flutter test

# Check code formatting
flutter analyze

# Run the application
flutter run
```

4. **Create Feature Branch**

```bash
# Create new branch from main
git checkout -b feature/your-feature-name

# Or fix a bug
git checkout -b fix/bug-description
```

---

## 代码规范 | Coding Standards

### 中文 | Chinese

#### Dart/Flutter 规范 | Dart/Flutter Conventions

我们遵循 Flutter 官方风格指南，并在 `analysis_options.yaml` 中配置了以下规则：

We follow the official Flutter style guide with additional rules configured in `analysis_options.yaml`:

**核心规则 | Core Rules:**

```yaml
# 必须规则 | Mandatory Rules
prefer_const_constructors: true      # 优先使用 const 构造函数
prefer_const_declarations: true      # 优先使用 const 声明
prefer_final_fields: true            # 字段优先使用 final
prefer_final_locals: true            # 局部变量优先使用 final
require_trailing_commas: true        # 要求尾随逗号
```

**代码示例 | Code Examples:**

```dart
// ✅ 好的做法 | Good Practice
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    const title = 'NAI Launcher';
    final count = ref.watch(countProvider);

    return Container(
      child: Text(title),
    );
  }
}

// ❌ 避免 | Avoid
class MyWidget extends StatelessWidget {
  // Missing const constructor
  @override
  Widget build(BuildContext context) {
    var title = 'NAI Launcher'; // Should be const
    // Missing trailing comma
    return Container(child: Text(title));
  }
}
```

#### 文件组织 | File Organization

```
lib/
├── core/              # 核心功能和基础设施 | Core functionality & infrastructure
│   ├── constants/     # 常量定义 | Constants
│   ├── utils/         # 工具类 | Utility classes
│   └── theme/         # 主题配置 | Theme configuration
├── data/              # 数据层 | Data layer
│   ├── models/        # 数据模型 | Data models
│   ├── repositories/  # 仓库实现 | Repository implementations
│   └── services/      # 外部服务 | External services
├── domain/            # 领域层 | Domain layer
│   └── entities/      # 领域实体 | Domain entities
├── presentation/      # 展示层 | Presentation layer
│   ├── pages/         # 页面 | Pages
│   ├── widgets/       # 通用组件 | Reusable widgets
│   └── providers/     # Riverpod providers | State management
└── l10n/              # 国际化文件 | Internationalization files
```

#### 命名约定 | Naming Conventions

```dart
// 类名使用大驼峰 | UpperCamelCase for classes
class ImageGenerator {}

// 变量和方法使用小驼峰 | lowerCamelCase for variables and methods
final imageCount = 0;
void generateImage() {}

// 常量使用小驼峰 | lowerCamelCase for constants
const maxImageSize = 1024;

// 私有成员前缀下划线 | Underscore prefix for private members
void _privateMethod() {}

// Provider 命名 | Provider naming
final imageProvider = Provider<Image>((ref) => Image());
final imageListProvider = StateProvider<List<Image>>((ref) => []);
```

### English

#### Dart/Flutter Conventions

We follow the official Flutter style guide with additional rules configured in `analysis_options.yaml`:

**Core Rules:**

```yaml
# Mandatory Rules
prefer_const_constructors: true      # Prefer const constructors
prefer_const_declarations: true      # Prefer const declarations
prefer_final_fields: true            # Prefer final for fields
prefer_final_locals: true            # Prefer final for locals
require_trailing_commas: true        # Require trailing commas
```

**Code Examples:**

```dart
// ✅ Good Practice
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    const title = 'NAI Launcher';
    final count = ref.watch(countProvider);

    return Container(
      child: Text(title),
    );
  }
}

// ❌ Avoid
class MyWidget extends StatelessWidget {
  // Missing const constructor
  @override
  Widget build(BuildContext context) {
    var title = 'NAI Launcher'; // Should be const
    // Missing trailing comma
    return Container(child: Text(title));
  }
}
```

#### File Organization

```
lib/
├── core/              # Core functionality & infrastructure
│   ├── constants/     # Constants
│   ├── utils/         # Utility classes
│   └── theme/         # Theme configuration
├── data/              # Data layer
│   ├── models/        # Data models
│   ├── repositories/  # Repository implementations
│   └── services/      # External services
├── domain/            # Domain layer
│   └── entities/      # Domain entities
├── presentation/      # Presentation layer
│   ├── pages/         # Pages
│   ├── widgets/       # Reusable widgets
│   └── providers/     # Riverpod providers
└── l10n/              # Internationalization files
```

#### Naming Conventions

```dart
// UpperCamelCase for classes
class ImageGenerator {}

// lowerCamelCase for variables and methods
final imageCount = 0;
void generateImage() {}

// lowerCamelCase for constants
const maxImageSize = 1024;

// Underscore prefix for private members
void _privateMethod() {}

// Provider naming
final imageProvider = Provider<Image>((ref) => Image());
final imageListProvider = StateProvider<List<Image>>((ref) => []);
```

---

## 提交信息规范 | Commit Message Guidelines

### 中文 | Chinese

我们使用 **Conventional Commits** 规范。提交信息格式如下：

We use the **Conventional Commits** specification. Commit message format:

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

#### 类型 | Types

| 类型 | Type | 描述 | Description |
|------|------|------|-------------|
| `feat` | Feature | 新功能 | New feature |
| `fix` | Bug Fix | Bug 修复 | Bug fix |
| `docs` | Documentation | 文档变更 | Documentation changes |
| `style` | Style | 代码格式（不影响功能） | Code formatting (no functional change) |
| `refactor` | Refactor | 重构（不是新功能也不是修复） | Code refactoring |
| `test` | Test | 添加或更新测试 | Adding or updating tests |
| `chore` | Chore | 构建过程或辅助工具变动 | Build process or auxiliary tool changes |
| `perf` | Performance | 性能优化 | Performance improvement |

#### 示例 | Examples

```bash
# 新功能 | New feature
feat(image): add batch image generation support

# Bug 修复 | Bug fix
fix(auth): resolve token expiration issue on API calls

# 文档 | Documentation
docs(readme): update installation instructions for Windows

# 重构 | Refactor
refactor(widget): extract color picker logic into separate component

# 性能优化 | Performance
perf(canvas): optimize layer rendering with viewport culling

# 测试 | Test
test(generator): add unit tests for prompt validation

# 自动生成 | Auto-generated (auto-claude)
auto-claude: subtask-1-2 - Create CONTRIBUTING.md with contribution guidelines
```

### English

We use the **Conventional Commits** specification. Commit message format:

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

#### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation changes |
| `style` | Code formatting (no functional change) |
| `refactor` | Code refactoring |
| `test` | Adding or updating tests |
| `chore` | Build process or auxiliary tool changes |
| `perf` | Performance improvement |

#### Examples

```bash
# New feature
feat(image): add batch image generation support

# Bug fix
fix(auth): resolve token expiration issue on API calls

# Documentation
docs(readme): update installation instructions for Windows

# Refactor
refactor(widget): extract color picker logic into separate component

# Performance
perf(canvas): optimize layer rendering with viewport culling

# Test
test(generator): add unit tests for prompt validation

# Auto-generated (auto-claude)
auto-claude: subtask-1-2 - Create CONTRIBUTING.md with contribution guidelines
```

---

## Pull Request 流程 | Pull Request Process

### 中文 | Chinese

#### PR 流程 | PR Workflow

1. **创建分支 | Create Branch**

```bash
git checkout -b feature/your-feature-name
# 或 | or
git checkout -b fix/bug-description
```

2. **进行更改并提交 | Make Changes and Commit**

```bash
# 添加更改的文件 | Add changed files
git add .

# 提交更改（遵循提交规范）| Commit changes (follow commit conventions)
git commit -m "feat(widget): add new feature description"

# 或修复上一个提交 | Or fix the last commit
git commit --amend
```

3. **同步上游更改 | Sync with Upstream**

```bash
# 获取上游更改 | Fetch upstream changes
git fetch upstream

# 合并上游主分支 | Merge upstream main branch
git merge upstream/main

# 解决冲突（如果有）| Resolve conflicts (if any)
```

4. **推送并创建 PR | Push and Create PR**

```bash
# 推送到您的 fork | Push to your fork
git push origin feature/your-feature-name

# 在 GitHub 上创建 Pull Request
# 标题格式 | Title format: feat(scope): brief description
```

#### PR 检查清单 | PR Checklist

在提交 PR 前，请确认：

Before submitting a PR, please confirm:

- [ ] 代码通过 `flutter analyze` 检查 | Code passes `flutter analyze`
- [ ] 所有测试通过 `flutter test` | All tests pass `flutter test`
- [ ] 添加了必要的测试 | Added necessary tests
- [ ] 更新了相关文档 | Updated relevant documentation
- [ ] 遵循了代码规范 | Followed coding standards
- [ ] 提交信息符合规范 | Commit messages follow conventions
- [ ] 添加了中英文翻译（如适用）| Added bilingual translations (if applicable)

#### PR 描述模板 | PR Description Template

```markdown
## 描述 | Description
<!-- 简要描述此 PR 的更改 | Briefly describe the changes in this PR -->

## 类型 | Type
- [ ] 新功能 | New feature
- [ ] Bug 修复 | Bug fix
- [ ] 重构 | Refactor
- [ ] 文档 | Documentation
- [ ] 其他 | Other

## 测试 | Testing
- [ ] 单元测试 | Unit tests
- [ ] 集成测试 | Integration tests
- [ ] 手动测试 | Manual testing

## 截图 | Screenshots
<!-- 如果适用，添加截图 | Add screenshots if applicable -->

## 相关 Issue | Related Issues
Closes #(issue number)
```

### English

#### PR Workflow

1. **Create Branch**

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

2. **Make Changes and Commit**

```bash
# Add changed files
git add .

# Commit changes (follow commit conventions)
git commit -m "feat(widget): add new feature description"

# Or fix the last commit
git commit --amend
```

3. **Sync with Upstream**

```bash
# Fetch upstream changes
git fetch upstream

# Merge upstream main branch
git merge upstream/main

# Resolve conflicts (if any)
```

4. **Push and Create PR**

```bash
# Push to your fork
git push origin feature/your-feature-name

# Create Pull Request on GitHub
# Title format: feat(scope): brief description
```

#### PR Checklist

Before submitting a PR, please confirm:

- [ ] Code passes `flutter analyze`
- [ ] All tests pass `flutter test`
- [ ] Added necessary tests
- [ ] Updated relevant documentation
- [ ] Followed coding standards
- [ ] Commit messages follow conventions
- [ ] Added bilingual translations (if applicable)

#### PR Description Template

```markdown
## Description
<!-- Briefly describe the changes in this PR -->

## Type
- [ ] New feature
- [ ] Bug fix
- [ ] Refactor
- [ ] Documentation
- [ ] Other

## Testing
- [ ] Unit tests
- [ ] Integration tests
- [ ] Manual testing

## Screenshots
<!-- Add screenshots if applicable -->

## Related Issues
Closes #(issue number)
```

---

## 测试要求 | Testing Requirements

### 中文 | Chinese

#### 测试结构 | Test Structure

```
test/
├── data/              # 数据层测试 | Data layer tests
├── domain/            # 领域层测试 | Domain layer tests
├── presentation/      # 展示层测试 | Presentation layer tests
├── widgets/           # Widget 测试 | Widget tests
└── integration/       # 集成测试 | Integration tests
```

#### 运行测试 | Running Tests

```bash
# 运行所有测试 | Run all tests
flutter test

# 运行特定测试文件 | Run specific test file
flutter test test/widgets/image_generator_test.dart

# 运行测试并查看覆盖率 | Run tests with coverage
flutter test --coverage

# 查看覆盖率报告 | View coverage report
# Windows:
genhtml coverage/lcov.info -o coverage/html
# Then open coverage/html/index.html
```

#### 编写测试 | Writing Tests

**单元测试示例 | Unit Test Example:**

```dart
void main() {
  group('ImageGenerator', () {
    test('should generate image with valid prompt', () {
      // Arrange
      final generator = ImageGenerator();
      const prompt = 'beautiful landscape';

      // Act
      final result = generator.generate(prompt);

      // Assert
      expect(result, isNotNull);
      expect(result.prompt, equals(prompt));
    });

    test('should throw error with empty prompt', () {
      final generator = ImageGenerator();

      expect(
        () => generator.generate(''),
        throwsA(isA<InvalidPromptException>()),
      );
    });
  });
}
```

**Widget 测试示例 | Widget Test Example:**

```dart
void main() {
  testWidgets('ImageGeneratorPage shows loading indicator',
      (WidgetTester tester) async {
    // Build widget
    await tester.pumpWidget(
      MaterialApp(
        home: ImageGeneratorPage(),
      ),
    );

    // Verify loading indicator exists
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

**集成测试示例 | Integration Test Example:**

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full image generation flow', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // Enter prompt
    await tester.enterText(
      find.byKey(Key('prompt_field')),
      'beautiful landscape',
    );

    // Tap generate button
    await tester.tap(find.byKey(Key('generate_button')));
    await tester.pumpAndSettle();

    // Verify image is generated
    expect(find.byType(ImageGeneratedWidget), findsOneWidget);
  });
}
```

#### 测试最佳实践 | Testing Best Practices

**✅ 应该做 | Should Do:**

- 测试所有公共 API | Test all public APIs
- 测试边界条件 | Test edge cases
- 测试错误处理 | Test error handling
- 使用描述性测试名称 | Use descriptive test names
- 保持测试简单和专注 | Keep tests simple and focused
- Mock 外部依赖 | Mock external dependencies

**❌ 不应该做 | Should Not Do:**

- 测试私有方法 | Don't test private methods
- 编写脆弱的测试 | Don't write flaky tests
- 测试第三方库 | Don't test third-party libraries
- 过度使用 Mock | Don't overuse mocks

### English

#### Test Structure

```
test/
├── data/              # Data layer tests
├── domain/            # Domain layer tests
├── presentation/      # Presentation layer tests
├── widgets/           # Widget tests
└── integration/       # Integration tests
```

#### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widgets/image_generator_test.dart

# Run tests with coverage
flutter test --coverage

# View coverage report
# Windows:
genhtml coverage/lcov.info -o coverage/html
# Then open coverage/html/index.html
```

#### Writing Tests

**Unit Test Example:**

```dart
void main() {
  group('ImageGenerator', () {
    test('should generate image with valid prompt', () {
      // Arrange
      final generator = ImageGenerator();
      const prompt = 'beautiful landscape';

      // Act
      final result = generator.generate(prompt);

      // Assert
      expect(result, isNotNull);
      expect(result.prompt, equals(prompt));
    });

    test('should throw error with empty prompt', () {
      final generator = ImageGenerator();

      expect(
        () => generator.generate(''),
        throwsA(isA<InvalidPromptException>()),
      );
    });
  });
}
```

**Widget Test Example:**

```dart
void main() {
  testWidgets('ImageGeneratorPage shows loading indicator',
      (WidgetTester tester) async {
    // Build widget
    await tester.pumpWidget(
      MaterialApp(
        home: ImageGeneratorPage(),
      ),
    );

    // Verify loading indicator exists
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

**Integration Test Example:**

```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full image generation flow', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // Enter prompt
    await tester.enterText(
      find.byKey(Key('prompt_field')),
      'beautiful landscape',
    );

    // Tap generate button
    await tester.tap(find.byKey(Key('generate_button')));
    await tester.pumpAndSettle();

    // Verify image is generated
    expect(find.byType(ImageGeneratedWidget), findsOneWidget);
  });
}
```

#### Testing Best Practices

**✅ Should Do:**

- Test all public APIs
- Test edge cases
- Test error handling
- Use descriptive test names
- Keep tests simple and focused
- Mock external dependencies

**❌ Should Not Do:**

- Don't test private methods
- Don't write flaky tests
- Don't test third-party libraries
- Don't overuse mocks

---

## 添加翻译 | Adding Translations

### 中文 | Chinese

#### 翻译文件位置 | Translation Files Location

```
lib/l10n/
├── app_en.arb    # 英文翻译 | English translations
└── app_zh.arb    # 中文翻译 | Chinese translations
```

#### 添加新翻译 | Adding New Translations

1. **在两个 ARB 文件中添加新键 | Add new keys in both ARB files**

**app_en.arb:**
```json
{
  "@@locale": "en",
  "newFeatureTitle": "New Feature",
  "@newFeatureTitle": {
    "description": "Title for the new feature page"
  }
}
```

**app_zh.arb:**
```json
{
  "@@locale": "zh",
  "newFeatureTitle": "新功能",
  "@newFeatureTitle": {
    "description": "新功能页面的标题"
  }
}
```

2. **在代码中使用翻译 | Use translations in code**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Text(l10n.newFeatureTitle);
  }
}
```

3. **生成翻译代码 | Generate translation code**

```bash
flutter gen-l10n
```

#### 翻译最佳实践 | Translation Best Practices

- **键名规范 | Key Naming:** 使用 lowerCamelCase | Use lowerCamelCase
- **保持一致性 | Be Consistent:** 相同概念使用相同翻译 | Use same translation for same concept
- **上下文相关 | Context-Aware:** 考虑上下文和场景 | Consider context and scenario
- **简洁明了 | Concise:** UI 文本应简洁 | UI text should be concise
- **添加元数据 | Add Metadata:** 为翻译键添加描述 | Add descriptions for translation keys

### English

#### Translation Files Location

```
lib/l10n/
├── app_en.arb    # English translations
└── app_zh.arb    # Chinese translations
```

#### Adding New Translations

1. **Add new keys in both ARB files**

**app_en.arb:**
```json
{
  "@@locale": "en",
  "newFeatureTitle": "New Feature",
  "@newFeatureTitle": {
    "description": "Title for the new feature page"
  }
}
```

**app_zh.arb:**
```json
{
  "@@locale": "zh",
  "newFeatureTitle": "新功能",
  "@newFeatureTitle": {
    "description": "新功能页面的标题"
  }
}
```

2. **Use translations in code**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Text(l10n.newFeatureTitle);
  }
}
```

3. **Generate translation code**

```bash
flutter gen-l10n
```

#### Translation Best Practices

- **Key Naming:** Use lowerCamelCase
- **Be Consistent:** Use same translation for same concept
- **Context-Aware:** Consider context and scenario
- **Concise:** UI text should be concise
- **Add Metadata:** Add descriptions for translation keys

---

## 报告问题 | Reporting Issues

### 中文 | Chinese

#### 报告 Bug | Bug Reports

报告 Bug 时，请提供：

When reporting bugs, please provide:

1. **问题描述 | Problem Description**
   - 清晰简洁地描述问题 | Clear and concise description of the problem
   - 复现步骤 | Steps to reproduce
   - 期望行为 | Expected behavior
   - 实际行为 | Actual behavior

2. **环境信息 | Environment Information**
   - 操作系统 | Operating system (Windows/Android/Linux version)
   - Flutter 版本 | Flutter version (`flutter --version`)
   - 应用版本 | App version

3. **截图和日志 | Screenshots and Logs**
   - 相关截图 | Relevant screenshots
   - 错误日志 | Error logs
   - 控制台输出 | Console output

4. **最小复现示例 | Minimal Reproduction**
   - 如果可能，提供最小可复现示例 | If possible, provide minimal reproducible example

#### 功能建议 | Feature Requests

提交功能建议时，请说明：

When submitting feature requests, please explain:

1. **功能描述 | Feature Description**
   - 清晰描述建议的功能 | Clearly describe the suggested feature
   - 使用场景 | Use cases
   - 预期效果 | Expected results

2. **替代方案 | Alternatives**
   - 考虑过的其他解决方案 | Other solutions considered

3. **附加信息 | Additional Context**
   - 相关链接 | Related links
   - 参考实现 | Reference implementations

### English

#### Bug Reports

When reporting bugs, please provide:

1. **Problem Description**
   - Clear and concise description of the problem
   - Steps to reproduce
   - Expected behavior
   - Actual behavior

2. **Environment Information**
   - Operating system (Windows/Android/Linux version)
   - Flutter version (`flutter --version`)
   - App version

3. **Screenshots and Logs**
   - Relevant screenshots
   - Error logs
   - Console output

4. **Minimal Reproduction**
   - If possible, provide minimal reproducible example

#### Feature Requests

When submitting feature requests, please explain:

1. **Feature Description**
   - Clearly describe the suggested feature
   - Use cases
   - Expected results

2. **Alternatives**
   - Other solutions considered

3. **Additional Context**
   - Related links
   - Reference implementations

---

## 获取帮助 | Getting Help

### 中文 | Chinese

- **GitHub Issues:** 报告 Bug 或功能请求 | Report bugs or feature requests
- **GitHub Discussions:** 讨论问题和想法 | Discuss problems and ideas
- **文档 | Documentation:** 查看 `docs/` 目录获取更多文档 | Check `docs/` directory for more documentation

### English

- **GitHub Issues:** Report bugs or feature requests
- **GitHub Discussions:** Discuss problems and ideas
- **Documentation:** Check `docs/` directory for more documentation

---

## 致谢 | Acknowledgments

**感谢所有贡献者！** 您的贡献使 NAI Launcher 变得更好。

**Thank you to all contributors!** Your contributions make NAI Launcher better.

---

**再次感谢您的贡献！我们期待您的 Pull Request！**

**Thank you again for your contribution! We look forward to your Pull Request!**

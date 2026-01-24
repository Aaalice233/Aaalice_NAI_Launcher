## 🛠️ 开发环境配置

### Flutter SDK 位置

```
E:\flutter\bin\flutter.bat
E:\flutter\bin\dart.bat
```

**常用命令**：
- 代码生成: `E:\flutter\bin\flutter.bat pub run build_runner build --delete-conflicting-outputs`
- 静态分析: `E:\flutter\bin\flutter.bat analyze`
- 运行测试: `E:\flutter\bin\flutter.bat test`
- 构建应用: `E:\flutter\bin\flutter.bat build windows`

## COMMANDS

```bash
# 运行应用
flutter run -d windows

# 代码生成 (必须执行)
dart run build_runner build --delete-conflicting-outputs

# 代码分析 (提交前必须通过)
flutter analyze

# 运行所有测试
flutter test

# 运行单个测试文件
flutter test test/data/services/random_prompt_generator_test.dart

# 运行单个测试组
flutter test -g "RandomPromptGenerator 参数使用测试"

# 构建发布包 (Windows)
flutter build windows --release

# 构建 Android APK
flutter build apk --release
```
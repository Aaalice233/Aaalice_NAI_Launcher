# NAI启动器第一阶段Bug修复工作计划

## 概述

本文档是NAI启动器第一阶段4个严重Bug修复的详细工作计划。

**优先级**：
- P0: Bug #1 (Vibe绑定) - 涉及资金，优先级最高
- P1: Bug #3 (登录失败) - 功能完全不可用
- P2: Bug #2 (DDIM采样器) - 部分用户受影响
- P3: Bug #4 (预填充点击) - 体验问题

---

## Bug #1: Vibe绑定图片被重新编码

### 问题描述
用户绑定vibe的图片无法被正确读取为vibe，选择作为vibe时会消耗点数进行重新编码。

### 根本原因
1. `VibeFileParser.fromPng()`从PNG的iTXt块提取编码，如果元数据不存在，解析器失败后没有明确处理
2. 失败后图片被错误标记为`rawImage`类型
3. `rawImage`类型会被计入点数消耗（2 Anlas/张）

### 涉及文件
- `lib/core/utils/vibe_file_parser.dart` - 解析逻辑
- `lib/data/models/vibe/vibe_reference_v4.dart` - 数据模型
- `lib/data/models/image/image_params.dart` - 消耗计算
- `lib/presentation/screens/generation/widgets/unified_reference_panel.dart` - UI交互

### 修复步骤

#### 任务1.1: 改进VibeFileParser解析逻辑
**文件**: `lib/core/utils/vibe_file_parser.dart`

**修改内容**:
1. 在`fromPng()`方法第86-122行增加明确的解析状态标记
2. 添加`parsingFailed`状态用于区分解析失败的情况
3. 增加详细日志记录解析过程

**具体修改**:
```dart
// 在fromPng()方法中
try {
  final chunks = png_extract.extractChunks(bytes);
  String? vibeEncoding;
  
  for (final chunk in chunks) {
    if (chunk['name'] == 'iTXt') {
      final iTXtData = chunk['data'] as Uint8List;
      vibeEncoding = _parseITXtChunk(iTXtData);
      if (vibeEncoding != null) break;
    }
  }
  
  if (vibeEncoding != null) {
    // 成功提取预编码数据
    return VibeReferenceV4(
      displayName: fileName,
      vibeEncoding: vibeEncoding,
      sourceType: VibeSourceType.preEncoded,
      // ... 其他参数
    );
  }
  
  // 没有找到预编码数据 - 明确标记为需要编码
  return VibeReferenceV4(
    displayName: fileName,
    vibeEncoding: '',
    rawImageData: bytes,
    sourceType: VibeSourceType.rawImage, // 明确需要编码
  );
} catch (e, stack) {
  // 解析失败 - 记录日志并询问用户
  logger.error('Vibe解析失败: $e', stackTrace: stack);
  return null; // 返回null，让上层处理
}
```

**验收标准**:
- [ ] PNG有有效编码元数据 → 返回preEncoded类型
- [ ] PNG无iTXt块 → 返回rawImage类型（不消耗点数）
- [ ] PNG有损坏iTXt → 返回null并记录日志
- [ ] 单元测试覆盖所有边缘情况

#### 任务1.2: 增强用户反馈UI
**文件**: `lib/presentation/screens/generation/widgets/unified_reference_panel.dart`

**修改内容**:
1. 在`_addVibeV4()`函数中处理解析结果
2. 显示图片是否已预编码的视觉指示
3. 如果没有预编码，显示消耗提示

**具体修改**:
```dart
Future<void> _addVibeV4() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['png', 'naiv4vibe', 'naiv4vibebundle'],
  );
  
  if (result == null) return;
  
  for (final file in result.files) {
    final bytes = await file.readAsBytes();
    final vibe = await VibeFileParser.parseFile(file.name, bytes);
    
    if (vibe == null) {
      // 解析失败，提示用户
      showErrorSnackBar(context.l10n.vibeParseFailed);
      continue;
    }
    
    if (vibe.sourceType == VibeSourceType.rawImage) {
      // 没有预编码，显示消耗提示
      final confirm = await showConfirmDialog(
        context.l10n.vibeNoEncodingWarning,
        context.l10n.vibeWillCostAnlas(2),
      );
      if (!confirm) continue;
    }
    
    notifier.addVibeReferenceV4(vibe);
  }
}
```

**验收标准**:
- [ ] 添加图片后显示编码状态图标
- [ ] 没有预编码的图片显示消耗提示
- [ ] 用户可以选择取消添加
- [ ] 国际化文本已添加到arb文件

#### 任务1.3: 优化消耗计算逻辑
**文件**: `lib/data/models/image/image_params.dart`

**修改内容**:
1. 只计算用户确认需要编码的图片
2. 显示预计消耗

**具体修改**:
```dart
// 只计算用户选择需要编码的vibe
int get vibeEncodingCount => vibeReferencesV4
    .where((v) => v.sourceType == VibeSourceType.rawImage)
    .length;
```

**验收标准**:
- [ ] 只有用户确认后才计入消耗
- [ ] 生成前显示准确的点数消耗
- [ ] 单元测试验证计算逻辑

### 测试用例
- ✅ PNG有有效编码元数据 → 不消耗点数
- ✅ PNG无iTXt块 → 提示用户将编码
- ✅ PNG有损坏iTXt → 提示解析失败
- ✅ 多张混合 → 正确计算总消耗
- ✅ 从.naiv4vibe文件导入 → 使用已有编码

---

## Bug #2: DDIM采样器无法生图

### 问题描述
采样器列表中的两个DDIM变体（ddim、ddim_v3）无法正常生成图片。

### 根本原因
1. DDIM的API名称与NovelAI后端期望的不一致
2. V4模型可能不原生支持DDIM
3. 缺少采样器有效性验证

### 涉及文件
- `lib/core/constants/api_constants.dart` - 采样器定义
- `lib/data/datasources/remote/nai_api_service.dart` - API调用
- `lib/presentation/providers/image_generation_provider.dart` - 状态管理

### 修复步骤

#### 任务2.1: 验证API支持和实现映射
**文件**: `lib/data/datasources/remote/nai_api_service.dart`

**修改内容**:
1. 根据模型版本自动映射采样器
2. V4模型不支持DDIM时回退到Euler

**具体修改**:
```dart
String _mapSamplerForModel(String sampler, String model) {
  // DDIM在V3模型中需要使用ddim_v3
  if (sampler == Samplers.ddim) {
    if (model.contains('diffusion-3')) {
      return Samplers.ddimV3;
    }
    // V4及以后版本不原生支持DDIM
    if (model.contains('diffusion-4') || model == 'N/A') {
      logger.warning('V4模型不支持DDIM，回退到Euler');
      return Samplers.kEuler;
    }
  }
  return sampler;
}

// 在generate方法中使用
final effectiveSampler = _mapSamplerForModel(params.sampler, params.model);
```

**验收标准**:
- [ ] DDIM + V1/V2 → 使用ddim
- [ ] DDIM + V3 → 自动映射到ddim_v3
- [ ] DDIM + V4 → 警告并回退到Euler

#### 任务2.2: 添加UI警告
**文件**: `lib/presentation/screens/generation/widgets/parameter_panel.dart`

**修改内容**:
1. 在采样器选择时显示兼容性警告
2. 不支持的组合显示警告图标

**验收标准**:
- [ ] 选择DDIM时显示模型兼容性提示
- [ ] 不支持的组合有视觉警告
- [ ] 日志记录警告信息

### 测试用例
- ✅ DDIM + V1/V2 → 正常生成
- ✅ DDIM + V3 → 映射到ddim_v3后生成
- ✅ DDIM + V4 → 回退到Euler并提示用户

---

## Bug #3: Danbooru/画廊登录失败

### 问题描述
danbooru登录时输入昵称和API提示登录成功但还是未登录状态，画廊登录也有同样问题。

### 根本原因
1. Danbooru登录只保存凭据，没有进行API验证
2. `isLoggedIn`状态判断基于本地凭据，而非API验证结果
3. 画廊登录Token验证可能失败但状态未更新

### 涉及文件
- `lib/data/services/danbooru_auth_service.dart` - 登录逻辑
- `lib/data/datasources/remote/danbooru_api_service.dart` - API验证
- `lib/presentation/providers/online_gallery_provider.dart` - 画廊状态
- `lib/presentation/providers/auth_provider.dart` - 画廊登录

### 修复步骤

#### 任务3.1: 重构Danbooru登录流程
**文件**: `lib/data/services/danbooru_auth_service.dart`

**修改内容**:
1. 先API验证再保存凭据
2. 验证失败时返回具体错误
3. 分离credentials和user状态

**具体修改**:
```dart
class DanbooruAuth extends Notifier<DanbooruAuthState> {
  Future<bool> login(String username, String apiKey) async {
    // 验证输入
    if (username.isEmpty || apiKey.isEmpty) {
      state = state.copyWith(error: '用户名和API Key不能为空');
      return false;
    }
    
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final credentials = DanbooruCredentials(username, apiKey);
      
      // 先验证凭据是否有效
      final apiService = ref.read(danbooruApiServiceProvider);
      final user = await apiService.getCurrentUser(credentials);
      
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error: '无法验证凭据，请检查用户名和API Key是否正确',
        );
        return false;
      }
      
      // 验证成功，保存凭据
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_credentialsKey, jsonEncode(credentials.toJson()));
      
      state = state.copyWith(
        credentials: credentials,
        user: user,
        isLoading: false,
        error: null,
      );
      
      return true;
    } catch (e, stack) {
      logger.error('登录失败: $e', stackTrace: stack);
      state = state.copyWith(
        isLoading: false,
        error: '登录失败，请检查网络连接',
      );
      return false;
    }
  }
}
```

**验收标准**:
- [ ] 正确凭据 → 登录成功，显示用户信息
- [ ] 错误凭据 → 显示具体错误信息
- [ ] 网络错误 → 重试提示

#### 任务3.2: 增强API验证逻辑
**文件**: `lib/data/datasources/remote/danbooru_api_service.dart`

**修改内容**:
1. 调用`getCurrentUser()`验证凭据
2. 处理网络错误和API变更

**具体修改**:
```dart
Future<DanbooruUser?> getCurrentUser([DanbooruCredentials? credentials]) async {
  final auth = credentials ?? _authState.credentials;
  if (auth == null) return null;
  
  try {
    final response = await _dio.get(
      '/profile.json',
      options: Options(headers: _buildAuthHeader(auth)),
    );
    
    if (response.statusCode == 200) {
      return DanbooruUser.fromJson(response.data);
    }
    
    if (response.statusCode == 401) {
      logger.warning('Danbooru凭据已过期');
      return null;
    }
    
    logger.error('Danbooru API错误: ${response.statusCode}');
    return null;
  } on DioException catch (e) {
    if (e.type == DioExceptionType.connectionTimeout) {
      logger.error('Danbooru连接超时');
    }
    return null;
  }
}
```

**验收标准**:
- [ ] 正确凭据 → 返回用户信息
- [ ] 错误凭据 → 返回null
- [ ] 网络错误 → 返回null并记录日志

#### 任务3.3: 修复状态判断逻辑
**文件**: `lib/data/services/danbooru_auth_service.dart`

**修改内容**:
1. 基于API验证结果判断登录状态
2. 添加过期检测

**具体修改**:
```dart
bool get isLoggedIn => credentials != null && user != null;

// 添加过期检测
bool get isExpired {
  if (user == null) return true;
  final lastVerified = _lastVerifiedTime;
  if (lastVerified == null) return true;
 

---

## 修改记录

### 第一次修改 (2026-01-09 20:00) - 根据Momus审核

#### 1. Bug #1 修改: 修正验收标准和国际化

##### 修改1.1: 验收标准修正
**原内容**:
```
- [ ] PNG无iTXt块 → 返回rawImage类型（不消耗点数）
```

**修改为**:
```
- [ ] PNG无iTXt块 → 返回rawImage类型（用户确认后编码，消耗2 Anlas）
- [ ] 生成前显示明确的消耗提示："编码将消耗 2 Anlas"
- [ ] 用户可选择确认或取消添加
```

##### 修改1.2: 添加国际化支持
**新增任务1.0: 国际化文本准备**
```
任务1.0: 国际化文本准备
**文件**: lib/l10n/app_zh.arb, lib/l10n/app_en.arb

**修改内容**:
添加以下国际化文本:
```json
{
  "vibeNoEncodingWarning": "此图片没有预编码数据",
  "vibeWillCostAnlas": "编码将消耗 {count} Anlas",
  "@vibeWillCostAnlas": {
    "placeholders": {"count": {"type": "int"}}
  },
  "vibeParseFailed": "无法解析Vibe文件",
  "vibeConfirmEncode": "确认编码",
  "vibeCancel": "取消"
}
```

**验收标准**:
- [ ] 所有用户可见文本已添加到 app_zh.arb
- [ ] 所有用户可见文本已添加到 app_en.arb
- [ ] 使用 context.l10n.xxx 引用文本
```

#### 2. Bug #2 修改: 增加API行为验证

##### 修改2.1: 新增验证任务
**新增任务2.0: API行为验证**
```
任务2.0: API行为验证（修复前必须完成）
**文件**: lib/data/datasources/remote/nai_api_service.dart

**修改内容**:
1. 在修复前进行API测试，确认DDIM的实际支持情况
2. 测试不同模型版本×采样器组合：
   - V1/V2 + ddim → 测试是否正常工作
   - V3 + ddim → 测试是否需要映射到ddim_v3
   - V4 + ddim → 测试是否回退到Euler
3. 根据测试结果调整映射逻辑

**测试方法**:
```dart
// 添加测试代码
Future<void> testDDIMSupport() async {
  final testCases = [
    (model: 'nai-diffusion-1', sampler: 'ddim'),
    (model: 'nai-diffusion-2', sampler: 'ddim'),
    (model: 'nai-diffusion-3', sampler: 'ddim'),
    (model: 'nai-diffusion-4', sampler: 'ddim'),
  ];
  
  for (final testCase in testCases) {
    try {
      final result = await testGeneration(testCase.model, testCase.sampler);
      logger.info('${testCase.model} + ${testCase.sampler}: ${result.status}');
    } catch (e) {
      logger.error('测试失败: ${testCase.model} + ${testCase.sampler}: $e');
    }
  }
}
```

**验收标准**:
- [ ] 已测试所有模型版本×DDIM组合
- [ ] 已记录实际支持情况
- [ ] 已根据测试结果调整映射逻辑
```

##### 修改2.2: 完善回退策略
**修改内容**:
```dart
String _mapSamplerForModel(String sampler, String model) {
  if (sampler == Samplers.ddim) {
    if (model.contains('diffusion-3')) {
      return Samplers.ddimV3;
    }
    
    if (model.contains('diffusion-4') || model == 'N/A') {
      // 记录警告日志
      logger.warning(
        '模型 $model 不支持 DDIM 采样器，'
        '将回退到 Euler Ancestral'
      );
      
      // 可选: 触发UI通知（如果需要）
      // _showUnsupportedSamplerWarning(model, sampler);
      
      return Samplers.kEulerAncestral;
    }
  }
  
  return sampler;
}
```

#### 3. Bug #4 修改: 补充中文输入法测试

##### 修改3.1: 新增测试用例
**修改任务4.2: 增强标签解析**

**验收标准补充**:
```dart
// 新增测试用例
test('中文输入 - 搜索建议', () async {
  // 模拟中文输入
  await tester.enterText(find.byType(TextField), '红色');
  
  // 等待防抖完成
  await tester.pump(Duration(milliseconds: 300));
  
  // 验证建议显示
  expect(find.text('red'), findsOneWidget);
  expect(find.text('crimson'), findsOneWidget);
});

test('中文输入 - 建议替换', () async {
  // 输入中文
  await tester.enterText(find.byType(TextField), '红色, ');
  
  // 等待建议显示
  await tester.pump(Duration(milliseconds: 300));
  
  // 点击建议
  await tester.tap(find.text('red').first);
  await tester.pump();
  
  // 验证替换结果
  expect(find.text('红色, red'), findsOneWidget);
});

test('中文输入法 - 组合输入', () async {
  // 测试IME组合过程中的搜索行为
  // 测试候选词选择
  // 验证不会在组合过程中触发搜索
});
```

#### 4. 通用修改: 补充完整测试策略

##### 修改4.1: 完整的测试策略
**新增章节: 测试策略**

```markdown
## 测试策略

### 测试优先级

| 优先级 | 测试类型 | 覆盖范围 | 执行频率 |
|--------|---------|---------|---------|
| P0 | 单元测试 | 核心逻辑 | 每次提交 |
| P1 | 集成测试 | 模块交互 | 每次构建 |
| P2 | UI测试 | 用户流程 | 每日构建 |
| P3 | 手动测试 | 边缘情况 | 发布前 |

### 单元测试 (必需)

#### Bug #1 测试
**文件**: test/vibe/vibe_file_parser_test.dart
```dart
void main() {
  group('VibeFileParser', () {
    test('PNG有有效编码元数据 → 返回preEncoded类型', () async {
      final bytes = await loadPngWithEncoding();
      final result = await VibeFileParser.parseFile('test.png', bytes);
      expect(result?.sourceType, equals(VibeSourceType.preEncoded));
      expect(result?.vibeEncoding, isNotEmpty);
    });
    
    test('PNG无iTXt块 → 返回rawImage类型', () async {
      final bytes = await loadPngWithoutITXt();
      final result = await VibeFileParser.parseFile('test.png', bytes);
      expect(result?.sourceType, equals(VibeSourceType.rawImage));
    });
    
    test('PNG有损坏iTXt → 返回null', () async {
      final bytes = await loadPngWithCorruptedITXt();
      final result = await VibeFileParser.parseFile('test.png', bytes);
      expect(result, isNull);
    });
  });
}
```

#### Bug #3 测试
**文件**: test/auth/danbooru_auth_test.dart
```dart
void main() {
  group('DanbooruAuth', () {
    test('正确凭据 → 登录成功', () async {
      final auth = DanbooruAuth();
      final result = await auth.login('valid_user', 'valid_api_key');
      expect(result, isTrue);
      expect(auth.state.user, isNotNull);
    });
    
    test('错误凭据 → 登录失败', () async {
      final auth = DanbooruAuth();
      final result = await auth.login('invalid_user', 'invalid_api_key');
      expect(result, isFalse);
      expect(auth.state.error, isNotNull);
    });
    
    test('网络错误 → 返回网络错误信息', () async {
      // 模拟网络错误
    });
  });
}
```

#### Bug #4 测试
**文件**: test/widgets/autocomplete_text_field_test.dart
```dart
void main() {
  group('AutocompleteTextField', () {
    testWidgets('英文输入 → 建议正常替换', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AutocompleteTextField(),
      ));
      
      await tester.enterText(find.byType(TextField), 'mast');
      await tester.pump(Duration(milliseconds: 300));
      
      expect(find.text('masterpiece'), findsOneWidget);
    });
    
    testWidgets('中文输入 → 建议正常替换', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AutocompleteTextField(),
      ));
      
      await tester.enterText(find.byType(TextField), '红色');
      await tester.pump(Duration(milliseconds: 300));
      
      expect(find.text('red'), findsOneWidget);
    });
    
    testWidgets('权重语法 → 正常替换', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AutocompleteTextField(),
      ));
      
      await tester.enterText(find.byType(TextField), '(masterpiece:1.');
      await tester.pump(Duration(milliseconds: 300));
      
      expect(find.text('masterpiece'), findsOneWidget);
    });
  });
}
```

### UI测试 (推荐)

#### Bug #1 UI测试
**文件**: test/integration/vibe_binding_flow_test.dart
```dart
void main() {
  testWidgets('完整Vibe绑定流程', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GenerationScreen(),
    ));
    
    // 打开Vibe面板
    await tester.tap(find.byIcon(Icons.image));
    
    // 添加图片
    await tester.tap(find.text('添加Vibe'));
    
    // 选择PNG文件（无编码）
    await tester.pump();
    
    // 验证显示消耗提示
    expect(find.text('编码将消耗 2 Anlas'), findsOneWidget);
    
    // 确认添加
    await tester.tap(find.text('确认编码'));
    await tester.pump();
    
    // 验证Vibe已添加
    expect(find.byType(VibeThumbnail), findsOneWidget);
  });
}
```

### 手动测试清单

#### Bug #1 手动测试
- [ ] PNG有有效编码 → 添加成功，不消耗点数
- [ ] PNG无iTXt块 → 显示消耗提示，确认后添加
- [ ] PNG有损坏iTXt → 显示错误提示，不添加
- [ ] .naiv4vibe文件 → 使用已有编码，不消耗点数
- [ ] 多张混合 → 正确计算总消耗

#### Bug #3 手动测试
- [ ] 正确凭据 → 登录成功，显示用户信息
- [ ] 错误用户名 → 显示"用户名或API Key错误"
- [ ] 错误API Key → 显示"用户名或API Key错误"
- [ ] 网络断开 → 显示"网络错误，请重试"
- [ ] 过期凭据 → 自动登出，提示重新登录

#### Bug #4 手动测试
- [ ] 英文输入 → 点击建议正确替换
- [ ] 中文输入 → 点击建议正确替换
- [ ] 权重语法 → 正常替换，权重不变
- [ ] 括号嵌套 → 正常替换
- [ ] 快速连续点击 → 不产生冲突
- [ ] 失焦后重新聚焦 → 建议正常显示

### 测试命令

```bash
# 运行所有测试
flutter test

# 运行特定测试文件
flutter test test/vibe/vibe_file_parser_test.dart
flutter test test/auth/danbooru_auth_test.dart
flutter test test/widgets/autocomplete_text_field_test.dart

# 运行集成测试
flutter test integration_test/

# 生成测试覆盖率报告
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### 测试环境要求

1. **Mock服务**:
   - Mock Danbooru API
   - Mock NAI API（用于测试DDIM）
   - Mock 文件系统（用于测试Vibe解析）

2. **测试数据**:
   - 有效编码的PNG文件
   - 无编码的PNG文件
   - 损坏iTXt的PNG文件
   - 有效的Danbooru凭据
   - 无效的Danbooru凭据

3. **持续集成**:
   - 每次PR自动运行单元测试
   - 每日构建运行所有测试
   - 测试覆盖率要求: >80%
```

### 运行测试验证修改

```bash
# 验证所有修改
flutter test --verbose

# 检查代码质量
flutter analyze

# 生成覆盖率报告
flutter test --coverage
```


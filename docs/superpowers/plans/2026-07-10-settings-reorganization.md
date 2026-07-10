# 设置页面分类重组（13→9 类）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把设置页 13 个平铺分类重组为 9 个语义自洽的分类，纯 UI 信息架构调整，不改任何持久化 key 与设置行为。

**Architecture:** 逐个改造/新建 section widget（Task 2-6），期间 `settings_screen.dart` 保持旧导航（中间态允许设置项在新旧分类同时出现，同一存储 key 天然双向同步）；Task 7 一次性切换导航到 9 类并删除废弃 section 文件；Task 8 清理旧 l10n 词条并做全量验证。集成页用 `SegmentedButton` 页内子导航，一次只渲染一个面板。

**Tech Stack:** Flutter (>=3.35.0) / Riverpod / Hive / flutter gen-l10n / flutter_test

**Spec:** `docs/superpowers/specs/2026-07-10-settings-reorganization-design.md`

## Global Constraints

- 不改任何 provider、持久化 key、设置默认值与生效逻辑（spec"非目标"节）。
- 迁移设置项时整块搬运 widget 代码及其依赖 import 与辅助方法，不重写控件逻辑。
- 所有用户可见新文案走 l10n（zh/en/ja 三份 ARB），不得硬编码中文（`test/i18n/hardcoded_chinese_regression_test.dart` 会拦截）；"Prompt Assistant"/"ComfyUI"/"Krita" 为专有名词直接硬编码（项目已有先例：`settings_screen.dart` 原 ComfyUI/Krita 分类标签）。
- 每个任务收尾运行该任务的测试 + `flutter analyze` 无新告警后提交；Conventional Commits。
- 中间态规则：Task 2-6 期间设置项允许在新旧两个分类重复出现；Task 5 后导航标签"存储"与页内标题"数据与存储"短暂不一致——均在 Task 7 收敛，不需要额外处理。
- 测试统一模式：`ProviderScope` + `MaterialApp(locale: zh, localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales)`；需要 `localStorageServiceProvider` 的测试用临时目录 `Hive.init` + `Hive.openBox(StorageKeys.settingsBox)`（参照 `test/presentation/screens/generation/widgets/fixed_tags_sidebar_test.dart`）。

---

### Task 1: 小节标题组件 + l10n 新词条

**Files:**
- Create: `lib/presentation/screens/settings/widgets/settings_section_label.dart`
- Modify: `lib/l10n/app_zh.arb`、`lib/l10n/app_en.arb`、`lib/l10n/app_ja.arb`
- Regenerate: `lib/l10n/app_localizations*.dart`（`flutter gen-l10n` 产物，随提交入库）

**Interfaces:**
- Produces: `SettingsSectionLabel(String text)` widget（Task 2、4 使用）；l10n getter：`settings_dataStorage`、`settings_privacySharing`、`settings_integrations`、`settings_generationInputSection`、`settings_generationRetrySection`、`settings_generationFeedbackSection`（Task 2、4、5、7 使用）

- [ ] **Step 1: 创建 SettingsSectionLabel 组件**

新建 `lib/presentation/screens/settings/widgets/settings_section_label.dart`：

```dart
import 'package:flutter/material.dart';

/// 设置卡片内的小节标题
///
/// 用于在一张设置卡片内划分多个小节，样式与原存储设置中
/// "保护功能"标题一致（labelLarge + primary + w700）。
class SettingsSectionLabel extends StatelessWidget {
  final String text;

  const SettingsSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 三份 ARB 新增词条**

在 `lib/l10n/app_zh.arb` 中找到 `"settings_generation": "生成",` 一行（约 231 行），其后插入：

```json
  "settings_dataStorage": "数据与存储",
  "settings_privacySharing": "安全与分享",
  "settings_integrations": "集成",
  "settings_generationInputSection": "输入",
  "settings_generationRetrySection": "失败重试",
  "settings_generationFeedbackSection": "完成提醒",
```

在 `lib/l10n/app_en.arb` 中找到 key 为 `"settings_generation"` 的行，其后插入：

```json
  "settings_dataStorage": "Data & Storage",
  "settings_privacySharing": "Privacy & Sharing",
  "settings_integrations": "Integrations",
  "settings_generationInputSection": "Input",
  "settings_generationRetrySection": "Retry on Failure",
  "settings_generationFeedbackSection": "Completion Alert",
```

在 `lib/l10n/app_ja.arb` 中找到 key 为 `"settings_generation"` 的行，其后插入：

```json
  "settings_dataStorage": "データとストレージ",
  "settings_privacySharing": "保護と共有",
  "settings_integrations": "連携",
  "settings_generationInputSection": "入力",
  "settings_generationRetrySection": "失敗時リトライ",
  "settings_generationFeedbackSection": "完了通知",
```

注意：本项目 ARB 词条不写 `@key` 描述注释，保持一致。

- [ ] **Step 3: 重新生成 l10n 并验证**

```bash
flutter gen-l10n
flutter analyze
```

Expected: gen-l10n exit 0；analyze 无新增告警（新组件暂未被引用，若报 unused 告警属预期，Task 2 引用后消失——Dart 对未引用的公开声明不告警，实际应无告警）。

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/screens/settings/widgets/settings_section_label.dart lib/l10n/
git commit -m "feat(settings): add reorg l10n entries and section label widget"
```

---

### Task 2: 生成分类改造（迁入重试 + 完成提示音）

**Files:**
- Rewrite: `lib/presentation/screens/settings/sections/generation_settings_section.dart`
- Test: `test/presentation/screens/settings/sections/generation_settings_section_test.dart`（新建）

**Interfaces:**
- Consumes: `SettingsSectionLabel`（Task 1）、l10n `settings_generation*Section`（Task 1）；既有 provider：`randomPromptToolsVisibilityProvider`、`promptWeightScrollSettingsProvider`（`lib/presentation/providers/generation/generation_settings_notifiers.dart`）、`notificationSettingsNotifierProvider`（`lib/presentation/providers/notification_settings_provider.dart`）、`localStorageServiceProvider` + `StorageKeys.queueRetryCount`/`StorageKeys.queueRetryInterval`
- Produces: 改造后的 `GenerationSettingsSection`（Task 7 导航使用，类名不变）

**迁移来源（本任务不改动来源文件）：** 重试次数/间隔的滑条行、`_buildSettingsInputDecoration`、`_buildSettingsSliderTheme` 来自 `queue_settings_section.dart`；音效开关与自定义音效来自 `notification_settings_section.dart`。

- [ ] **Step 1: 写失败测试**

新建 `test/presentation/screens/settings/sections/generation_settings_section_test.dart`：

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/generation_settings_section.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('generation_settings_hive_');
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: GenerationSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('按任务流展示输入、重试、提醒三个小节', (tester) async {
    await pumpSection(tester);

    // 小节标题
    expect(find.text('输入'), findsOneWidget);
    expect(find.text('失败重试'), findsOneWidget);
    expect(find.text('完成提醒'), findsOneWidget);

    // 原有输入行为设置仍在
    expect(find.text('显示随机提示词工具'), findsOneWidget);
    expect(find.text('滚轮调整提示词权重'), findsOneWidget);

    // 自队列迁入的重试设置
    expect(find.text('重试次数'), findsOneWidget);
    expect(find.text('重试间隔'), findsOneWidget);

    // 自通知迁入的完成提示音
    expect(find.text('完成音效'), findsOneWidget);
  });

  testWidgets('音效开关关闭时隐藏自定义音效入口', (tester) async {
    await pumpSection(tester);

    // 默认开启，自定义音效入口可见
    expect(find.text('自定义音效'), findsOneWidget);

    await tester.ensureVisible(find.text('完成音效'));
    await tester.tap(find.text('完成音效'));
    await tester.pumpAndSettle();

    expect(find.text('自定义音效'), findsNothing);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/presentation/screens/settings/sections/generation_settings_section_test.dart
```

Expected: FAIL（找不到 '失败重试'、'完成音效' 等文案——现版 section 只有两个开关）。

- [ ] **Step 3: 重写 generation_settings_section.dart**

整文件替换为：

```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../providers/generation/generation_settings_notifiers.dart';
import '../../../providers/notification_settings_provider.dart';
import '../../../widgets/common/themed_input.dart';
import '../widgets/settings_card.dart';
import '../widgets/settings_section_label.dart';

/// 构建标准输入框装饰（自原队列设置迁入）
InputDecoration _buildSettingsInputDecoration(
  ThemeData theme, {
  String? labelText,
  String? hintText,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide:
          BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
    ),
  );
}

/// 构建标准滑条主题（自原队列设置迁入）
SliderThemeData _buildSettingsSliderTheme(BuildContext context) {
  return SliderTheme.of(context).copyWith(
    trackHeight: 4,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
  );
}

/// 生成设置板块
///
/// 按生成任务流组织：输入行为 → 失败重试 → 完成提醒。
class GenerationSettingsSection extends ConsumerStatefulWidget {
  const GenerationSettingsSection({super.key});

  @override
  ConsumerState<GenerationSettingsSection> createState() =>
      _GenerationSettingsSectionState();
}

class _GenerationSettingsSectionState
    extends ConsumerState<GenerationSettingsSection> {
  late final TextEditingController _retryCountController;
  late final TextEditingController _retryIntervalController;

  @override
  void initState() {
    super.initState();
    _retryCountController = TextEditingController();
    _retryIntervalController = TextEditingController();
  }

  @override
  void dispose() {
    _retryCountController.dispose();
    _retryIntervalController.dispose();
    super.dispose();
  }

  void _updateRetryCount(int value) async {
    final storage = ref.read(localStorageServiceProvider);
    final clampedValue = value.clamp(1, 30);
    await storage.setSetting(StorageKeys.queueRetryCount, clampedValue);
    ref.invalidate(localStorageServiceProvider);
  }

  void _updateRetryInterval(double value) async {
    final storage = ref.read(localStorageServiceProvider);
    final clampedValue = value.clamp(0.5, 10.0);
    await storage.setSetting(StorageKeys.queueRetryInterval, clampedValue);
    ref.invalidate(localStorageServiceProvider);
  }

  Future<void> _selectCustomSound(
    NotificationSettingsNotifier notifier,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a'],
    );
    if (result != null && result.files.single.path != null) {
      await notifier.setCustomSoundPath(result.files.single.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final showRandomTools = ref.watch(randomPromptToolsVisibilityProvider);
    final promptWeightScrollEnabled = ref.watch(
      promptWeightScrollSettingsProvider,
    );
    final storage = ref.watch(localStorageServiceProvider);
    final notificationSettings =
        ref.watch(notificationSettingsNotifierProvider);
    final notificationNotifier =
        ref.read(notificationSettingsNotifierProvider.notifier);

    final retryCount = storage.getSetting<int>(
          StorageKeys.queueRetryCount,
          defaultValue: 10,
        ) ??
        10;
    final retryInterval = storage.getSetting<double>(
          StorageKeys.queueRetryInterval,
          defaultValue: 1.0,
        ) ??
        1.0;

    // 同步输入框文本（仅当未聚焦时更新，避免编辑中被覆盖）
    if (_retryCountController.text != '$retryCount') {
      _retryCountController.text = '$retryCount';
    }
    if (_retryIntervalController.text != retryInterval.toStringAsFixed(1)) {
      _retryIntervalController.text = retryInterval.toStringAsFixed(1);
    }

    return SettingsCard(
      title: l10n.settings_generation,
      icon: Icons.tune_outlined,
      child: Column(
        children: [
          SettingsSectionLabel(l10n.settings_generationInputSection),
          SwitchListTile(
            secondary: const Icon(Icons.casino_outlined),
            title: Text(l10n.settings_showRandomPromptTools),
            subtitle: Text(l10n.settings_showRandomPromptToolsSubtitle),
            value: showRandomTools,
            onChanged: (value) {
              ref.read(randomPromptToolsVisibilityProvider.notifier).set(value);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.mouse_outlined),
            title: Text(l10n.settings_enablePromptWeightScroll),
            subtitle: Text(l10n.settings_enablePromptWeightScrollSubtitle),
            value: promptWeightScrollEnabled,
            onChanged: (value) async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              try {
                await ref
                    .read(promptWeightScrollSettingsProvider.notifier)
                    .set(value);
              } catch (error) {
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text(l10n.globalSettings_saveFailed('$error')),
                  ),
                );
              }
            },
          ),
          SettingsSectionLabel(l10n.settings_generationRetrySection),
          _buildRetrySliderRow(
            theme: theme,
            label: l10n.settings_queueRetryCount,
            valueLabel: l10n.settings_queueRetryCountMax(
              retryCount.toString(),
            ),
            value: retryCount.toDouble(),
            min: 1,
            max: 30,
            unit: l10n.unit_times,
            controller: _retryCountController,
            onDecrease: retryCount > 1
                ? () => _updateRetryCount(retryCount - 1)
                : null,
            onIncrease: retryCount < 30
                ? () => _updateRetryCount(retryCount + 1)
                : null,
            onSliderChanged: (value) => _updateRetryCount(value.round()),
            onSubmitted: (value) {
              final parsed = int.tryParse(value);
              if (parsed != null) {
                _updateRetryCount(parsed);
              } else {
                _retryCountController.text = '$retryCount';
              }
            },
          ),
          _buildRetrySliderRow(
            theme: theme,
            label: l10n.settings_queueRetryInterval,
            valueLabel: l10n.settings_queueRetryIntervalValue(
              retryInterval.toStringAsFixed(1),
            ),
            value: retryInterval,
            min: 0.5,
            max: 10.0,
            unit: l10n.unit_seconds,
            controller: _retryIntervalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onDecrease: retryInterval > 0.5
                ? () => _updateRetryInterval(retryInterval - 0.5)
                : null,
            onIncrease: retryInterval < 10.0
                ? () => _updateRetryInterval(retryInterval + 0.5)
                : null,
            onSliderChanged: (value) =>
                _updateRetryInterval((value * 2).round() / 2),
            onSubmitted: (value) {
              final parsed = double.tryParse(value);
              if (parsed != null) {
                _updateRetryInterval(parsed);
              } else {
                _retryIntervalController.text =
                    retryInterval.toStringAsFixed(1);
              }
            },
          ),
          SettingsSectionLabel(l10n.settings_generationFeedbackSection),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: Text(l10n.settings_notificationSound),
            subtitle: Text(l10n.settings_notificationSoundSubtitle),
            value: notificationSettings.soundEnabled,
            onChanged: (value) => notificationNotifier.setSoundEnabled(value),
          ),
          if (notificationSettings.soundEnabled)
            ListTile(
              leading: const Icon(Icons.audiotrack_outlined),
              title: Text(l10n.settings_notificationCustomSound),
              subtitle: Text(
                notificationSettings.customSoundPath != null
                    ? Uri.file(notificationSettings.customSoundPath!)
                        .pathSegments
                        .last
                    : l10n.settings_notificationSelectSound,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (notificationSettings.customSoundPath != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: l10n.settings_notificationResetSound,
                      onPressed: () =>
                          notificationNotifier.setCustomSoundPath(null),
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => _selectCustomSound(notificationNotifier),
            ),
        ],
      ),
    );
  }

  Widget _buildRetrySliderRow({
    required ThemeData theme,
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required String unit,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.number,
    VoidCallback? onDecrease,
    VoidCallback? onIncrease,
    required ValueChanged<double> onSliderChanged,
    required ValueChanged<String> onSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                Text(
                  valueLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            visualDensity: VisualDensity.compact,
            onPressed: onDecrease,
          ),
          Expanded(
            child: SliderTheme(
              data: _buildSettingsSliderTheme(context),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onSliderChanged,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            visualDensity: VisualDensity.compact,
            onPressed: onIncrease,
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 56,
            child: ThemedInput(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: TextAlign.center,
              decoration: _buildSettingsInputDecoration(theme),
              onSubmitted: onSubmitted,
            ),
          ),
          const SizedBox(width: 4),
          Text(unit),
        ],
      ),
    );
  }
}
```

实现要点：
- 原通知设置里用 `dart:io` 的 `Platform.pathSeparator` 截文件名，这里改用 `Uri.file(...).pathSegments.last`（跨平台等价，同时避免只为一个分隔符 import `dart:io`）。若实现时发现 Windows 反斜杠路径 `Uri.file` 处理有误，回退为与原实现一致的 `split(Platform.pathSeparator).last` 并加回 `import 'dart:io';`。
- 两个重试行合并进同一张卡，原 `queue_settings_section.dart` 的两张独立卡样式不保留；滑条行结构（80px 标题列 + 加减按钮 + 滑条 + 数字输入 + 单位）原样保留。

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/presentation/screens/settings/sections/generation_settings_section_test.dart
flutter analyze
```

Expected: 2 个测试 PASS；analyze 无新增告警。

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/settings/sections/generation_settings_section.dart test/presentation/screens/settings/sections/generation_settings_section_test.dart
git commit -m "feat(settings): fold retry and completion sound into generation section"
```

---

### Task 3: 外观分类迁入悬浮球背景

**Files:**
- Modify: `lib/presentation/screens/settings/sections/appearance_settings_section.dart`
- Test: `test/presentation/screens/settings/sections/appearance_settings_section_test.dart`（新建）

**Interfaces:**
- Consumes: `localStorageServiceProvider` 的 `getFloatingButtonBackgroundImage()` / `setFloatingButtonBackgroundImage(String?)`（既有 API，来自 `lib/core/storage/local_storage_service.dart`）
- Produces: 改造后的 `AppearanceSettingsSection`（Task 7 使用，类名不变）

**迁移来源（本任务不改动来源文件）：** 悬浮球背景 UI 与 `_selectBackgroundImage`/`_clearBackgroundImage`/`_loadBackgroundImage` 来自 `queue_settings_section.dart`。

- [ ] **Step 1: 写失败测试**

新建 `test/presentation/screens/settings/sections/appearance_settings_section_test.dart`：

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/appearance_settings_section.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('appearance_settings_hive_');
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  testWidgets('外观分类包含悬浮球背景设置', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: AppearanceSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 原有项仍在
    expect(find.text('生成页布局'), findsOneWidget);
    // 自队列迁入的悬浮球背景
    expect(find.text('悬浮球背景'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/presentation/screens/settings/sections/appearance_settings_section_test.dart
```

Expected: FAIL（找不到 '悬浮球背景'）。

- [ ] **Step 3: 修改 appearance_settings_section.dart**

3a. 文件顶部 import 区追加（保持既有 import 不动）：

```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../../../core/storage/local_storage_service.dart';
```

3b. 在 `AppearanceSettingsSection` 的 `SettingsCard` 的 `Column` children 末尾（`settings_generationLayout` 的 `ListTile` 之后）追加一项：

```dart
          // 悬浮球背景图片（自原队列设置迁入）
          const _FloatingButtonBackgroundTile(),
```

3c. 在文件末尾追加私有 widget（逻辑自 `queue_settings_section.dart` 原样迁入，仅把独立 SettingsCard 外壳换成卡内行）：

```dart
/// 悬浮球背景图片设置行
class _FloatingButtonBackgroundTile extends ConsumerStatefulWidget {
  const _FloatingButtonBackgroundTile();

  @override
  ConsumerState<_FloatingButtonBackgroundTile> createState() =>
      _FloatingButtonBackgroundTileState();
}

class _FloatingButtonBackgroundTileState
    extends ConsumerState<_FloatingButtonBackgroundTile> {
  String? _backgroundImagePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final storage = ref.read(localStorageServiceProvider);
        setState(() {
          _backgroundImagePath = storage.getFloatingButtonBackgroundImage();
        });
      }
    });
  }

  Future<void> _selectBackgroundImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        final storage = ref.read(localStorageServiceProvider);
        await storage.setFloatingButtonBackgroundImage(path);
        setState(() {
          _backgroundImagePath = path;
        });
        ref.invalidate(localStorageServiceProvider);
      }
    }
  }

  Future<void> _clearBackgroundImage() async {
    final storage = ref.read(localStorageServiceProvider);
    await storage.setFloatingButtonBackgroundImage(null);
    setState(() {
      _backgroundImagePath = null;
    });
    ref.invalidate(localStorageServiceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.settings_floatingButtonBackground),
                Text(
                  _backgroundImagePath != null
                      ? l10n.settings_floatingButtonBackgroundCustom
                      : l10n.settings_floatingButtonBackgroundDefault,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                if (_backgroundImagePath != null)
                  Text(
                    _backgroundImagePath!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_backgroundImagePath != null)
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: ClipOval(
                child: Image.file(
                  File(_backgroundImagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
          if (_backgroundImagePath != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: l10n.settings_clearBackground,
              onPressed: _clearBackgroundImage,
            ),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.folder_open, size: 18),
            label: Text(l10n.settings_selectImage),
            onPressed: _selectBackgroundImage,
          ),
        ],
      ),
    );
  }
}
```

注意：原队列版行首文案直接显示"自定义/默认"，迁入版补了一行主标题 `settings_floatingButtonBackground`（原来这个文案是卡片标题，迁入后卡片标题不存在，需降为行标题——这是唯一的展示层调整，不改行为）。

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/presentation/screens/settings/sections/appearance_settings_section_test.dart
flutter analyze
```

Expected: PASS；analyze 无新增告警。

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/settings/sections/appearance_settings_section.dart test/presentation/screens/settings/sections/appearance_settings_section_test.dart
git commit -m "feat(settings): move floating button background into appearance"
```

---

### Task 4: 新建"安全与分享"分类

**Files:**
- Create: `lib/presentation/screens/settings/sections/privacy_settings_section.dart`
- Test: `test/presentation/screens/settings/sections/privacy_settings_section_test.dart`（新建）

**Interfaces:**
- Consumes: `shareImageSettingsProvider`（`lib/presentation/providers/share_image_settings_provider.dart`）、`OnlineGalleryBlacklistSettingsPanel`（`lib/presentation/widgets/online_gallery/blacklist_settings_panel.dart`）、`SettingsSectionLabel`（Task 1）、l10n `settings_privacySharing`（Task 1）
- Produces: `PrivacySettingsSection`（无参 const 构造，Task 7 使用）

**迁移来源（本任务不改动来源文件）：** 保护模式块与 `_editHighAnlasThreshold` 来自 `storage_settings_section.dart`；黑名单面板引用方式来自 `data_source_settings_section.dart`。

- [ ] **Step 1: 写失败测试**

新建 `test/presentation/screens/settings/sections/privacy_settings_section_test.dart`：

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/privacy_settings_section.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/blacklist_settings_panel.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('privacy_settings_hive_');
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: PrivacySettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('包含保护模式与在线画廊黑名单', (tester) async {
    await pumpSection(tester);

    expect(find.text('保护模式'), findsOneWidget);
    expect(find.text('保护功能'), findsOneWidget);
    expect(find.text('复制/拖拽时移除全部元数据'), findsOneWidget);
    expect(find.byType(OnlineGalleryBlacklistSettingsPanel), findsOneWidget);
  });

  testWidgets('保护模式关闭时子开关不可用', (tester) async {
    await pumpSection(tester);

    // 保护模式默认开启，先关闭
    await tester.tap(find.text('保护模式'));
    await tester.pumpAndSettle();

    final stripTile = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('复制/拖拽时移除全部元数据'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(stripTile.onChanged, isNull);
  });
}
```

注意：若 `shareImageSettingsProvider` 的保护模式默认值为关闭，第二个测试改为直接断言 `onChanged == null` 而无需先点击——以第一次运行的实际失败信息为准调整（provider 默认值见 `share_image_settings_provider.dart`）。

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/presentation/screens/settings/sections/privacy_settings_section_test.dart
```

Expected: FAIL（`privacy_settings_section.dart` 不存在，编译错误）。

- [ ] **Step 3: 创建 privacy_settings_section.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/share_image_settings_provider.dart';
import '../../../widgets/online_gallery/blacklist_settings_panel.dart';
import '../widgets/settings_card.dart';
import '../widgets/settings_section_label.dart';

/// 安全与分享设置板块
///
/// 集中管理保护模式（分享脱敏、危险操作确认、高消耗警告等）
/// 与在线画廊内容屏蔽。
class PrivacySettingsSection extends ConsumerStatefulWidget {
  const PrivacySettingsSection({super.key});

  @override
  ConsumerState<PrivacySettingsSection> createState() =>
      _PrivacySettingsSectionState();
}

class _PrivacySettingsSectionState
    extends ConsumerState<PrivacySettingsSection> {
  Future<void> _editHighAnlasThreshold() async {
    final settings = ref.read(shareImageSettingsProvider);
    final controller = TextEditingController(
      text: settings.highAnlasCostThreshold.toString(),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_setHighAnlasCostThresholdTitle),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.settings_threshold,
            suffixText: 'Anlas',
            helperText: context.l10n.settings_highAnlasCostThresholdHelper,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value > 0) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            child: Text(context.l10n.common_save),
          ),
        ],
      ),
    );

    controller.dispose();
    if (result == null) {
      return;
    }
    await ref
        .read(shareImageSettingsProvider.notifier)
        .setHighAnlasCostThreshold(result);
  }

  @override
  Widget build(BuildContext context) {
    final shareSettings = ref.watch(shareImageSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCard(
          title: context.l10n.settings_privacySharing,
          icon: Icons.shield_outlined,
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.shield_outlined),
                title: Text(context.l10n.settings_protectionMode),
                subtitle: Text(context.l10n.settings_protectionModeSubtitle),
                value: shareSettings.protectionMode,
                onChanged: (value) async {
                  await ref
                      .read(shareImageSettingsProvider.notifier)
                      .setProtectionMode(value);
                },
              ),
              SettingsSectionLabel(context.l10n.settings_protectionFeatures),
              SwitchListTile(
                secondary: const Icon(Icons.cleaning_services_outlined),
                title: Text(context.l10n.settings_stripMetadataTitle),
                subtitle: Text(context.l10n.settings_stripMetadataSubtitle),
                value: shareSettings.stripMetadataForCopyAndDrag,
                onChanged: shareSettings.protectionMode
                    ? (value) async {
                        await ref
                            .read(shareImageSettingsProvider.notifier)
                            .setStripMetadataForCopyAndDrag(value);
                      }
                    : null,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.warning_amber_rounded),
                title: Text(
                  context.l10n.settings_confirmDangerousActionsTitle,
                ),
                subtitle: Text(
                  context.l10n.settings_confirmDangerousActionsSubtitle,
                ),
                value: shareSettings.confirmDangerousActions,
                onChanged: shareSettings.protectionMode
                    ? (value) async {
                        await ref
                            .read(shareImageSettingsProvider.notifier)
                            .setConfirmDangerousActions(value);
                      }
                    : null,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.cloud_upload_outlined),
                title: Text(context.l10n.settings_warnExternalImageSendTitle),
                subtitle: Text(
                  context.l10n.settings_warnExternalImageSendSubtitle,
                ),
                value: shareSettings.warnExternalImageSend,
                onChanged: shareSettings.protectionMode
                    ? (value) async {
                        await ref
                            .read(shareImageSettingsProvider.notifier)
                            .setWarnExternalImageSend(value);
                      }
                    : null,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.file_copy_outlined),
                title: Text(context.l10n.settings_preventOverwriteTitle),
                subtitle: Text(context.l10n.settings_preventOverwriteSubtitle),
                value: shareSettings.preventOverwrite,
                onChanged: shareSettings.protectionMode
                    ? (value) async {
                        await ref
                            .read(shareImageSettingsProvider.notifier)
                            .setPreventOverwrite(value);
                      }
                    : null,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.toll_outlined),
                title: Text(context.l10n.settings_warnHighAnlasCostTitle),
                subtitle: Text(
                  context.l10n.settings_warnHighAnlasCostSubtitle(
                    shareSettings.highAnlasCostThreshold,
                  ),
                ),
                value: shareSettings.warnHighAnlasCost,
                onChanged: shareSettings.protectionMode
                    ? (value) async {
                        await ref
                            .read(shareImageSettingsProvider.notifier)
                            .setWarnHighAnlasCost(value);
                      }
                    : null,
              ),
              ListTile(
                enabled: shareSettings.protectionMode &&
                    shareSettings.warnHighAnlasCost,
                leading: const Icon(Icons.speed_outlined),
                title: Text(
                  context.l10n.settings_highAnlasCostThresholdTitle,
                ),
                subtitle:
                    Text('${shareSettings.highAnlasCostThreshold} Anlas'),
                trailing: const Icon(Icons.chevron_right),
                onTap: shareSettings.protectionMode &&
                        shareSettings.warnHighAnlasCost
                    ? _editHighAnlasThreshold
                    : null,
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: OnlineGalleryBlacklistSettingsPanel(),
        ),
      ],
    );
  }
}
```

与原 storage 版的差异（有意为之，其余原样）：
- "保护功能"标题由手写 `Padding`+`Text` 换成 `SettingsSectionLabel`（样式一致）。
- 保护模式开关补了 `secondary` 图标（原缺失，与同卡其他行对齐）。

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/presentation/screens/settings/sections/privacy_settings_section_test.dart
flutter analyze
```

Expected: 2 个测试 PASS；analyze 无新增告警。

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/settings/sections/privacy_settings_section.dart test/presentation/screens/settings/sections/privacy_settings_section_test.dart
git commit -m "feat(settings): add privacy & sharing section"
```

---

### Task 5: 存储分类改造为"数据与存储"

**Files:**
- Modify: `lib/presentation/screens/settings/sections/storage_settings_section.dart`
- Test: `test/presentation/screens/settings/sections/storage_settings_section_test.dart`（新建）

**Interfaces:**
- Consumes: `DataSourceCacheSettings`（`lib/presentation/screens/settings/widgets/data_source_cache_settings.dart`，自带卡片外观）、l10n `settings_dataStorage`（Task 1）
- Produces: 改造后的 `StorageSettingsSection`（文件名、类名不变，Task 7 使用）

- [ ] **Step 1: 写失败测试**

新建 `test/presentation/screens/settings/sections/storage_settings_section_test.dart`：

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/storage_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/data_source_cache_settings.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('storage_settings_hive_');
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  testWidgets('聚焦数据与存储：保护模式移出，数据源缓存迁入', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: StorageSettingsSection()),
          ),
        ),
      ),
    );
    // DataSourceCacheSettings 内部有异步 provider，首帧后再 pump 一次即可
    await tester.pump();

    // 标题更新
    expect(find.text('数据与存储'), findsOneWidget);
    // 保留的存储项
    expect(find.text('图片保存位置'), findsOneWidget);
    expect(find.text('自动保存'), findsOneWidget);
    // 保护模式已移出
    expect(find.text('保护模式'), findsNothing);
    expect(find.text('复制/拖拽时移除全部元数据'), findsNothing);
    // 数据源缓存迁入
    expect(find.byType(DataSourceCacheSettings), findsOneWidget);
  });
}
```

注意：`DataSourceCacheSettings` watch `danbooruTagsCacheNotifierProvider`（AsyncValue），未完成时渲染加载态，不影响 `byType` 断言；因此用 `tester.pump()` 而非 `pumpAndSettle()`（后者可能因持续异步而超时——若实际可 settle 则换回 `pumpAndSettle` 亦可）。

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/presentation/screens/settings/sections/storage_settings_section_test.dart
```

Expected: FAIL（'数据与存储' 找不到，'保护模式' findsOneWidget 与 findsNothing 冲突）。

- [ ] **Step 3: 修改 storage_settings_section.dart**

3a. 删除以下内容：
- import `'../../../providers/share_image_settings_provider.dart'`
- `_editHighAnlasThreshold()` 方法整个（97-142 行区域）
- build 中 `final shareSettings = ref.watch(shareImageSettingsProvider);` 一行
- build 的 Column children 中从"保护模式 SwitchListTile"到"高 Anlas 阈值 ListTile"整块（原 227-329 行区域：`settings_protectionMode` 开关、`settings_protectionFeatures` 标题 Padding、5 个保护子开关、阈值 ListTile）

3b. 标题替换：

```dart
    return SettingsCard(
      title: context.l10n.settings_storage,
```
改为
```dart
    return SettingsCard(
      title: context.l10n.settings_dataStorage,
```

3c. 迁入数据源缓存：import 区追加

```dart
import '../widgets/data_source_cache_settings.dart';
```

并把 build 的返回值从单个 `SettingsCard` 包一层 Column（`DataSourceCacheSettings` 自带卡片样式，必须放在 `SettingsCard` 外面，避免双重卡片——原 `data_source_settings_section.dart` 的注释已说明）：

```dart
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCard(
          title: context.l10n.settings_dataStorage,
          icon: Icons.storage,
          child: Column(
            children: [
              // ……保留的原有 children（图片保存路径、自动保存、
              // ONNX Tagger、VibeLibraryPathTile、HiveStoragePathTile、
              // CacheStatisticsTile、GalleryCacheActions 及原有 Divider）……
            ],
          ),
        ),
        const DataSourceCacheSettings(),
      ],
    );
```

删除保护块后，原"自动保存"开关与"ONNX Tagger"行之间残留的 `const Divider(height: 24)` 保留一个即可（自动保存与路径配置组之间的视觉分隔）。

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/presentation/screens/settings/sections/storage_settings_section_test.dart
flutter analyze
```

Expected: PASS；analyze 无新增告警（特别确认无 unused import）。

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/settings/sections/storage_settings_section.dart test/presentation/screens/settings/sections/storage_settings_section_test.dart
git commit -m "refactor(settings): focus storage section on data & storage"
```

---

### Task 6: 新建"集成"分类（页内子导航）

**Files:**
- Create: `lib/presentation/screens/settings/sections/integrations_settings_section.dart`
- Test: `test/presentation/screens/settings/sections/integrations_settings_section_test.dart`（新建）

**Interfaces:**
- Consumes: `PromptAssistantSettingsSection` / `ComfyUISettingsSection` / `KritaBridgeSettingsSection`（三个既有 section，原样复用不改动）
- Produces: `IntegrationsSettingsSection({List<WidgetBuilder>? panelBuilders})`（Task 7 使用；`panelBuilders` 仅测试注入用）

- [ ] **Step 1: 写失败测试**

新建 `test/presentation/screens/settings/sections/integrations_settings_section_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/integrations_settings_section.dart';

void main() {
  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: IntegrationsSettingsSection(
            panelBuilders: [
              (_) => const Text('panel-prompt-assistant'),
              (_) => const Text('panel-comfyui'),
              (_) => const Text('panel-krita'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('默认显示第一个面板且三段可切换', (tester) async {
    await pumpSection(tester);

    // 三段子导航
    expect(find.text('Prompt Assistant'), findsOneWidget);
    expect(find.text('ComfyUI'), findsOneWidget);
    expect(find.text('Krita'), findsOneWidget);

    // 默认渲染第一个面板，且一次只渲染一个
    expect(find.text('panel-prompt-assistant'), findsOneWidget);
    expect(find.text('panel-comfyui'), findsNothing);

    await tester.tap(find.text('ComfyUI'));
    await tester.pumpAndSettle();
    expect(find.text('panel-comfyui'), findsOneWidget);
    expect(find.text('panel-prompt-assistant'), findsNothing);

    await tester.tap(find.text('Krita'));
    await tester.pumpAndSettle();
    expect(find.text('panel-krita'), findsOneWidget);
    expect(find.text('panel-comfyui'), findsNothing);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/presentation/screens/settings/sections/integrations_settings_section_test.dart
```

Expected: FAIL（文件不存在，编译错误）。

- [ ] **Step 3: 创建 integrations_settings_section.dart**

```dart
import 'package:flutter/material.dart';

import 'comfyui_settings_section.dart';
import 'krita_bridge_settings_section.dart';
import 'prompt_assistant_settings_section.dart';

/// 集成设置板块
///
/// 汇总外部工具集成（Prompt Assistant / ComfyUI / Krita）。
/// 顶部子导航切换，一次只渲染一个面板，避免长滚动页。
class IntegrationsSettingsSection extends StatefulWidget {
  /// 测试注入用面板构造器；生产环境保持 null 使用默认三面板。
  @visibleForTesting
  final List<WidgetBuilder>? panelBuilders;

  const IntegrationsSettingsSection({super.key, this.panelBuilders});

  @override
  State<IntegrationsSettingsSection> createState() =>
      _IntegrationsSettingsSectionState();
}

class _IntegrationsSettingsSectionState
    extends State<IntegrationsSettingsSection> {
  // 专有名词标签，不进 l10n（与原导航中 ComfyUI/Krita 标签一致）
  static const _labels = ['Prompt Assistant', 'ComfyUI', 'Krita'];

  int _selectedIndex = 0;

  List<WidgetBuilder> get _builders =>
      widget.panelBuilders ??
      [
        (_) => const PromptAssistantSettingsSection(),
        (_) => const ComfyUISettingsSection(),
        (_) => const KritaBridgeSettingsSection(),
      ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: SegmentedButton<int>(
              segments: [
                for (var i = 0; i < _labels.length; i++)
                  ButtonSegment(value: i, label: Text(_labels[i])),
              ],
              selected: {_selectedIndex},
              onSelectionChanged: (selection) {
                setState(() => _selectedIndex = selection.first);
              },
            ),
          ),
        ),
        _builders[_selectedIndex](context),
      ],
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/presentation/screens/settings/sections/integrations_settings_section_test.dart
flutter analyze
```

Expected: PASS；analyze 无新增告警。

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/settings/sections/integrations_settings_section.dart test/presentation/screens/settings/sections/integrations_settings_section_test.dart
git commit -m "feat(settings): add integrations section with sub navigation"
```

---

### Task 7: 导航切换到 9 类并删除废弃 section

**Files:**
- Modify: `lib/presentation/screens/settings/settings_screen.dart:4-134`（import 区与 `_buildSections`）
- Delete: `lib/presentation/screens/settings/sections/queue_settings_section.dart`、`lib/presentation/screens/settings/sections/notification_settings_section.dart`、`lib/presentation/screens/settings/sections/data_source_settings_section.dart`
- Test: `test/presentation/screens/settings/settings_screen_test.dart`（新建）

**Interfaces:**
- Consumes: Task 2-6 产出的全部 section；`AuthNotifier`/`AuthState`/`AuthStatus`（`lib/presentation/providers/auth_provider.dart`）、`AccountManagerNotifier`/`AccountManagerState`（`lib/presentation/providers/account_manager_provider.dart`）、`SubscriptionNotifier`（`lib/presentation/providers/subscription_provider.dart`）、`SubscriptionStateInitial`（`lib/data/models/user/user_subscription.dart`）
- Produces: 9 类导航的 `SettingsScreen`（对外接口不变，仍由 `/settings` 路由整页打开）

- [ ] **Step 1: 写失败测试**

新建 `test/presentation/screens/settings/settings_screen_test.dart`：

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/settings_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _FakeAccountManagerNotifier extends AccountManagerNotifier {
  @override
  AccountManagerState build() => const AccountManagerState();
}

class _FakeSubscriptionNotifier extends SubscriptionNotifier {
  @override
  SubscriptionState build() => const SubscriptionStateInitial();
}

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('settings_screen_hive_');
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  testWidgets('设置页导航为 9 个分类', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          accountManagerNotifierProvider.overrideWith(
            _FakeAccountManagerNotifier.new,
          ),
          subscriptionNotifierProvider.overrideWith(
            _FakeSubscriptionNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations.length, 9);

    // 新分类标签（当前选中账号页，其余 section 未构建，导航标签唯一）
    expect(find.text('数据与存储'), findsOneWidget);
    expect(find.text('安全与分享'), findsOneWidget);
    expect(find.text('集成'), findsOneWidget);

    // 撤销的分类不再出现
    expect(find.text('队列'), findsNothing);
    expect(find.text('通知'), findsNothing);
    expect(find.text('数据源'), findsNothing);
    expect(find.text('ComfyUI'), findsNothing);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/presentation/screens/settings/settings_screen_test.dart
```

Expected: FAIL（destinations.length 为 13，'队列' 等仍存在）。

- [ ] **Step 3: 修改 settings_screen.dart**

3a. import 区（第 4-17 行）替换为：

```dart
import '../../../core/utils/localization_extension.dart';
import 'sections/account_settings_section.dart';
import 'sections/appearance_settings_section.dart';
import 'sections/generation_settings_section.dart';
import 'sections/storage_settings_section.dart';
import 'sections/privacy_settings_section.dart';
import 'sections/network_settings_section.dart';
import 'sections/shortcut_settings_section.dart';
import 'sections/integrations_settings_section.dart';
import 'sections/about_settings_section.dart';
```

3b. `_buildSections`（第 53-134 行）替换为：

```dart
  List<_SettingsSection> _buildSections(BuildContext context) {
    return [
      _SettingsSection(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: context.l10n.settings_account,
        widget: const AccountSettingsSection(),
      ),
      _SettingsSection(
        icon: Icons.palette_outlined,
        selectedIcon: Icons.palette,
        label: context.l10n.settings_appearance,
        widget: const AppearanceSettingsSection(),
      ),
      _SettingsSection(
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune,
        label: context.l10n.settings_generation,
        widget: const GenerationSettingsSection(),
      ),
      _SettingsSection(
        icon: Icons.storage_outlined,
        selectedIcon: Icons.storage,
        label: context.l10n.settings_dataStorage,
        widget: const StorageSettingsSection(),
      ),
      _SettingsSection(
        icon: Icons.shield_outlined,
        selectedIcon: Icons.shield,
        label: context.l10n.settings_privacySharing,
        widget: const PrivacySettingsSection(),
      ),
      _SettingsSection(
        icon: Icons.network_check_outlined,
        selectedIcon: Icons.network_check,
        label: context.l10n.settings_network,
        widget: const NetworkSettingsSection(),
      ),
      _SettingsSection(
        icon: Icons.keyboard_outlined,
        selectedIcon: Icons.keyboard,
        label: context.l10n.settings_shortcuts,
        widget: const ShortcutSettingsSection(),
      ),
      _SettingsSection(
        icon: Icons.extension_outlined,
        selectedIcon: Icons.extension,
        label: context.l10n.settings_integrations,
        widget: const IntegrationsSettingsSection(),
      ),
      _SettingsSection(
        icon: Icons.info_outlined,
        selectedIcon: Icons.info,
        label: context.l10n.settings_about,
        widget: const AboutSettingsSection(),
      ),
    ];
  }
```

3c. 删除三个废弃 section 文件：

```bash
git rm lib/presentation/screens/settings/sections/queue_settings_section.dart lib/presentation/screens/settings/sections/notification_settings_section.dart lib/presentation/screens/settings/sections/data_source_settings_section.dart
```

- [ ] **Step 4: 全局引用核查**

```bash
grep -rn "queue_settings_section\|notification_settings_section\|data_source_settings_section\|QueueSettingsSection\|NotificationSettingsSection\|DataSourceSettingsSection" lib/ test/
```

Expected: 无任何输出（若有残留引用，按引用处上下文改为新 section 或删除）。

- [ ] **Step 5: 运行测试确认通过**

```bash
flutter test test/presentation/screens/settings/settings_screen_test.dart
flutter analyze
```

Expected: PASS；analyze 无新增告警。

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/screens/settings/settings_screen.dart test/presentation/screens/settings/settings_screen_test.dart
git commit -m "feat(settings): reorganize settings navigation to 9 categories"
```

（`git rm` 的删除已在暂存区，随本次提交一并入库。）

---

### Task 8: 清理旧词条 + 全量验证

**Files:**
- Modify: `lib/l10n/app_zh.arb`、`lib/l10n/app_en.arb`、`lib/l10n/app_ja.arb`（各删 3 个 key）
- Regenerate: `lib/l10n/app_localizations*.dart`

**Interfaces:**
- Consumes: Task 7 完成后 `settings_dataSource`、`settings_queue`、`settings_notifications` 已无代码引用（已核实原先仅 `settings_screen.dart` 使用）

- [ ] **Step 1: 确认旧词条无引用**

```bash
grep -rn "settings_dataSource\b\|settings_queue\b\|settings_notifications\b" lib/ test/ --include="*.dart" | grep -v "app_localizations"
```

Expected: 无输出。若有输出（其他任务期间有人新增了引用），保留对应词条不删，仅删除确认无引用的。

- [ ] **Step 2: 三份 ARB 各删除 3 个 key**

从 `app_zh.arb`、`app_en.arb`、`app_ja.arb` 中删除以下三行（zh 版为例，位于 230-233 行区域）：

```json
  "settings_dataSource": "数据源",
  "settings_queue": "队列",
  "settings_notifications": "通知",
```

注意不要误删 `settings_dataSourceCacheTitle` 等带相同前缀的词条。

- [ ] **Step 3: 重新生成并验证编译**

```bash
flutter gen-l10n
flutter analyze
```

Expected: 均无错误。

- [ ] **Step 4: 全量验证（AGENTS.md 要求的完整步骤）**

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter analyze
flutter build windows --release
```

Expected: 全部通过。说明：本次未新增 Riverpod provider/Freezed model，`build_runner` 预期零 diff，运行仅为符合仓库验证规范；若产生无关 diff 不要提交。

- [ ] **Step 5: 手动冒烟（启动应用逐项确认）**

```bash
flutter run -d windows
```

检查清单：
1. 设置页导航为 9 项，顺序与图标正确；窄窗口（<600px）下 Drawer 列表同样为 9 项。
2. 生成页：三个小节标题渲染正常；调整重试次数/间隔后重进设置页数值保留；完成音效开关联动自定义音效行。
3. 外观页：选择悬浮球背景图片后预览出现，悬浮球实际背景更新；清除后恢复默认。
4. 安全与分享页：关闭保护模式后 5 个子开关与阈值行变灰；黑名单面板可正常增删。
5. 数据与存储页：无保护模式相关项；Danbooru 标签缓存卡片功能正常（同步/清除）。
6. 集成页：三段切换正常；ComfyUI 测试连接、Krita 桥接开关行为与改版前一致。
7. 关于页：文件日志开关、检查更新正常。

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/
git commit -m "chore(l10n): drop retired settings category labels"
```

---

## 计划自审记录

- **Spec 覆盖**：9 类结构（Task 7）、生成页三小节（Task 2）、悬浮球背景迁移（Task 3）、安全与分享新建（Task 4）、数据与存储改造（Task 5）、集成页子导航（Task 6）、l10n 三语词条与旧词条清理（Task 1/8）、文件级变更表全部对应；"无深链、无迁移"约束体现在 Global Constraints。
- **中间态说明**：Task 2-6 的重复展示与标签不一致已在 Global Constraints 声明为预期，Task 7 收敛。
- **类型一致性**：`PrivacySettingsSection`/`IntegrationsSettingsSection` 名称在 Task 4/6（定义）与 Task 7（引用）一致；`panelBuilders` 参数签名在 Task 6 定义与测试一致。
- **已知不确定点（实现时按 Step 说明就地处理）**：① 保护模式默认值影响 Task 4 第二个测试的前置点击；② `Uri.file` 截取文件名在 Windows 的表现（Task 2 已给回退方案）；③ Task 5 测试 `pump` vs `pumpAndSettle` 的选择。

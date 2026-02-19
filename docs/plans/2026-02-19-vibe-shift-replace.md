# Vibe Shift+点击替换功能实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现按住 Shift 点击"一键复用"按钮时替换现有 vibes，普通点击时追加 vibes，并在悬浮提示中显示 Shift 快捷键信息。

**Architecture:** 在业务逻辑层检测 `HardwareKeyboard.isShiftPressed` 状态，根据状态决定调用 `addVibeReferences`（追加）或 `setVibeReferences`（替换）。修改 `_ActionButton` 组件支持显示带修饰键信息的自定义提示。

**Tech Stack:** Flutter, Riverpod, 项目现有快捷键系统

---

### Task 1: 在 GenerationParamsNotifier 中添加 setVibeReferences 方法

**Files:**
- Modify: `lib/presentation/providers/image_generation_provider.dart`

**Step 1: 添加 setVibeReferences 方法**

在 `GenerationParamsNotifier` 类中添加替换 vibes 的方法（用于 Shift+点击时替换现有 vibes）：

```dart
/// 设置 vibe references（替换现有）
void setVibeReferences(List<VibeReference> vibes) {
  // 限制最多16个
  final limitedVibes = vibes.take(16).toList();
  state = state.copyWith(vibeReferencesV4: limitedVibes);
}
```

**Step 2: 提交**

```bash
git add lib/presentation/providers/image_generation_provider.dart
git commit -m "feat(vibe): 添加 setVibeReferences 方法用于替换 vibes"
```

---

### Task 2: 修改 VibeCard 的 _ActionButton 支持带修饰键信息的提示

**Files:**
- Modify: `lib/presentation/screens/vibe_library/widgets/vibe_card.dart`

**Step 1: 修改 _ActionButton 组件添加 modifierHint 参数**

修改 `_ActionButton` 类：

```dart
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final String? modifierHint; // 新增：修饰键提示，如 "Shift+点击 替换"
  final VoidCallback? onTap;
  final bool isDanger;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    this.modifierHint, // 新增
    this.onTap,
    this.isDanger = false,
  });
  // ...
}
```

**Step 2: 修改 _ActionButtonState 的 tooltip 显示逻辑**

在 `_ActionButtonState` 的 build 方法中，修改 tooltip 显示：

```dart
// 自定义 Tooltip
if (_showTooltip)
  Positioned(
    right: 40,
    top: 4,
    child: AnimatedOpacity(
      opacity: _showTooltip ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.88),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              widget.tooltip,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.modifierHint != null) ...[
              const SizedBox(height: 2),
              Text(
                widget.modifierHint!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  ),
```

**Step 3: 在 _buildActionButtons 中为 onSendToGeneration 按钮添加 modifierHint**

```dart
if (widget.onSendToGeneration != null)
  _ActionButton(
    icon: Icons.send,
    tooltip: context.l10n.vibe_reuseButton,
    modifierHint: 'Shift+点击 替换', // 新增
    onTap: widget.onSendToGeneration,
  ),
```

**Step 4: 提交**

```bash
git add lib/presentation/screens/vibe_library/widgets/vibe_card.dart
git commit -m "feat(vibe-card): _ActionButton 支持修饰键提示"
```

---

### Task 3: 在 vibe_library_screen.dart 中实现 Shift+点击替换逻辑

**Files:**
- Modify: `lib/presentation/screens/vibe_library/vibe_library_screen.dart`

**Step 1: 添加 HardwareKeyboard 导入**

```dart
import 'package:flutter/services.dart';
```

**Step 2: 修改 _sendEntryToGeneration 方法检测 Shift 键状态**

```dart
Future<void> _sendEntryToGeneration(BuildContext context, VibeLibraryEntry entry) async {
  final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);
  final currentParams = ref.read(generationParamsNotifierProvider);

  // 检测是否按住 Shift 键
  final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

  // 检查是否超过16个限制（仅在追加模式下检查）
  if (!isShiftPressed && currentParams.vibeReferencesV4.length >= 16) {
    AppToast.warning(context, '已达到最大数量 (16张)');
    return;
  }

  // 处理 Bundle 条目：从文件读取所有 vibes
  if (entry.isBundle && entry.filePath != null && entry.filePath!.isNotEmpty) {
    final file = File(entry.filePath!);
    if (await file.exists()) {
      try {
        final bytes = await file.readAsBytes();
        final fileName = p.basename(entry.filePath!);
        final vibes = await VibeFileParser.fromBundle(fileName, bytes);

        // 应用条目的 strength 和 infoExtracted 到所有 vibes
        final adjustedVibes = vibes
            .map(
              (vibe) => vibe.copyWith(
                strength: entry.strength,
                infoExtracted: entry.infoExtracted,
              ),
            )
            .toList();

        if (isShiftPressed) {
          // Shift+点击：替换现有 vibes
          paramsNotifier.setVibeReferences(adjustedVibes);
        } else {
          // 普通点击：追加 vibes
          paramsNotifier.addVibeReferences(adjustedVibes);
        }

        ref.read(vibeLibraryNotifierProvider.notifier).recordUsage(entry.id);
        if (context.mounted) {
          final message = isShiftPressed
              ? '已替换为 ${adjustedVibes.length} 个 Vibe: ${entry.displayName}'
              : '已发送 ${adjustedVibes.length} 个 Vibe 到生成页面: ${entry.displayName}';
          AppToast.success(context, message);
          context.go(AppRoutes.home);
        }
        return;
      } catch (e, stackTrace) {
        AppLogger.e('读取 Bundle 文件失败: ${entry.filePath}', e, stackTrace, 'VibeLibrary');
        // 回退到单个 vibe 处理
      }
    }
  }

  // 普通条目或 Bundle 文件不存在时，使用单个 vibe
  final vibeReference = entry.toVibeReference();
  if (isShiftPressed) {
    // Shift+点击：替换现有 vibes
    paramsNotifier.setVibeReferences([vibeReference]);
  } else {
    // 普通点击：追加 vibes
    paramsNotifier.addVibeReferences([vibeReference]);
  }

  ref.read(vibeLibraryNotifierProvider.notifier).recordUsage(entry.id);
  if (context.mounted) {
    final message = isShiftPressed
        ? '已替换为: ${entry.displayName}'
        : '已发送到生成页面: ${entry.displayName}';
    AppToast.success(context, message);
    context.go(AppRoutes.home);
  }
}
```

**Step 3: 提交**

```bash
git add lib/presentation/screens/vibe_library/vibe_library_screen.dart
git commit -m "feat(vibe): Shift+点击一键复用按钮时替换现有 vibes"
```

---

### Task 4: 在 vibe_detail_viewer.dart 中实现相同的 Shift+点击逻辑

**Files:**
- Modify: `lib/presentation/screens/vibe_library/widgets/vibe_detail_viewer.dart`

**Step 1: 添加 HardwareKeyboard 导入**

```dart
import 'package:flutter/services.dart';
```

**Step 2: 修改 _sendToGeneration 方法检测 Shift 键状态**

```dart
void _sendToGeneration() {
  // 检测是否按住 Shift 键
  final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

  widget.callbacks?.onSendToGeneration?.call(
    _entry,
    _strength,
    _infoExtracted,
    isShiftPressed, // 传递 Shift 状态
  );
  Navigator.of(context).pop();
}
```

**注意：** 这需要修改 `VibeDetailCallbacks` 的 `onSendToGeneration` 签名，添加 `isShiftPressed` 参数。

**Step 3: 修改 VibeDetailCallbacks 签名**

```dart
class VibeDetailCallbacks {
  /// 发送到生成页面回调
  final void Function(
    VibeLibraryEntry entry,
    double strength,
    double infoExtracted,
    bool isShiftPressed, // 新增参数
  )? onSendToGeneration;
  // ...
}
```

**Step 4: 提交**

```bash
git add lib/presentation/screens/vibe_library/widgets/vibe_detail_viewer.dart
git commit -m "feat(vibe-detail): 详情页支持 Shift+点击替换 vibes"
```

---

### Task 5: 更新 vibe_library_screen.dart 中的 VibeDetailCallbacks

**Files:**
- Modify: `lib/presentation/screens/vibe_library/vibe_library_screen.dart`

**Step 1: 修改 _showVibeDetail 中的 onSendToGeneration 回调**

```dart
callbacks: VibeDetailCallbacks(
  onSendToGeneration: (entry, strength, infoExtracted, isShiftPressed) async {
    await _sendEntryToGenerationWithParams(
      context,
      entry,
      strength,
      infoExtracted,
      isShiftPressed, // 传递 Shift 状态
    );
  },
  // ...
),
```

**Step 2: 修改 _sendEntryToGenerationWithParams 方法签名和逻辑**

```dart
Future<void> _sendEntryToGenerationWithParams(
  BuildContext context,
  VibeLibraryEntry entry,
  double strength,
  double infoExtracted,
  bool isShiftPressed, // 新增参数
) async {
  final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);
  final currentParams = ref.read(generationParamsNotifierProvider);

  // 仅在追加模式下检查限制
  if (!isShiftPressed && currentParams.vibeReferencesV4.length >= 16) {
    AppToast.warning(context, '已达到最大数量 (16张)');
    return;
  }

  // ... 处理 Bundle 逻辑 ...

  if (isShiftPressed) {
    paramsNotifier.setVibeReferences([adjustedVibe]);
  } else {
    paramsNotifier.addVibeReferences([adjustedVibe]);
  }

  // ... 其余逻辑 ...
}
```

**Step 3: 提交**

```bash
git add lib/presentation/screens/vibe_library/vibe_library_screen.dart
git commit -m "feat(vibe): 更新详情页回调支持 Shift 状态传递"
```

---

### Task 6: 运行 flutter analyze 检查代码

**Step 1: 运行分析**

```bash
/mnt/e/flutter/bin/flutter.bat analyze
```

**Step 2: 修复任何问题**

如果有分析错误，修复它们。

**Step 3: 最终提交**

```bash
git commit -m "refactor(vibe): 修复分析错误"
```

---

## 测试清单

- [ ] 普通点击"一键复用"按钮：vibes 被追加到现有列表
- [ ] 按住 Shift 点击"一键复用"按钮：vibes 替换现有列表
- [ ] Bundle 条目：Shift+点击正确替换所有子 vibes
- [ ] 悬浮提示显示 "Shift+点击 替换"
- [ ] 详情页的"发送到生成页面"按钮同样支持 Shift+点击
- [ ] 替换成功后显示 "已替换为..." 提示
- [ ] 追加成功后显示 "已发送..." 提示

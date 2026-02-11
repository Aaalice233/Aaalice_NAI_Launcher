# Vibe 导入对话框增强实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 unified_reference_panel.dart 中的 `_importFromLibrary()` 方法从简单 AlertDialog 列表改为使用 `VibeSelectorDialog`，支持多选、搜索、最近使用等功能

**Architecture:** 替换现有的简单列表对话框为已存在的 `VibeSelectorDialog` 组件。该组件提供网格视图、搜索、最近使用 Chips、多选、添加/替换模式切换等功能。修改后的导入流程将支持一次导入多个 Vibe，并保持使用统计更新。

**Tech Stack:** Flutter, Dart, Riverpod

---

## 前置信息

### 相关文件位置

- **修改文件**: `lib/presentation/screens/generation/widgets/unified_reference_panel.dart`
- **使用的组件**: `lib/presentation/screens/vibe_library/widgets/vibe_selector_dialog.dart`
- **数据模型**: `lib/data/models/vibe/vibe_library_entry.dart`

### VibeSelectorDialog 功能

已存在的 `VibeSelectorDialog` 提供：
- 多选支持（最多16个）
- 搜索功能（按名称、标签搜索）
- 最近使用快速访问（顶部 Chips）
- 网格视图展示（每行3个）
- 添加到当前 / 替换现有 模式切换
- 显示强度和参数信息

### 当前 _importFromLibrary() 方法位置

位于 `unified_reference_panel.dart` 第 1184-1271 行。

---

## Task 1: 添加 VibeSelectorDialog 导入

**Files:**
- Modify: `lib/presentation/screens/generation/widgets/unified_reference_panel.dart`

**Step 1: 在文件顶部添加导入语句**

在现有导入语句后添加：

```dart
import '../../vibe_library/widgets/vibe_selector_dialog.dart';
```

**Step 2: 验证导入**

运行: `flutter analyze lib/presentation/screens/generation/widgets/unified_reference_panel.dart`
Expected: 无错误，只有 info 级别提示

**Step 3: Commit**

```bash
git add lib/presentation/screens/generation/widgets/unified_reference_panel.dart
git commit -m "feat(vibe): 添加 VibeSelectorDialog 导入"
```

---

## Task 2: 替换 _importFromLibrary 方法实现

**Files:**
- Modify: `lib/presentation/screens/generation/widgets/unified_reference_panel.dart:1184-1271`

**Step 1: 删除旧的 _importFromLibrary 方法**

删除第 1184-1271 行的整个方法。

**Step 2: 添加新的 _importFromLibrary 方法**

在相同位置插入新实现：

```dart
  /// 从库导入 Vibes
  Future<void> _importFromLibrary() async {
    final storageService = ref.read(vibeLibraryStorageServiceProvider);

    try {
      // 获取当前已选中的 Vibe IDs
      final currentVibes = ref.read(generationParamsNotifierProvider).vibeReferencesV4;
      final currentIds = currentVibes.map((v) => v.id).toSet();

      // 显示选择器对话框
      final result = await VibeSelectorDialog.show(
        context: context,
        initialSelectedIds: currentIds,
        showReplaceOption: true,
        title: '从库导入 Vibe',
      );

      if (result == null || result.selectedEntries.isEmpty) return;

      // 转换为 VibeReferenceV4
      final newVibes = result.selectedEntries
          .map((entry) => entry.toVibeReference())
          .toList();

      // 应用选择
      final notifier = ref.read(generationParamsNotifierProvider.notifier);
      if (result.shouldReplace) {
        // 替换模式：清除现有并添加新的
        notifier.clearVibeReferencesV4();
        notifier.addVibeReferencesV4(newVibes);
      } else {
        // 添加模式：只添加新增的（避免重复）
        final existingIds = ref
            .read(generationParamsNotifierProvider)
            .vibeReferencesV4
            .map((v) => v.id)
            .toSet();
        final vibesToAdd = newVibes.where((v) => !existingIds.contains(v.id)).toList();

        // 检查是否超过限制
        final currentCount = existingIds.length;
        final availableSlots = 16 - currentCount;
        if (vibesToAdd.length > availableSlots) {
          if (mounted) {
            AppToast.warning(
              context,
              '只能添加 $availableSlots 个，已选择 ${vibesToAdd.length} 个',
            );
          }
          final limitedVibes = vibesToAdd.take(availableSlots).toList();
          notifier.addVibeReferencesV4(limitedVibes);
        } else {
          notifier.addVibeReferencesV4(vibesToAdd);
        }
      }

      // 更新使用统计
      for (final entry in result.selectedEntries) {
        await storageService.incrementUsedCount(entry.id);
      }

      // 刷新最近使用列表
      await _loadRecentEntries();

      if (mounted) {
        AppToast.success(
          context,
          '已导入 ${result.selectedEntries.length} 个 Vibe',
        );
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to import from library', e, stackTrace);
      if (mounted) {
        AppToast.error(context, '导入失败: $e');
      }
    }
  }
```

**Step 3: 验证代码**

运行: `flutter analyze lib/presentation/screens/generation/widgets/unified_reference_panel.dart`
Expected: 无错误

**Step 4: Commit**

```bash
git add lib/presentation/screens/generation/widgets/unified_reference_panel.dart
git commit -m "feat(vibe): 替换导入对话框为 VibeSelectorDialog"
```

---

## Task 3: 测试功能

**Files:**
- Test manually through UI

**Step 1: 运行应用**

```bash
flutter run
```

**Step 2: 手动测试场景**

1. 打开生成页面
2. 点击 Vibe Transfer 区域展开面板
3. 点击"从库导入"按钮
4. 验证以下功能：
   - 对话框显示为网格视图
   - 顶部有搜索栏
   - 显示最近使用 Chips（如果有最近使用记录）
   - 可以多选条目
   - 显示"添加/替换"模式切换
   - 确认后正确导入 Vibe

**Step 3: Commit**

```bash
git commit -m "test(vibe): 验证 VibeSelectorDialog 集成"
```

---

## Task 4: 代码清理（可选）

**Files:**
- Modify: `lib/presentation/screens/generation/widgets/unified_reference_panel.dart`

**Step 1: 检查是否有未使用的导入**

运行: `flutter analyze --severity=info lib/presentation/screens/generation/widgets/unified_reference_panel.dart`

如果有未使用的导入，删除它们。

**Step 2: 格式化代码**

运行: `dart format lib/presentation/screens/generation/widgets/unified_reference_panel.dart`

**Step 3: Commit**

```bash
git add lib/presentation/screens/generation/widgets/unified_reference_panel.dart
git commit -m "style(vibe): 格式化代码"
```

---

## 总结

完成以上任务后：

1. ✅ `_importFromLibrary()` 方法使用 `VibeSelectorDialog`
2. ✅ 支持多选导入
3. ✅ 支持搜索功能
4. ✅ 显示最近使用
5. ✅ 支持添加/替换模式
6. ✅ 自动更新使用统计
7. ✅ 正确处理 16 个 Vibe 上限

---

## 回滚方案

如果需要回滚，恢复原始的 `_importFromLibrary()` 方法：

```dart
  /// 从库导入 Vibes
  Future<void> _importFromLibrary() async {
    final storageService = ref.read(vibeLibraryStorageServiceProvider);

    try {
      final entries = await storageService.getAllEntries();

      if (!mounted) return;

      if (entries.isEmpty) {
        AppToast.info(context, 'Vibe 库为空');
        return;
      }

      final selected = await showDialog<VibeLibraryEntry>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('从库导入 Vibe'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  leading: entry.hasThumbnail
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.memory(
                            entry.thumbnail!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.image, size: 20),
                        ),
                  title: Text(entry.displayName),
                  subtitle: Text(
                    entry.isPreEncoded ? '预编码' : '需编码 (2 Anlas)',
                    style: TextStyle(
                      fontSize: 12,
                      color: entry.isPreEncoded ? Colors.green : Colors.orange,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(entry),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.common_cancel),
            ),
          ],
        ),
      );

      if (selected != null && mounted) {
        final notifier = ref.read(generationParamsNotifierProvider.notifier);
        final vibe = selected.toVibeReference();
        notifier.addVibeReferencesV4([vibe]);

        // 更新使用统计
        await storageService.incrementUsedCount(selected.id);

        if (mounted) {
          AppToast.success(context, '已导入: ${selected.displayName}');
        }
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to import from library', e, stackTrace);
      if (mounted) {
        AppToast.error(context, '导入失败: $e');
      }
    }
  }
```

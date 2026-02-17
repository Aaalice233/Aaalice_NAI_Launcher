import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/vibe_library_category_provider.dart';
import '../../../providers/vibe_library_provider.dart';
import '../../../providers/vibe_library_selection_provider.dart';
import '../../../router/app_router.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/themed_confirm_dialog.dart';
import '../../../widgets/common/pro_context_menu.dart';
import '../widgets/vibe_detail_viewer.dart';
import '../widgets/vibe_export_dialog.dart';
import '../widgets/import_menu_route.dart';
import '../mixins/vibe_library_import_mixin.dart';

/// Vibe库屏幕操作处理 Mixin
/// 集中处理所有用户交互操作
mixin VibeLibraryActionsMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, VibeLibraryImportMixin<T> {

  /// 发送单个条目到生成页面
  void sendEntryToGeneration(BuildContext context, VibeLibraryEntry entry) {
    final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);
    final currentParams = ref.read(generationParamsNotifierProvider);

    // 检查是否超过16个限制
    if (currentParams.vibeReferencesV4.length >= 16) {
      AppToast.warning(context, 'Vibe 数量已达到上限 (16个)');
      return;
    }

    // 检查是否已存在
    final exists = currentParams.vibeReferencesV4.any(
      (v) => v.vibeImagePath == entry.imagePath,
    );
    if (exists) {
      AppToast.info(context, '该 Vibe 已存在于生成参数中');
      return;
    }

    paramsNotifier.addVibeReference(entry.toVibeReference());
    AppToast.success(context, '已发送到生成页面: ${entry.displayName}');
  }

  /// 发送单个条目到生成页面（带参数）
  void sendEntryToGenerationWithParams(
    BuildContext context,
    VibeLibraryEntry entry,
    double strength,
    double infoExtracted,
  ) {
    final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);
    final currentParams = ref.read(generationParamsNotifierProvider);

    // 检查是否超过16个限制
    if (currentParams.vibeReferencesV4.length >= 16) {
      AppToast.warning(context, 'Vibe 数量已达到上限 (16个)');
      return;
    }

    // 检查是否已存在
    final exists = currentParams.vibeReferencesV4.any(
      (v) => v.vibeImagePath == entry.imagePath,
    );
    if (exists) {
      AppToast.info(context, '该 Vibe 已存在于生成参数中');
      return;
    }

    final updatedEntry =
        entry.updateStrength(strength).updateInfoExtracted(infoExtracted);
    paramsNotifier.addVibeReference(updatedEntry.toVibeReference());
    AppToast.success(context, '已发送到生成页面: ${entry.displayName}');
  }

  /// 导出单个条目
  Future<void> exportSingleEntry(
    BuildContext context,
    VibeLibraryEntry entry,
  ) async {
    final result = await VibeExportDialog.show(
      context: context,
      entries: [entry],
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      AppToast.success(context, '导出成功: ${entry.displayName}');
    }
  }

  /// 删除单个条目
  Future<void> deleteSingleEntry(
    BuildContext context,
    VibeLibraryEntry entry,
  ) async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: '确认删除',
      content: '确定要删除 "${entry.displayName}" 吗？此操作无法撤销。',
      confirmText: '删除',
      cancelText: '取消',
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );

    if (confirmed) {
      await ref
          .read(vibeLibraryNotifierProvider.notifier)
          .deleteEntries([entry.id]);
      if (context.mounted) {
        AppToast.success(context, '已删除: ${entry.displayName}');
      }
    }
  }

  /// 重命名单个条目
  Future<String?> renameSingleEntry(
    BuildContext context,
    VibeLibraryEntry entry,
    String newName,
  ) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      return '名称不能为空';
    }

    final result = await ref
        .read(vibeLibraryNotifierProvider.notifier)
        .renameEntry(entry.id, trimmedName);
    if (result.isSuccess) {
      return null;
    }

    switch (result.error) {
      case VibeEntryRenameError.invalidName:
        return '名称不能为空';
      case VibeEntryRenameError.nameConflict:
        return '名称已存在，请使用其他名称';
      case VibeEntryRenameError.entryNotFound:
        return '条目不存在，可能已被删除';
      case VibeEntryRenameError.filePathMissing:
        return '该条目缺少文件路径，无法重命名';
      case VibeEntryRenameError.fileRenameFailed:
        return '重命名文件失败，请稍后重试';
      case null:
        return '重命名失败，请稍后重试';
    }
  }

  /// 更新条目参数
  void updateEntryParams(
    BuildContext context,
    VibeLibraryEntry entry,
    double strength,
    double infoExtracted,
  ) {
    final updatedEntry =
        entry.updateStrength(strength).updateInfoExtracted(infoExtracted);

    ref.read(vibeLibraryNotifierProvider.notifier).saveEntry(updatedEntry);
  }

  /// 显示移动到分类对话框
  Future<void> showMoveToCategoryDialog() async {
    final selectionState = ref.read(vibeLibrarySelectionNotifierProvider);
    final categories = ref.read(vibeLibraryCategoryNotifierProvider).categories;

    if (categories.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可用的分类')),
        );
      }
      return;
    }

    final selectedCategory = await showDialog<VibeLibraryCategory>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移动到分类'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: categories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('未分类'),
                  onTap: () => Navigator.of(context).pop(null),
                );
              }
              final category = categories[index - 1];
              return ListTile(
                leading: const Icon(Icons.folder),
                title: Text(category.name),
                onTap: () => Navigator.of(context).pop(category),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (selectedCategory == null || !mounted) return;

    final categoryId = selectedCategory.id;
    final ids = selectionState.selectedIds.toList();

    var movedCount = 0;
    for (final id in ids) {
      final result = await ref
          .read(vibeLibraryNotifierProvider.notifier)
          .updateEntryCategory(id, categoryId);
      if (result != null) movedCount++;
    }

    ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已移动 $movedCount 个Vibe')),
    );
  }

  /// 批量切换收藏
  Future<void> batchToggleFavorite() async {
    final selectionState = ref.read(vibeLibrarySelectionNotifierProvider);
    final ids = selectionState.selectedIds.toList();

    for (final id in ids) {
      await ref.read(vibeLibraryNotifierProvider.notifier).toggleFavorite(id);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('收藏状态已更新')),
      );
      ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
    }
  }

  /// 批量发送到生成页面
  Future<void> batchSendToGeneration() async {
    final selectionState = ref.read(vibeLibrarySelectionNotifierProvider);
    final selectedIds = selectionState.selectedIds.toList();

    if (selectedIds.isEmpty) return;

    // 检查是否超过16个限制
    if (selectedIds.length > 16) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Vibe数量过多'),
            content: Text(
              '选中了 ${selectedIds.length} 个Vibe，但最多只能同时使用16个。\n\n'
              '请减少选择数量后再试。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 获取选中的条目
    final state = ref.read(vibeLibraryNotifierProvider);
    final selectedEntries =
        state.entries.where((e) => selectedIds.contains(e.id)).toList();

    // 获取当前的生成参数
    final paramsNotifier = ref.read(generationParamsNotifierProvider.notifier);
    final currentParams = ref.read(generationParamsNotifierProvider);

    // 检查添加后是否会超过16个
    final currentVibeCount = currentParams.vibeReferencesV4.length;
    final willExceedLimit = currentVibeCount + selectedEntries.length > 16;

    if (willExceedLimit) {
      final remainingSlots = 16 - currentVibeCount;
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Vibe数量过多'),
            content: Text(
              '当前生成页面已有 $currentVibeCount 个Vibe，'
              '还可以添加 $remainingSlots 个。\n\n'
              '请减少选择数量后再试。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 添加选中的Vibe到生成参数
    final vibes = selectedEntries.map((e) => e.toVibeReference()).toList();
    paramsNotifier.addVibeReferences(vibes);

    // 显示成功提示
    if (mounted) {
      AppToast.success(context, '已发送 ${selectedEntries.length} 个Vibe到生成页面');
    }

    // 退出选择模式
    ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();

    // 跳转到生成页面
    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  /// 批量导出
  Future<void> batchExport() async {
    final selectionState = ref.read(vibeLibrarySelectionNotifierProvider);
    final ids = selectionState.selectedIds.toList();

    if (ids.isEmpty) return;

    final state = ref.read(vibeLibraryNotifierProvider);
    final selectedEntries =
        state.entries.where((e) => ids.contains(e.id)).toList();

    if (selectedEntries.isEmpty) return;

    // 打开导出对话框
    await exportVibes(specificEntries: selectedEntries);

    // 退出选择模式
    ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
  }

  /// 批量删除
  Future<void> batchDelete() async {
    final selectionState = ref.read(vibeLibrarySelectionNotifierProvider);
    final ids = selectionState.selectedIds.toList();

    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: '确认删除',
      content: '确定要删除选中的 ${ids.length} 个Vibe吗？此操作无法撤销。',
      confirmText: '删除',
      cancelText: '取消',
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );

    if (confirmed) {
      await ref.read(vibeLibraryNotifierProvider.notifier).deleteEntries(ids);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 ${ids.length} 个Vibe')),
        );
        ref.read(vibeLibrarySelectionNotifierProvider.notifier).exit();
      }
    }
  }

  /// 导出Vibes
  Future<void> exportVibes({List<VibeLibraryEntry>? specificEntries}) async {
    final state = ref.read(vibeLibraryNotifierProvider);
    final entries = specificEntries ?? state.entries;

    if (entries.isEmpty) return;

    await VibeExportDialog.show(
      context: context,
      entries: entries,
    );
  }

  /// 显示导入菜单
  void showImportMenu() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);

    Navigator.of(context).push(
      ImportMenuRoute(
        position: position,
        items: [
          ProMenuItem(
            id: 'import_file',
            label: '从文件导入',
            icon: Icons.folder_outlined,
            onTap: () => importVibes(),
          ),
          ProMenuItem(
            id: 'import_image',
            label: '从图片导入',
            icon: Icons.image_outlined,
            onTap: () => importVibesFromImage(),
          ),
          ProMenuItem(
            id: 'import_clipboard',
            label: '从剪贴板导入编码',
            icon: Icons.content_paste,
            onTap: () => importVibesFromClipboard(),
          ),
        ],
        onSelect: (_) {},
      ),
    );
  }
}

part of 'vibe_library_screen.dart';

/// Vibe 库的批量操作实现。
///
/// 与 [_VibeLibraryScreenLayout] 一样以 part 的形式拆出来，避免主屏幕文件继续
/// 膨胀（`vibe_library_screen_structure_test` 会守住行数上限）。
extension _VibeLibraryScreenBulkActions on _VibeLibraryScreenState {
  /// 批量把选中条目的编码模型标记为当前生成模型。
  ///
  /// 修复历史数据用：`encodingModel` 为空的 Vibe 落盘时必须被兜底成某个模型键
  /// （NovelAI 的文件格式表达不了"未知"），回读后就成了"明确属于该模型"，于是
  /// 在别的模型下每次生成都会重新编码扣 Anlas。代码无法区分这种兜底和真实的
  /// 跨模型编码，所以把判断交给用户。
  Future<void> _batchMarkEncodingModel() async {
    if (_isMarkingEncodingModel) return;

    final ids = ref
        .read(vibeLibrarySelectionNotifierProvider)
        .selectedIds
        .toList();
    if (ids.isEmpty) return;

    final currentModel = ref.read(generationParamsNotifierProvider).model;
    if (!ModelCapabilityRegistry.of(currentModel).supportsVibeTransfer) return;
    final model = NovelAiVibeCodec.normalizeModelOrNull(currentModel);
    if (model == null) return;

    final libraryNotifier = ref.read(vibeLibraryNotifierProvider.notifier);
    final selectionNotifier = ref.read(
      vibeLibrarySelectionNotifierProvider.notifier,
    );
    _updateLayoutState(() => _isMarkingEncodingModel = true);

    var updatedCount = 0;
    try {
      final confirmed = await ThemedConfirmDialog.show(
        context: context,
        title: context.l10n.vibeLibrary_markEncodingModel,
        content: context.l10n.vibeLibrary_markEncodingModelContent(
          ids.length,
          ImageModels.modelDisplayNames[model] ?? model,
        ),
        confirmText: context.l10n.common_confirm,
        cancelText: context.l10n.common_cancel,
        icon: Icons.model_training_outlined,
      );
      if (!confirmed) return;

      for (final id in ids) {
        final result = await libraryNotifier.updateEntryEncodingModel(
          id,
          model,
        );
        if (result != null) updatedCount++;
      }

      if (!mounted) return;
      selectionNotifier.exit();
      AppToast.success(
        context,
        context.l10n.vibeLibrary_encodingModelMarked(updatedCount),
      );
    } finally {
      if (mounted) {
        _updateLayoutState(() => _isMarkingEncodingModel = false);
      } else {
        _isMarkingEncodingModel = false;
      }
    }
  }
}

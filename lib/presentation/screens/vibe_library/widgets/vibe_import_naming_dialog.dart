import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/themes/core/input_surface_style.dart';

import '../../../widgets/common/image_viewport_surface.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../widgets/common/adaptive_dialog_frame.dart';

/// Vibe 导入命名结果
class VibeImportResult {
  /// 用户输入的名称
  final String name;

  /// 是否应用到后续所有文件（批量导入时）
  final bool applyToAll;

  const VibeImportResult({required this.name, this.applyToAll = false});
}

/// Vibe 导入命名对话框
///
/// 用于在导入 Vibe 时让用户确认或修改名称
/// 支持单文件导入和批量导入模式
class VibeImportNamingDialog extends StatefulWidget {
  /// 建议名称（来自文件名）
  final String suggestedName;

  /// 预览缩略图（可选）
  final Uint8List? thumbnail;

  /// 是否批量导入模式
  final bool isBatchImport;

  /// 是否存在名称冲突
  final bool hasNameConflict;
  final bool _presented;
  final ScrollController? _scrollController;

  const VibeImportNamingDialog({
    super.key,
    required this.suggestedName,
    this.thumbnail,
    this.isBatchImport = false,
    this.hasNameConflict = false,
  }) : _presented = false,
       _scrollController = null;

  const VibeImportNamingDialog._presented({
    required this.suggestedName,
    required this.thumbnail,
    required this.isBatchImport,
    required this.hasNameConflict,
    required ScrollController scrollController,
  }) : _presented = true,
       _scrollController = scrollController;

  /// 显示对话框的便捷方法
  static Future<VibeImportResult?> show({
    required BuildContext context,
    required String suggestedName,
    Uint8List? thumbnail,
    bool isBatchImport = false,
    bool hasNameConflict = false,
  }) {
    return AdaptivePresenter.showForm<VibeImportResult>(
      context: context,
      barrierDismissible: false,
      titleBuilder: (dialogContext) => Row(
        children: [
          Icon(
            Icons.edit_note,
            color: Theme.of(dialogContext).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              dialogContext.l10n.vibe_import_namingTitle,
              style: Theme.of(dialogContext).textTheme.titleLarge,
            ),
          ),
          if (hasNameConflict)
            Tooltip(
              message: dialogContext.l10n.vibe_import_nameConflictOverwrite,
              child: Icon(
                Icons.warning_amber,
                color: Theme.of(dialogContext).colorScheme.error,
                size: 20,
              ),
            ),
        ],
      ),
      dialogWidth: 400,
      builder: (dialogContext, scrollController) =>
          VibeImportNamingDialog._presented(
            suggestedName: suggestedName,
            thumbnail: thumbnail,
            isBatchImport: isBatchImport,
            hasNameConflict: hasNameConflict,
            scrollController: scrollController,
          ),
    );
  }

  @override
  State<VibeImportNamingDialog> createState() => _VibeImportNamingDialogState();
}

class _VibeImportNamingDialogState extends State<VibeImportNamingDialog> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;
  late final FocusNode _keyboardFocusNode;
  bool _applyToAll = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.suggestedName);
    _nameFocusNode = FocusNode();
    _keyboardFocusNode = FocusNode();

    // 延迟聚焦和全选，确保渲染完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });

    AppLogger.d(
      'VibeImportNamingDialog 初始化，建议名称: ${widget.suggestedName}',
      'VibeImportNamingDialog',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  /// 验证名称
  bool _validateName(String name) {
    if (name.trim().isEmpty) {
      setState(() => _errorText = context.l10n.vibe_nameRequired);
      return false;
    }
    setState(() => _errorText = null);
    return true;
  }

  /// 确认导入
  void _confirm() {
    final name = _nameController.text.trim();
    if (!_validateName(name)) {
      return;
    }

    AppLogger.i(
      'Vibe 导入确认: name=$name, applyToAll=$_applyToAll',
      'VibeImportNamingDialog',
    );

    Navigator.of(
      context,
    ).pop(VibeImportResult(name: name, applyToAll: _applyToAll));
  }

  /// 跳过当前文件
  void _skip() {
    AppLogger.i('跳过当前 Vibe 导入', 'VibeImportNamingDialog');
    Navigator.of(context).pop(null);
  }

  /// 处理键盘事件
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      _confirm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) => _buildScrollableContent(
          Theme.of(context),
          constraints,
          includeHeader: !widget._presented,
        ),
      ),
    );

    if (widget._presented) {
      return content;
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: AdaptiveDialogFrame(
        key: const Key('vibe-import-naming-frame'),
        maxWidth: 400,
        maxHeight: 720,
        reservedVerticalSpace: 0,
        horizontalMargin: 0,
        child: SafeArea(child: content),
      ),
    );
  }

  Widget _buildScrollableContent(
    ThemeData theme,
    BoxConstraints constraints, {
    required bool includeHeader,
  }) {
    final compact = constraints.maxWidth < 380;
    final padding = compact ? 16.0 : 24.0;
    final thumbnailExtent = math
        .min(
          math.max(80, constraints.maxHeight * 0.34),
          math.min(200, constraints.maxWidth * 0.58),
        )
        .toDouble();

    return SingleChildScrollView(
      key: const Key('vibe-import-naming-scroll'),
      controller: widget._scrollController,
      padding: EdgeInsets.all(padding),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (includeHeader) ...[
            _buildHeader(theme),
            SizedBox(height: compact ? 16 : 24),
          ],
          if (widget.thumbnail != null) ...[
            _buildThumbnailPreview(theme, extent: thumbnailExtent),
            SizedBox(height: compact ? 16 : 24),
          ],
          _buildNameInput(theme),
          const SizedBox(height: 16),
          if (widget.isBatchImport) ...[
            _buildBatchOptions(theme),
            const SizedBox(height: 16),
          ],
          _buildFooter(theme),
        ],
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.edit_note, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.l10n.vibe_import_namingTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (widget.hasNameConflict)
          Tooltip(
            message: context.l10n.vibe_import_nameConflictOverwrite,
            child: Icon(
              Icons.warning_amber,
              color: theme.colorScheme.error,
              size: 20,
            ),
          ),
      ],
    );
  }

  /// 构建缩略图预览
  Widget _buildThumbnailPreview(ThemeData theme, {required double extent}) {
    return Center(
      child: SizedBox.square(
        dimension: extent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: ImageViewportSurface.background,
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.memory(
            widget.thumbnail!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              AppLogger.w('缩略图加载失败: $error', 'VibeImportNamingDialog');
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.broken_image,
                    size: 48,
                    color: ImageViewportSurface.mutedForeground,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.vibe_previewLoadFailed,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ImageViewportSurface.mutedForeground,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 构建名称输入框
  Widget _buildNameInput(ThemeData theme) {
    return TextField(
      controller: _nameController,
      focusNode: _nameFocusNode,
      decoration: InputDecoration(
        labelText: context.l10n.vibe_saveToLibrary_nameLabel,
        hintText: context.l10n.vibe_saveToLibrary_nameHint,
        errorText: _errorText,
        prefixIcon: const Icon(Icons.label_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: inputSurfaceFillColor(theme.colorScheme),
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _confirm(),
      onChanged: (value) {
        if (_errorText != null) {
          setState(() => _errorText = null);
        }
      },
    );
  }

  /// 构建批量导入选项
  Widget _buildBatchOptions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.batch_prediction,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.vibe_import_applyToRemainingFiles,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  context.l10n.vibe_import_applyNamingToRemainingFiles,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Checkbox(
            value: _applyToAll,
            onChanged: (value) {
              setState(() => _applyToAll = value ?? false);
              AppLogger.d(
                '批量导入选项改变: applyToAll=$_applyToAll',
                'VibeImportNamingDialog',
              );
            },
          ),
        ],
      ),
    );
  }

  /// 构建底部按钮
  Widget _buildFooter(ThemeData theme) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        // 跳过按钮（仅批量导入时显示）
        if (widget.isBatchImport) ...[
          TextButton.icon(
            onPressed: _skip,
            icon: const Icon(Icons.skip_next),
            label: Text(context.l10n.vibe_import_skip),
          ),
        ],
        // 取消按钮
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_cancel),
        ),
        // 确认按钮
        FilledButton.icon(
          onPressed: _confirm,
          icon: const Icon(Icons.check),
          label: Text(context.l10n.vibe_import_confirm),
        ),
      ],
    );
  }
}

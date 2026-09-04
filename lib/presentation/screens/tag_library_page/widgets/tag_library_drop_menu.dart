import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../adaptive/adaptive_presenter.dart';

/// 词库拖拽操作类型
enum TagLibraryDropAction {
  /// 创建新词条
  create,

  /// 更新现有词条预览图
  updateThumbnail,

  /// 取消
  cancel,
}

/// 词库拖拽操作选择菜单
///
/// 当用户拖拽图片到词库页面时弹出，让用户选择操作
class TagLibraryDropMenu extends StatelessWidget {
  /// 拖入的文件名
  final String fileName;

  /// 提取的提示词（如果有）
  final String? prompt;

  /// 自适应呈现层提供的滚动控制器
  final ScrollController? scrollController;

  const TagLibraryDropMenu({
    super.key,
    required this.fileName,
    this.prompt,
    this.scrollController,
  });

  /// 显示自适应操作面板
  static Future<TagLibraryDropAction?> show(
    BuildContext context, {
    required String fileName,
    String? prompt,
  }) {
    final displayFileName = _displayFileName(fileName);
    return AdaptivePresenter.showForm<TagLibraryDropAction>(
      context: context,
      dialogWidth: 400,
      titleBuilder: (panelContext) => Row(
        children: [
          Icon(
            Icons.image_outlined,
            color: Theme.of(panelContext).colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  panelContext.l10n.tagLibrary_droppedImage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(panelContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayFileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(panelContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(panelContext).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      builder: (panelContext, scrollController) => TagLibraryDropMenu(
        fileName: fileName,
        prompt: prompt,
        scrollController: scrollController,
      ),
    );
  }

  static String _displayFileName(String fileName) => fileName.length > 40
      ? '${fileName.substring(0, 20)}...${fileName.substring(fileName.length - 17)}'
      : fileName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // 截断过长的提示词预览
    final promptPreview = prompt != null && prompt!.isNotEmpty
        ? (prompt!.length > 50 ? '${prompt!.substring(0, 50)}...' : prompt!)
        : null;

    return ListView(
      key: const ValueKey('tag-library-drop-menu-scroll'),
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(24),
      children: [
        _ActionButton(
          icon: Icons.add_box_outlined,
          title: l10n.tagLibrary_createEntryFromImage,
          subtitle: promptPreview != null
              ? l10n.tagLibrary_promptExtracted(promptPreview)
              : l10n.tagLibrary_createEntryFromImageSubtitle,
          onTap: () => Navigator.of(context).pop(TagLibraryDropAction.create),
        ),
        const SizedBox(height: 12),
        _ActionButton(
          icon: Icons.image_search_outlined,
          title: l10n.tagLibrary_updateExistingThumbnail,
          subtitle: l10n.tagLibrary_updateExistingThumbnailSubtitle,
          onTap: () =>
              Navigator.of(context).pop(TagLibraryDropAction.updateThumbnail),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () =>
              Navigator.of(context).pop(TagLibraryDropAction.cancel),
          icon: const Icon(Icons.close, size: 18),
          label: Text(l10n.common_cancel),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}

/// 操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

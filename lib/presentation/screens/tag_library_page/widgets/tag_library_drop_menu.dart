import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

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

  const TagLibraryDropMenu({
    super.key,
    required this.fileName,
    this.prompt,
  });

  /// 显示对话框
  static Future<TagLibraryDropAction?> show(
    BuildContext context, {
    required String fileName,
    String? prompt,
  }) {
    return showDialog<TagLibraryDropAction>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => TagLibraryDropMenu(
        fileName: fileName,
        prompt: prompt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    // 截断过长的文件名
    final displayFileName = fileName.length > 40
        ? '${fileName.substring(0, 20)}...${fileName.substring(fileName.length - 17)}'
        : fileName;

    // 截断过长的提示词预览
    final promptPreview = prompt != null && prompt!.isNotEmpty
        ? (prompt!.length > 50 ? '${prompt!.substring(0, 50)}...' : prompt!)
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题区域
              Row(
                children: [
                  Icon(
                    Icons.image_outlined,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '拖入图片',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayFileName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 操作选项
              _ActionButton(
                icon: Icons.add_box_outlined,
                title: '创建新词条',
                subtitle: promptPreview != null
                    ? '提示词已提取: "$promptPreview"'
                    : '从图片创建新词条',
                onTap: () =>
                    Navigator.of(context).pop(TagLibraryDropAction.create),
              ),

              const SizedBox(height: 12),

              _ActionButton(
                icon: Icons.image_search_outlined,
                title: '更新现有词条预览图',
                subtitle: '选择词条并替换其预览图',
                onTap: () => Navigator.of(context)
                    .pop(TagLibraryDropAction.updateThumbnail),
              ),

              const SizedBox(height: 20),

              // 取消按钮
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
          ),
        ),
      ),
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
                child: Icon(
                  icon,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
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
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

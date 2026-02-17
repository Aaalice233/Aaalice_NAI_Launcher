import 'package:flutter/material.dart';

import '../../../core/services/smart_folder_suggestion_service.dart';
import '../../../core/utils/localization_extension.dart';

/// 智能文件夹建议 UI 组件
///
/// 显示基于标签匹配的智能文件夹建议列表
/// 包含匹配分数、匹配标签等信息
///
/// 使用示例:
/// ```dart
/// SmartFolderSuggestions(
///   suggestions: suggestions,
///   onFolderSelected: (folderId) => print('Selected: $folderId'),
///   emptyMessage: '暂无建议',
/// )
/// ```
class SmartFolderSuggestions extends StatelessWidget {
  /// 文件夹建议列表
  final List<FolderSuggestion> suggestions;

  /// 文件夹选中回调
  final ValueChanged<String>? onFolderSelected;

  /// 空状态显示的消息
  final String? emptyMessage;

  /// 最大显示数量
  final int maxDisplayCount;

  /// 是否显示匹配标签
  final bool showMatchingTags;

  /// 是否显示分数
  final bool showScore;

  /// 选中的文件夹ID
  final String? selectedFolderId;

  /// 是否使用紧凑模式
  final bool compact;

  const SmartFolderSuggestions({
    super.key,
    required this.suggestions,
    this.onFolderSelected,
    this.emptyMessage,
    this.maxDisplayCount = 5,
    this.showMatchingTags = true,
    this.showScore = true,
    this.selectedFolderId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (suggestions.isEmpty) {
      return _buildEmptyState(theme);
    }

    final displaySuggestions = suggestions.take(maxDisplayCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: displaySuggestions.map((suggestion) {
        return _buildSuggestionItem(context, theme, suggestion);
      }).toList(),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            emptyMessage ?? '暂无文件夹建议',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建建议项
  Widget _buildSuggestionItem(
    BuildContext context,
    ThemeData theme,
    FolderSuggestion suggestion,
  ) {
    final isSelected = suggestion.folderId == selectedFolderId;
    final scoreColor = _getScoreColor(theme, suggestion.score);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withOpacity(0.5)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onFolderSelected != null
            ? () => onFolderSelected!(suggestion.folderId)
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 8 : 12,
          ),
          child: Row(
            children: [
              // 文件夹图标
              _buildFolderIcon(theme, isSelected),
              const SizedBox(width: 12),
              // 文件夹信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 文件夹名称和分数
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            suggestion.folderName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showScore) ...[
                          const SizedBox(width: 8),
                          _buildScoreBadge(theme, suggestion, scoreColor),
                        ],
                      ],
                    ),
                    // 匹配描述和标签
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      _buildMatchInfo(theme, suggestion),
                    ],
                  ],
                ),
              ),
              // 选中指示器
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建文件夹图标
  Widget _buildFolderIcon(ThemeData theme, bool isSelected) {
    return Container(
      width: compact ? 32 : 40,
      height: compact ? 32 : 40,
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withOpacity(0.2)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.folder,
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
        size: compact ? 18 : 20,
      ),
    );
  }

  /// 构建分数徽章
  Widget _buildScoreBadge(
    ThemeData theme,
    FolderSuggestion suggestion,
    Color scoreColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scoreColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        suggestion.formattedScore,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scoreColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 构建匹配信息
  Widget _buildMatchInfo(ThemeData theme, FolderSuggestion suggestion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 匹配描述
        Text(
          suggestion.matchDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        // 匹配标签
        if (showMatchingTags && suggestion.matchingTags.isNotEmpty) ...[
          const SizedBox(height: 6),
          _buildMatchingTags(theme, suggestion.matchingTags),
        ],
      ],
    );
  }

  /// 构建匹配标签列表
  Widget _buildMatchingTags(ThemeData theme, List<String> tags) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: tags.take(5).map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            tag,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontSize: 11,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 根据分数获取颜色
  Color _getScoreColor(ThemeData theme, double score) {
    if (score >= 0.7) {
      return Colors.green;
    } else if (score >= 0.4) {
      return theme.colorScheme.primary;
    } else if (score >= 0.2) {
      return Colors.orange;
    } else {
      return theme.colorScheme.outline;
    }
  }
}

/// 智能文件夹建议对话框
///
/// 用于显示文件夹建议并让用户选择
class SmartFolderSuggestionDialog extends StatelessWidget {
  /// 建议列表
  final List<FolderSuggestion> suggestions;

  /// 对话框标题
  final String? title;

  /// 确认按钮文本
  final String? confirmText;

  /// 取消按钮文本
  final String? cancelText;

  const SmartFolderSuggestionDialog({
    super.key,
    required this.suggestions,
    this.title,
    this.confirmText,
    this.cancelText,
  });

  /// 显示智能文件夹建议对话框
  ///
  /// 返回用户选择的文件夹ID，如果取消则返回null
  static Future<String?> show({
    required BuildContext context,
    required List<FolderSuggestion> suggestions,
    String? title,
    String? confirmText,
    String? cancelText,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => SmartFolderSuggestionDialog(
        suggestions: suggestions,
        title: title,
        confirmText: confirmText,
        cancelText: cancelText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title ?? '智能文件夹建议',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (suggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '根据标签匹配，推荐以下文件夹：',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                child: SmartFolderSuggestions(
                  suggestions: suggestions,
                  maxDisplayCount: 5,
                  showMatchingTags: true,
                  showScore: true,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelText ?? l10n.common_cancel),
        ),
      ],
    );
  }
}

/// 智能文件夹选择底部弹窗
///
/// 移动端友好的底部弹窗形式
class SmartFolderSuggestionBottomSheet extends StatefulWidget {
  /// 建议列表
  final List<FolderSuggestion> suggestions;

  /// 标题
  final String? title;

  /// 确认按钮文本
  final String? confirmText;

  const SmartFolderSuggestionBottomSheet({
    super.key,
    required this.suggestions,
    this.title,
    this.confirmText,
  });

  /// 显示底部弹窗
  ///
  /// 返回用户选择的文件夹ID，如果取消则返回null
  static Future<String?> show({
    required BuildContext context,
    required List<FolderSuggestion> suggestions,
    String? title,
    String? confirmText,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SmartFolderSuggestionBottomSheet(
        suggestions: suggestions,
        title: title,
        confirmText: confirmText,
      ),
    );
  }

  @override
  State<SmartFolderSuggestionBottomSheet> createState() =>
      _SmartFolderSuggestionBottomSheetState();
}

class _SmartFolderSuggestionBottomSheetState
    extends State<SmartFolderSuggestionBottomSheet> {
  String? _selectedFolderId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动指示器
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title ?? '选择文件夹',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 建议列表
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SmartFolderSuggestions(
                suggestions: widget.suggestions,
                selectedFolderId: _selectedFolderId,
                onFolderSelected: (folderId) {
                  setState(() {
                    _selectedFolderId = folderId;
                  });
                },
                maxDisplayCount: 5,
                showMatchingTags: true,
                showScore: true,
              ),
            ),
          ),
          // 底部按钮
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomPadding),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _selectedFolderId != null
                        ? () => Navigator.of(context).pop(_selectedFolderId)
                        : null,
                    child: Text(widget.confirmText ?? '选择'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 智能文件夹快捷入口
///
/// 在工具栏或操作栏显示的紧凑型建议按钮
class SmartFolderQuickSuggestion extends StatelessWidget {
  /// 最佳建议
  final FolderSuggestion? bestSuggestion;

  /// 点击回调
  final VoidCallback? onTap;

  /// 是否启用动画
  final bool animated;

  const SmartFolderQuickSuggestion({
    super.key,
    this.bestSuggestion,
    this.onTap,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (bestSuggestion == null) {
      return const SizedBox.shrink();
    }

    final suggestion = bestSuggestion!;
    final scoreColor = _getScoreColor(theme, suggestion.score);

    Widget content = Material(
      color: theme.colorScheme.primaryContainer.withOpacity(0.3),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '推荐: ${suggestion.folderName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  suggestion.formattedScore,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scoreColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (animated) {
      content = AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 300),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: content,
        ),
      );
    }

    return content;
  }

  /// 根据分数获取颜色
  Color _getScoreColor(ThemeData theme, double score) {
    if (score >= 0.7) {
      return Colors.green;
    } else if (score >= 0.4) {
      return theme.colorScheme.primary;
    } else if (score >= 0.2) {
      return Colors.orange;
    } else {
      return theme.colorScheme.outline;
    }
  }
}

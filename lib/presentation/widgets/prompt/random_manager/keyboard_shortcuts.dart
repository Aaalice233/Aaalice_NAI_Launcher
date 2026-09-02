import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../providers/tag_group_sync_provider.dart';

/// 随机词库管理器的键盘快捷键配置
///
/// 提供的快捷键:
/// - Ctrl+S: 保存/同步
/// - Ctrl+G: 生成预览
/// - Ctrl+N: 新建预设
/// - Ctrl+D: 复制预设
/// - Ctrl+F: 搜索
/// - Ctrl+A: 全选
/// - Ctrl+Shift+A: 取消全选
/// - Delete: 删除选中
/// - F5: 刷新/同步 Danbooru
class RandomManagerShortcuts extends ConsumerWidget {
  const RandomManagerShortcuts({
    super.key,
    required this.child,
    this.onGeneratePreview,
    this.onSearch,
    this.onSelectAll,
    this.onDeselectAll,
    this.onDeleteSelected,
    this.onNewPreset,
    this.onCopyPreset,
  });

  final Widget child;
  final VoidCallback? onGeneratePreview;
  final VoidCallback? onSearch;
  final VoidCallback? onSelectAll;
  final VoidCallback? onDeselectAll;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onNewPreset;
  final VoidCallback? onCopyPreset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CallbackShortcuts(
      bindings: _buildBindings(context, ref),
      child: Focus(autofocus: true, child: child),
    );
  }

  Map<ShortcutActivator, VoidCallback> _buildBindings(
    BuildContext context,
    WidgetRef ref,
  ) {
    return {
      // Escape - 关闭
      const SingleActivator(LogicalKeyboardKey.escape): () {
        Navigator.of(context).pop();
      },

      // Ctrl+S - 保存/同步
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
        _syncDanbooru(ref);
      },

      // F5 - 刷新/同步
      const SingleActivator(LogicalKeyboardKey.f5): () {
        _syncDanbooru(ref);
      },

      // Ctrl+G - 生成预览
      if (onGeneratePreview != null)
        const SingleActivator(LogicalKeyboardKey.keyG, control: true):
            onGeneratePreview!,

      // Ctrl+F - 搜索
      if (onSearch != null)
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            onSearch!,

      // Ctrl+A - 全选
      if (onSelectAll != null)
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            onSelectAll!,

      // Ctrl+Shift+A - 取消全选
      if (onDeselectAll != null)
        const SingleActivator(
          LogicalKeyboardKey.keyA,
          control: true,
          shift: true,
        ): onDeselectAll!,

      // Delete - 删除选中
      if (onDeleteSelected != null)
        const SingleActivator(LogicalKeyboardKey.delete): onDeleteSelected!,

      // Ctrl+N - 新建预设
      if (onNewPreset != null)
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            onNewPreset!,

      // Ctrl+D - 复制预设
      if (onCopyPreset != null)
        const SingleActivator(LogicalKeyboardKey.keyD, control: true):
            onCopyPreset!,
    };
  }

  void _syncDanbooru(WidgetRef ref) {
    final syncNotifier = ref.read(tagGroupSyncNotifierProvider.notifier);
    final syncState = ref.read(tagGroupSyncNotifierProvider);
    if (!syncState.isSyncing) {
      syncNotifier.syncTagGroups();
    }
  }
}

/// 快捷键提示组件
///
/// 显示当前可用的键盘快捷键列表
class ShortcutHelpDialog extends StatelessWidget {
  const ShortcutHelpDialog({super.key, this.scrollController});

  final ScrollController? scrollController;

  static Future<void> show(BuildContext context) {
    return AdaptivePresenter.showPanel<void>(
      context: context,
      titleBuilder: (context) => Text(
        context.l10n.randomManager_keyboardShortcuts,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      initialChildSize: 0.8,
      minChildSize: 0.5,
      sideSheetWidth: 440,
      builder: (context, scrollController) =>
          ShortcutHelpDialog(scrollController: scrollController),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        _ShortcutSection(
          title: l10n.randomManager_generalShortcuts,
          shortcuts: [
            _ShortcutItem('Esc', l10n.randomManager_closeWindow),
            _ShortcutItem('Ctrl+S', l10n.randomManager_syncDanbooruTags),
            _ShortcutItem('F5', l10n.randomManager_refreshOrSync),
          ],
        ),
        const SizedBox(height: 16),
        _ShortcutSection(
          title: l10n.randomManager_presetActions,
          shortcuts: [
            _ShortcutItem('Ctrl+N', l10n.shortcut_action_new_preset),
            _ShortcutItem('Ctrl+D', l10n.shortcut_action_duplicate_preset),
            _ShortcutItem('Ctrl+G', l10n.randomManager_generatePreview),
          ],
        ),
        const SizedBox(height: 16),
        _ShortcutSection(
          title: l10n.randomManager_selectionActions,
          shortcuts: [
            _ShortcutItem('Ctrl+F', l10n.common_search),
            _ShortcutItem('Ctrl+A', l10n.common_selectAll),
            _ShortcutItem('Ctrl+Shift+A', l10n.common_deselectAll),
            _ShortcutItem('Delete', l10n.randomManager_deleteSelected),
          ],
        ),
      ],
    );
  }
}

/// 快捷键分组
class _ShortcutSection extends StatelessWidget {
  const _ShortcutSection({required this.title, required this.shortcuts});

  final String title;
  final List<_ShortcutItem> shortcuts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...shortcuts.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 360 ||
                    MediaQuery.textScalerOf(context).scale(1) >= 2;
                final description = Text(
                  s.description,
                  style: theme.textTheme.bodySmall,
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _KeyBadge(keys: s.keys),
                      const SizedBox(height: 4),
                      description,
                    ],
                  );
                }
                return Row(
                  children: [
                    _KeyBadge(keys: s.keys),
                    const SizedBox(width: 12),
                    Expanded(child: description),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// 快捷键项
class _ShortcutItem {
  final String keys;
  final String description;

  const _ShortcutItem(this.keys, this.description);
}

/// 按键徽章
class _KeyBadge extends StatelessWidget {
  const _KeyBadge({required this.keys});

  final String keys;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final parts = keys.split('+');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: parts.asMap().entries.map((entry) {
        final index = entry.key;
        final key = entry.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  '+',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                key,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

/// 快捷键帮助按钮
class ShortcutHelpButton extends StatefulWidget {
  const ShortcutHelpButton({super.key});

  @override
  State<ShortcutHelpButton> createState() => _ShortcutHelpButtonState();
}

class _ShortcutHelpButtonState extends State<ShortcutHelpButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => ShortcutHelpDialog.show(context),
        child: Tooltip(
          message: context.l10n.randomManager_keyboardShortcutsHint,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isHovered
                  ? colorScheme.surfaceContainerHighest
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.keyboard,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

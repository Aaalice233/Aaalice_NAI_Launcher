import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      child: Focus(
        autofocus: true,
        child: child,
      ),
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
  const ShortcutHelpDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const ShortcutHelpDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.keyboard,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '键盘快捷键',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 快捷键列表
            const _ShortcutSection(
              title: '通用',
              shortcuts: [
                _ShortcutItem('Esc', '关闭窗口'),
                _ShortcutItem('Ctrl+S', '同步 Danbooru'),
                _ShortcutItem('F5', '刷新/同步'),
              ],
            ),
            const SizedBox(height: 16),
            const _ShortcutSection(
              title: '预设操作',
              shortcuts: [
                _ShortcutItem('Ctrl+N', '新建预设'),
                _ShortcutItem('Ctrl+D', '复制预设'),
                _ShortcutItem('Ctrl+G', '生成预览'),
              ],
            ),
            const SizedBox(height: 16),
            const _ShortcutSection(
              title: '选择操作',
              shortcuts: [
                _ShortcutItem('Ctrl+F', '搜索'),
                _ShortcutItem('Ctrl+A', '全选'),
                _ShortcutItem('Ctrl+Shift+A', '取消全选'),
                _ShortcutItem('Delete', '删除选中'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 快捷键分组
class _ShortcutSection extends StatelessWidget {
  const _ShortcutSection({
    required this.title,
    required this.shortcuts,
  });

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
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                _KeyBadge(keys: s.keys),
                const SizedBox(width: 12),
                Text(
                  s.description,
                  style: theme.textTheme.bodySmall,
                ),
              ],
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
                    color: colorScheme.shadow.withOpacity(0.08),
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
          message: '键盘快捷键 (按 ? 查看)',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/shortcuts/default_shortcuts.dart';
import '../../../../../core/shortcuts/shortcut_config.dart';
import '../../../../../core/shortcuts/shortcut_manager.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../providers/shortcuts_provider.dart';

/// 查看器快捷键提示覆盖层
///
/// 浮动显示在图片查看器中的快捷键指南，自动根据当前配置显示
/// 可用的快捷键列表。支持显示/隐藏动画。
class ViewerShortcutHints extends ConsumerStatefulWidget {
  /// 是否可见
  final bool visible;

  /// 自动隐藏时长（默认5秒）
  final Duration autoHideDuration;

  /// 背景透明度（0.0 - 1.0）
  final double backgroundOpacity;

  const ViewerShortcutHints({
    super.key,
    this.visible = true,
    this.autoHideDuration = const Duration(seconds: 5),
    this.backgroundOpacity = 0.85,
  });

  @override
  ConsumerState<ViewerShortcutHints> createState() =>
      _ViewerShortcutHintsState();
}

class _ViewerShortcutHintsState extends ConsumerState<ViewerShortcutHints> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _isVisible = widget.visible;
  }

  @override
  void didUpdateWidget(ViewerShortcutHints oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      setState(() => _isVisible = widget.visible);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(shortcutConfigNotifierProvider);

    return configAsync.when(
      data: (config) {
        // 如果快捷键被禁用，不显示提示
        if (!config.enableShortcuts) {
          return const SizedBox.shrink();
        }

        return AnimatedOpacity(
          opacity: _isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: _buildHintsContainer(context, config),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildHintsContainer(BuildContext context, ShortcutConfig config) {
    final theme = Theme.of(context);
    final viewerShortcuts = _getViewerShortcuts(config);

    if (viewerShortcuts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(widget.backgroundOpacity),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard,
                color: Colors.white.withOpacity(0.9),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.shortcut_context_viewer,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 快捷键列表
          ...viewerShortcuts.map(
            (item) => _buildShortcutRow(
              context,
              label: item.label,
              shortcut: item.shortcut,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutRow(
    BuildContext context, {
    required String label,
    required String shortcut,
  }) {
    final shortcutLabel = AppShortcutManager.getDisplayLabel(shortcut);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 快捷键标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: Text(
              shortcutLabel,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 功能描述
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取查看器相关的快捷键列表
  List<_ShortcutItem> _getViewerShortcuts(ShortcutConfig config) {
    final items = <_ShortcutItem>[];
    final l10n = context.l10n;

    // 导航快捷键
    _addShortcutItem(
      items,
      config,
      ShortcutIds.previousImage,
      l10n.shortcut_action_previous_image,
    );
    _addShortcutItem(
      items,
      config,
      ShortcutIds.nextImage,
      l10n.shortcut_action_next_image,
    );

    // 缩放快捷键
    _addShortcutItem(
      items,
      config,
      ShortcutIds.zoomIn,
      l10n.shortcut_action_zoom_in,
    );
    _addShortcutItem(
      items,
      config,
      ShortcutIds.zoomOut,
      l10n.shortcut_action_zoom_out,
    );
    _addShortcutItem(
      items,
      config,
      ShortcutIds.resetZoom,
      l10n.shortcut_action_reset_zoom,
    );

    // 操作快捷键
    _addShortcutItem(
      items,
      config,
      ShortcutIds.toggleFavorite,
      l10n.shortcut_action_toggle_favorite,
    );
    _addShortcutItem(
      items,
      config,
      ShortcutIds.copyPrompt,
      l10n.shortcut_action_copy_prompt,
    );
    _addShortcutItem(
      items,
      config,
      ShortcutIds.reuseGalleryParams,
      l10n.shortcut_action_reuse_gallery_params,
    );

    // 查看器控制
    _addShortcutItem(
      items,
      config,
      ShortcutIds.toggleFullscreen,
      l10n.shortcut_action_toggle_fullscreen,
    );
    _addShortcutItem(
      items,
      config,
      ShortcutIds.closeViewer,
      l10n.shortcut_action_close_viewer,
    );

    // 帮助快捷键
    _addShortcutItem(
      items,
      config,
      ShortcutIds.showShortcutHelp,
      l10n.shortcut_action_show_shortcut_help,
    );

    return items;
  }

  void _addShortcutItem(
    List<_ShortcutItem> items,
    ShortcutConfig config,
    String shortcutId,
    String label,
  ) {
    final shortcut = config.getEffectiveShortcut(shortcutId);
    if (shortcut != null && shortcut.isNotEmpty) {
      items.add(_ShortcutItem(label: label, shortcut: shortcut));
    }
  }
}

/// 快捷键项数据
class _ShortcutItem {
  final String label;
  final String shortcut;

  const _ShortcutItem({
    required this.label,
    required this.shortcut,
  });
}

/// 查看器快捷键提示按钮
/// 用于切换快捷键提示的显示/隐藏
class ViewerShortcutHintsButton extends ConsumerWidget {
  /// 当前提示是否可见
  final bool isVisible;

  /// 点击回调
  final VoidCallback onToggle;

  const ViewerShortcutHintsButton({
    super.key,
    required this.isVisible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(shortcutConfigNotifierProvider);

    return configAsync.when(
      data: (config) {
        // 如果快捷键被禁用，不显示按钮
        if (!config.enableShortcuts) {
          return const SizedBox.shrink();
        }

        return Tooltip(
          message: isVisible ? '隐藏快捷键提示' : '显示快捷键提示',
          child: Material(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  isVisible ? Icons.keyboard_hide : Icons.keyboard,
                  color: Colors.white.withOpacity(0.9),
                  size: 20,
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// 查看器快捷键提示浮动组件
/// 自动定位在屏幕角落的浮动提示
class ViewerShortcutHintsFloating extends ConsumerStatefulWidget {
  /// 初始是否可见
  final bool initiallyVisible;

  /// 边距
  final EdgeInsets margin;

  /// 位置
  final FloatingHintPosition position;

  const ViewerShortcutHintsFloating({
    super.key,
    this.initiallyVisible = false,
    this.margin = const EdgeInsets.all(16),
    this.position = FloatingHintPosition.bottomRight,
  });

  @override
  ConsumerState<ViewerShortcutHintsFloating> createState() =>
      _ViewerShortcutHintsFloatingState();
}

class _ViewerShortcutHintsFloatingState
    extends ConsumerState<ViewerShortcutHintsFloating> {
  late bool _isVisible;

  @override
  void initState() {
    super.initState();
    _isVisible = widget.initiallyVisible;
  }

  void _toggleVisibility() {
    setState(() => _isVisible = !_isVisible);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 快捷键提示
        if (_isVisible)
          Positioned(
            left: widget.position == FloatingHintPosition.bottomLeft ||
                    widget.position == FloatingHintPosition.topLeft
                ? widget.margin.left
                : null,
            right: widget.position == FloatingHintPosition.bottomRight ||
                    widget.position == FloatingHintPosition.topRight
                ? widget.margin.right
                : null,
            top: widget.position == FloatingHintPosition.topLeft ||
                    widget.position == FloatingHintPosition.topRight
                ? widget.margin.top
                : null,
            bottom: widget.position == FloatingHintPosition.bottomLeft ||
                    widget.position == FloatingHintPosition.bottomRight
                ? widget.margin.bottom + 40 // 为按钮留出空间
                : null,
            child: ViewerShortcutHints(
              visible: _isVisible,
            ),
          ),
        // 切换按钮
        Positioned(
          left: widget.position == FloatingHintPosition.bottomLeft ||
                  widget.position == FloatingHintPosition.topLeft
              ? widget.margin.left
              : null,
          right: widget.position == FloatingHintPosition.bottomRight ||
                  widget.position == FloatingHintPosition.topRight
              ? widget.margin.right
              : null,
          top: widget.position == FloatingHintPosition.topLeft ||
                  widget.position == FloatingHintPosition.topRight
              ? widget.margin.top
              : null,
          bottom: widget.position == FloatingHintPosition.bottomLeft ||
                  widget.position == FloatingHintPosition.bottomRight
              ? widget.margin.bottom
              : null,
          child: ViewerShortcutHintsButton(
            isVisible: _isVisible,
            onToggle: _toggleVisibility,
          ),
        ),
      ],
    );
  }
}

/// 浮动提示位置
enum FloatingHintPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

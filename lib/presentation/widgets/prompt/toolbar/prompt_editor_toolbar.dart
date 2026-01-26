import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../unified/unified_prompt_config.dart';
import 'prompt_editor_toolbar_config.dart';

/// 提示词编辑器工具栏组件
///
/// 根据 [PromptEditorToolbarConfig] 配置渲染相应的工具栏按钮。
/// 支持随机生成、全屏编辑、清空和设置等操作。
///
/// 紧凑模式：
/// 当 [PromptEditorToolbarConfig.compact] 为 true 时，工具栏会：
/// - 使用更小的按钮尺寸（图标 16px，按钮高度 24px）
/// - 优先显示必要操作（清空），隐藏次要操作（随机、全屏、设置）
///
/// 使用示例：
/// ```dart
/// PromptEditorToolbar(
///   config: PromptEditorToolbarConfig.characterEditor,
///   onClearPressed: () => _controller.clear(),
/// )
/// ```
class PromptEditorToolbar extends StatelessWidget {
  // 标准模式尺寸
  static const double _standardIconSize = 20.0;

  // 紧凑模式尺寸
  static const double _compactIconSize = 16.0;

  /// 工具栏配置
  final PromptEditorToolbarConfig config;

  /// 随机按钮点击回调
  final VoidCallback? onRandomPressed;

  /// 随机按钮长按回调（用于打开配置）
  final VoidCallback? onRandomLongPressed;

  /// 全屏按钮点击回调
  final VoidCallback? onFullscreenPressed;

  /// 清空按钮点击回调
  final VoidCallback? onClearPressed;

  /// 设置按钮点击回调
  final VoidCallback? onSettingsPressed;

  /// 前置自定义按钮
  final List<Widget>? leadingActions;

  /// 后置自定义按钮
  final List<Widget>? trailingActions;

  const PromptEditorToolbar({
    super.key,
    required this.config,
    this.onRandomPressed,
    this.onRandomLongPressed,
    this.onFullscreenPressed,
    this.onClearPressed,
    this.onSettingsPressed,
    this.leadingActions,
    this.trailingActions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = config.compact;

    // 紧凑模式下，只显示必要操作（清空）
    final showRandomButton = config.showRandomButton && !isCompact;
    final showFullscreenButton = config.showFullscreenButton && !isCompact;
    final showClearButton = config.showClearButton;
    final showSettingsButton = config.showSettingsButton && !isCompact;

    // 检查是否有任何按钮需要显示
    final hasAnyButton = showRandomButton ||
        showFullscreenButton ||
        showClearButton ||
        showSettingsButton ||
        (leadingActions?.isNotEmpty ?? false) ||
        (trailingActions?.isNotEmpty ?? false);

    if (!hasAnyButton) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 前置自定义按钮
        if (leadingActions != null) ...leadingActions!,

        // 随机按钮（次要操作，紧凑模式隐藏）
        if (showRandomButton) _buildRandomButton(context, theme, isCompact),

        // 全屏按钮（次要操作，紧凑模式隐藏）
        if (showFullscreenButton)
          _buildFullscreenButton(context, theme, isCompact),

        // 清空按钮（必要操作，紧凑模式保留）
        if (showClearButton) _buildClearButton(context, theme, isCompact),

        // 设置按钮（次要操作，紧凑模式隐藏）
        if (showSettingsButton) _buildSettingsButton(context, theme, isCompact),

        // 后置自定义按钮
        if (trailingActions != null) ...trailingActions!,
      ],
    );
  }

  /// 构建随机按钮
  Widget _buildRandomButton(
    BuildContext context,
    ThemeData theme,
    bool isCompact,
  ) {
    final iconSize = isCompact ? _compactIconSize : _standardIconSize;
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onLongPress: onRandomLongPressed,
      child: IconButton(
        icon: Icon(
          Icons.casino_outlined,
          size: iconSize,
          color: onRandomPressed != null
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withOpacity(0.3),
        ),
        tooltip: l10n.toolbar_randomPrompt,
        onPressed: onRandomPressed,
        visualDensity: VisualDensity.compact,
        constraints: isCompact
            ? const BoxConstraints(minWidth: 32, minHeight: 32)
            : null,
        padding: isCompact ? const EdgeInsets.all(4) : null,
      ),
    );
  }

  /// 构建全屏按钮
  Widget _buildFullscreenButton(
    BuildContext context,
    ThemeData theme,
    bool isCompact,
  ) {
    final iconSize = isCompact ? _compactIconSize : _standardIconSize;
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      icon: Icon(
        Icons.fullscreen,
        size: iconSize,
        color: onFullscreenPressed != null
            ? theme.colorScheme.onSurface.withOpacity(0.6)
            : theme.colorScheme.onSurface.withOpacity(0.3),
      ),
      tooltip: l10n.toolbar_fullscreenEdit,
      onPressed: onFullscreenPressed,
      visualDensity: VisualDensity.compact,
      constraints:
          isCompact ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
      padding: isCompact ? const EdgeInsets.all(4) : null,
    );
  }

  /// 构建清空按钮
  Widget _buildClearButton(
    BuildContext context,
    ThemeData theme,
    bool isCompact,
  ) {
    if (config.confirmBeforeClear) {
      return _buildClearButtonWithConfirmation(context, theme, isCompact);
    }

    final iconSize = isCompact ? _compactIconSize : _standardIconSize;
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      icon: Icon(
        Icons.clear,
        size: iconSize,
        color: onClearPressed != null
            ? theme.colorScheme.onSurface.withOpacity(0.6)
            : theme.colorScheme.onSurface.withOpacity(0.3),
      ),
      tooltip: l10n.toolbar_clear,
      onPressed: onClearPressed,
      visualDensity: VisualDensity.compact,
      constraints:
          isCompact ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
      padding: isCompact ? const EdgeInsets.all(4) : null,
    );
  }

  /// 构建带确认的清空按钮
  Widget _buildClearButtonWithConfirmation(
    BuildContext context,
    ThemeData theme,
    bool isCompact,
  ) {
    final iconSize = isCompact ? _compactIconSize : _standardIconSize;
    final menuOffset = isCompact ? 32.0 : 40.0;
    final l10n = AppLocalizations.of(context)!;

    return PopupMenuButton<bool>(
      icon: Icon(
        Icons.clear,
        size: iconSize,
        color: onClearPressed != null
            ? theme.colorScheme.onSurface.withOpacity(0.6)
            : theme.colorScheme.onSurface.withOpacity(0.3),
      ),
      tooltip: l10n.toolbar_clear,
      enabled: onClearPressed != null,
      offset: Offset(0, menuOffset),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      constraints:
          isCompact ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
      padding: isCompact ? const EdgeInsets.all(4) : const EdgeInsets.all(8),
      itemBuilder: (context) => [
        PopupMenuItem<bool>(
          value: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline,
                size: isCompact ? 16 : 18,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.toolbar_confirmClear,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value) {
          onClearPressed?.call();
        }
      },
    );
  }

  /// 构建设置按钮
  ///
  /// 使用 Builder 包装以获取正确的按钮位置上下文
  Widget _buildSettingsButton(
    BuildContext context,
    ThemeData theme,
    bool isCompact,
  ) {
    final iconSize = isCompact ? _compactIconSize : _standardIconSize;
    final l10n = AppLocalizations.of(context)!;

    return Builder(
      builder: (buttonContext) => IconButton(
        icon: Icon(
          Icons.settings,
          size: iconSize,
          color: onSettingsPressed != null
              ? theme.colorScheme.onSurface.withOpacity(0.6)
              : theme.colorScheme.onSurface.withOpacity(0.3),
        ),
        tooltip: l10n.toolbar_settings,
        onPressed: onSettingsPressed != null
            ? () => _invokeSettingsWithContext(buttonContext)
            : null,
        visualDensity: VisualDensity.compact,
        constraints: isCompact
            ? const BoxConstraints(minWidth: 32, minHeight: 32)
            : null,
        padding: isCompact ? const EdgeInsets.all(4) : null,
      ),
    );
  }

  /// 使用按钮上下文调用设置回调
  ///
  /// 将按钮的 BuildContext 存储到静态变量中，供外部获取菜单位置
  void _invokeSettingsWithContext(BuildContext buttonContext) {
    _lastSettingsButtonContext = buttonContext;
    onSettingsPressed?.call();
  }

  /// 最后一次点击设置按钮的上下文（用于定位菜单）
  static BuildContext? _lastSettingsButtonContext;

  /// 获取设置按钮的位置，用于显示菜单
  ///
  /// 返回相对于 overlay 的位置矩形，菜单应显示在按钮下方
  static RelativeRect? getSettingsButtonPosition(BuildContext overlayContext) {
    final buttonContext = _lastSettingsButtonContext;
    if (buttonContext == null) return null;

    final RenderBox? button = buttonContext.findRenderObject() as RenderBox?;
    final RenderBox? overlay =
        Overlay.of(overlayContext).context.findRenderObject() as RenderBox?;

    if (button == null || overlay == null) return null;

    // 计算按钮在 overlay 中的位置
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonSize = button.size;

    // 菜单显示在按钮正下方，右对齐
    return RelativeRect.fromLTRB(
      buttonPosition.dx + buttonSize.width - 220, // 菜单宽度约 220
      buttonPosition.dy + buttonSize.height + 4, // 按钮下方 4px
      overlay.size.width - buttonPosition.dx - buttonSize.width,
      0,
    );
  }
}

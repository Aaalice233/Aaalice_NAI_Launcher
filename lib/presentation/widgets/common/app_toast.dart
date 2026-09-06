import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../adaptive/interaction_policy.dart';
import '../../adaptive/window_size_class.dart';

/// Toast 类型
enum ToastType { success, error, warning, info, progress }

/// Toast 控制器接口，用于控制持久化 Toast（如进度条）
abstract class ToastController {
  /// 更新进度
  /// [progress] 0.0-1.0，null 表示不确定进度
  void updateProgress(double? progress, {String? message, String? subtitle});

  /// 完成，变为 success 并自动消失
  void complete({String? message});

  /// 失败，变为 error 并自动消失
  void fail({String? message});

  /// 直接关闭
  void dismiss();
}

/// 真实的 Toast 控制器实现
class _RealToastController implements ToastController {
  final _ProgressToastWidgetState _state;

  _RealToastController._(this._state);

  @override
  void updateProgress(double? progress, {String? message, String? subtitle}) {
    _state._updateProgress(progress, message: message, subtitle: subtitle);
  }

  @override
  void complete({String? message}) {
    _state._complete(message: message);
  }

  @override
  void fail({String? message}) {
    _state._fail(message: message);
  }

  @override
  void dismiss() {
    _state._dismiss();
  }
}

/// 代理控制器，允许在真实控制器创建前就返回
class _ProxyToastController implements ToastController {
  ToastController? _real;
  final List<void Function(ToastController)> _pendingCalls = [];

  void _setReal(ToastController real) {
    _real = real;
    for (final call in _pendingCalls) {
      call(real);
    }
    _pendingCalls.clear();
  }

  void _enqueue(void Function(ToastController) call) {
    if (_real != null) {
      call(_real!);
    } else {
      _pendingCalls.add(call);
    }
  }

  @override
  void updateProgress(double? progress, {String? message, String? subtitle}) {
    _enqueue(
      (c) => c.updateProgress(progress, message: message, subtitle: subtitle),
    );
  }

  @override
  void complete({String? message}) {
    _enqueue((c) => c.complete(message: message));
  }

  @override
  void fail({String? message}) {
    _enqueue((c) => c.fail(message: message));
  }

  @override
  void dismiss() {
    _enqueue((c) => c.dismiss());
  }
}

/// 空操作控制器，当没有 Overlay 时使用
class _NoOpToastController implements ToastController {
  @override
  void updateProgress(double? progress, {String? message, String? subtitle}) {}

  @override
  void complete({String? message}) {}

  @override
  void fail({String? message}) {}

  @override
  void dismiss() {}
}

/// 全局 Toast 通知服务
/// 桌面端与移动端均显示顶部可堆叠 Toast，避免遮挡底部主操作区。
class AppToast {
  static OverlayEntry? _progressEntry;
  static OverlayEntry? _toastStackEntry;
  static OverlayState? _toastOverlay;
  static final List<_ActiveToast> _activeToasts = [];

  /// 显示成功通知
  static void success(BuildContext context, String message) {
    _show(context, message, ToastType.success);
  }

  /// 显示错误通知
  static void error(BuildContext context, String message) {
    _show(context, message, ToastType.error);
  }

  static void successOnOverlay(OverlayState? overlay, String message) {
    _showOnOverlay(overlay, message, ToastType.success);
  }

  static void errorOnOverlay(OverlayState? overlay, String message) {
    _showOnOverlay(overlay, message, ToastType.error);
  }

  /// 显示警告通知
  static void warning(BuildContext context, String message) {
    _show(context, message, ToastType.warning);
  }

  /// 显示信息通知
  static void info(BuildContext context, String message) {
    _show(context, message, ToastType.info);
  }

  /// 显示持久化进度 Toast
  /// 返回 ToastController 用于更新进度或关闭
  /// [progress] 0.0-1.0，null 表示不确定进度
  static ToastController showProgress(
    BuildContext context,
    String message, {
    double? progress,
    String? subtitle,
  }) {
    // 进度通知是单例。替换时让旧控制器随旧 Entry 一并失效，
    // 避免旧任务稍后 dismiss/complete 误删新任务的通知。
    if (_progressEntry?.mounted == true) _progressEntry!.remove();
    _progressEntry = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      // 如果没有 Overlay，返回一个空操作的控制器
      return _NoOpToastController();
    }

    // 创建一个同步可用的控制器
    final proxyController = _ProxyToastController();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ProgressToastWidget(
        initialMessage: message,
        initialProgress: progress,
        initialSubtitle: subtitle,
        onControllerCreated: (c) => proxyController._setReal(c),
        onDismiss: () {
          if (_progressEntry != entry) return;
          if (entry.mounted) entry.remove();
          _progressEntry = null;
        },
      ),
    );

    _progressEntry = entry;
    overlay.insert(entry);
    return proxyController;
  }

  static void _show(BuildContext context, String message, ToastType type) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    _showToastInOverlay(overlay, message, type);
  }

  static void _showOnOverlay(
    OverlayState? overlay,
    String message,
    ToastType type,
  ) {
    if (overlay == null || !overlay.mounted) {
      return;
    }
    _showToastInOverlay(overlay, message, type);
  }

  /// 用于生成唯一 toast ID 的计数器
  static int _toastIdCounter = 0;

  static void _showToastInOverlay(
    OverlayState overlay,
    String message,
    ToastType type,
  ) {
    // Overlay roots can be replaced by router or test lifecycles. Never carry
    // stale toast widgets into the new root.
    if (_toastOverlay != overlay) {
      if (_toastStackEntry?.mounted == true) _toastStackEntry!.remove();
      _toastStackEntry = null;
      _toastOverlay = overlay;
      _activeToasts.clear();
    }

    // 使用递增计数器确保 ID 唯一，避免同一毫秒内创建的 toast 有相同 ID
    final id = _toastIdCounter++;

    _activeToasts.add(_ActiveToast(id: id, message: message, type: type));

    final currentEntry = _toastStackEntry;
    if (currentEntry != null) {
      currentEntry.markNeedsBuild();
      return;
    }

    _toastStackEntry = OverlayEntry(
      builder: (context) => _ToastStack(
        toasts: List<_ActiveToast>.of(_activeToasts),
        onDismiss: _dismissToast,
      ),
    );
    overlay.insert(_toastStackEntry!);
  }

  static void _dismissToast(int id) {
    _activeToasts.removeWhere((toast) => toast.id == id);
    if (_activeToasts.isEmpty) {
      if (_toastStackEntry?.mounted == true) _toastStackEntry!.remove();
      _toastStackEntry = null;
      _toastOverlay = null;
      return;
    }
    _toastStackEntry?.markNeedsBuild();
  }
}

class _ActiveToast {
  const _ActiveToast({
    required this.id,
    required this.message,
    required this.type,
  });

  final int id;
  final String message;
  final ToastType type;
}

class _ToastStack extends StatelessWidget {
  const _ToastStack({required this.toasts, required this.onDismiss});

  final List<_ActiveToast> toasts;
  final ValueChanged<int> onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final policy = context.interactionPolicy;
            final sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);
            final horizontalInset = sizeClass.isCompact ? 12.0 : 16.0;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalInset,
                sizeClass.isCompact ? 12 : 16,
                horizontalInset,
                12,
              ),
              child: Align(
                alignment: policy.usesAnchoredMenus
                    ? Alignment.topRight
                    : Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: sizeClass.isCompact ? constraints.maxWidth : 360,
                    maxHeight: constraints.maxHeight,
                  ),
                  child: SingleChildScrollView(
                    primary: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final toast in toasts) ...[
                          _SingleToastWidget(
                            key: ValueKey(toast.id),
                            message: toast.message,
                            type: toast.type,
                            onDismiss: () => onDismiss(toast.id),
                          ),
                          if (toast != toasts.last) const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 单个 Toast Widget
class _SingleToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const _SingleToastWidget({
    super.key,
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_SingleToastWidget> createState() => _SingleToastWidgetState();
}

class _SingleToastWidgetState extends State<_SingleToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _entranceStarted = false;
  bool _isDismissing = false;
  bool _supportsHover = false;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _scheduleAutoDismiss();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final supportsHover = context.interactionPolicy.precisePointerAvailable;
    if (_supportsHover && !supportsHover && _autoDismissTimer == null) {
      _scheduleAutoDismiss();
    }
    _supportsHover = supportsHover;
    if (_entranceStarted) return;
    _entranceStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  void _scheduleAutoDismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 3), _dismiss);
  }

  void _handleHoverEnter(PointerEnterEvent event) {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
  }

  void _handleHoverExit(PointerExitEvent event) {
    if (!_isDismissing) _scheduleAutoDismiss();
  }

  void _dismiss() {
    if (!mounted || _isDismissing) return;
    _isDismissing = true;
    _autoDismissTimer?.cancel();
    final reverse = MediaQuery.disableAnimationsOf(context)
        ? _controller.animateBack(0, duration: Duration.zero)
        : _controller.reverse();
    reverse.then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _getTypeStyle(theme, widget.type);
    final policy = context.interactionPolicy;

    return MouseRegion(
      onEnter: policy.precisePointerAvailable ? _handleHoverEnter : null,
      onExit: policy.precisePointerAvailable ? _handleHoverExit : null,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                decoration: BoxDecoration(
                  color: style.container,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(style.icon, color: style.foreground, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: style.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _dismiss,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: style.foreground,
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: Size.square(
                          context.interactionPolicy.minimumControlExtent,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 进度 Toast Widget（持久化，需要手动关闭）
class _ProgressToastWidget extends StatefulWidget {
  final String initialMessage;
  final double? initialProgress;
  final String? initialSubtitle;
  final void Function(ToastController) onControllerCreated;
  final VoidCallback onDismiss;

  const _ProgressToastWidget({
    required this.initialMessage,
    required this.initialProgress,
    required this.initialSubtitle,
    required this.onControllerCreated,
    required this.onDismiss,
  });

  @override
  State<_ProgressToastWidget> createState() => _ProgressToastWidgetState();
}

class _ProgressToastWidgetState extends State<_ProgressToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _entranceStarted = false;
  bool _supportsHover = false;

  late String _message;
  double? _progress;
  String? _subtitle;
  ToastType _type = ToastType.progress;
  bool _autoClose = false;
  bool _isDismissing = false;
  Timer? _autoCloseTimer;
  Duration? _autoCloseDuration;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
    _progress = widget.initialProgress?.clamp(0, 1);
    _subtitle = widget.initialSubtitle;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // 创建控制器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onControllerCreated(_RealToastController._(this));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final supportsHover = context.interactionPolicy.precisePointerAvailable;
    final autoCloseDuration = _autoCloseDuration;
    if (_supportsHover &&
        !supportsHover &&
        _autoClose &&
        _autoCloseTimer == null &&
        autoCloseDuration != null) {
      _scheduleAutoClose(autoCloseDuration);
    }
    _supportsHover = supportsHover;
    if (_entranceStarted) return;
    _entranceStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  void _updateProgress(double? progress, {String? message, String? subtitle}) {
    if (!mounted || _type != ToastType.progress || _isDismissing) return;
    setState(() {
      _progress = progress?.clamp(0, 1);
      if (message != null) _message = message;
      if (subtitle != null) _subtitle = subtitle;
    });
  }

  void _complete({String? message}) {
    if (!mounted || _type != ToastType.progress || _isDismissing) return;
    setState(() {
      _type = ToastType.success;
      _progress = 1.0;
      _subtitle = null;
      if (message != null) _message = message;
      _autoClose = true;
    });
    _scheduleAutoClose(const Duration(seconds: 2));
  }

  void _fail({String? message}) {
    if (!mounted || _type != ToastType.progress || _isDismissing) return;
    setState(() {
      _type = ToastType.error;
      _progress = null;
      _subtitle = null;
      if (message != null) _message = message;
      _autoClose = true;
    });
    _scheduleAutoClose(const Duration(seconds: 3));
  }

  void _scheduleAutoClose(Duration duration) {
    _autoCloseDuration = duration;
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(duration, _dismiss);
  }

  void _handleHoverEnter(PointerEnterEvent event) {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = null;
  }

  void _handleHoverExit(PointerExitEvent event) {
    final duration = _autoCloseDuration;
    if (!_isDismissing && _autoClose && duration != null) {
      _scheduleAutoClose(duration);
    }
  }

  void _dismiss() {
    if (!mounted || _isDismissing) return;
    _isDismissing = true;
    _autoCloseTimer?.cancel();
    final reverse = MediaQuery.disableAnimationsOf(context)
        ? _controller.animateBack(0, duration: Duration.zero)
        : _controller.reverse();
    reverse.then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final policy = context.interactionPolicy;
    return Positioned.fill(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);
            final inset = sizeClass.isCompact ? 12.0 : 16.0;
            return Padding(
              padding: EdgeInsets.all(inset),
              child: Align(
                alignment: policy.usesAnchoredMenus
                    ? Alignment.topRight
                    : Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: sizeClass.isCompact ? constraints.maxWidth : 360,
                  ),
                  child: policy.precisePointerAvailable
                      ? MouseRegion(
                          onEnter: _handleHoverEnter,
                          onExit: _handleHoverExit,
                          child: _buildProgressSurface(context, policy),
                        )
                      : _buildProgressSurface(context, policy),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressSurface(BuildContext context, InteractionPolicy policy) {
    final theme = Theme.of(context);
    final style = _getTypeStyle(theme, _type);
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            container: true,
            liveRegion: true,
            label: _subtitle == null ? _message : '$_message. $_subtitle',
            value: _type == ToastType.progress && _progress != null
                ? '${(_progress! * 100).round()}%'
                : null,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: style.container,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.icon, color: style.accent, size: 20),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          _message,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: style.foreground,
                          ),
                        ),
                      ),
                      if (!_autoClose) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _dismiss,
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          style: IconButton.styleFrom(
                            minimumSize: Size.square(
                              policy.minimumControlExtent,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: style.foreground,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_subtitle != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: Text(
                        _subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: style.foreground,
                        ),
                      ),
                    ),
                  ],
                  if (_type == ToastType.progress && _progress != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: style.foreground.withValues(
                          alpha: 0.16,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(style.accent),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastVisualStyle {
  const _ToastVisualStyle({
    required this.icon,
    required this.container,
    required this.foreground,
    required this.accent,
  });

  final IconData icon;
  final Color container;
  final Color foreground;
  final Color accent;
}

/// Brand accents do not encode status. Keep status hues stable across themes
/// and use complete light/dark pairs to preserve text contrast.
_ToastVisualStyle _getTypeStyle(ThemeData theme, ToastType type) {
  final colors = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  return switch (type) {
    ToastType.success => _ToastVisualStyle(
      icon: Icons.check_circle_rounded,
      container: dark ? const Color(0xFF163A24) : const Color(0xFFE8F5E9),
      foreground: dark ? const Color(0xFFA5D6A7) : const Color(0xFF1B5E20),
      accent: dark ? const Color(0xFFA5D6A7) : const Color(0xFF1B5E20),
    ),
    ToastType.error => _ToastVisualStyle(
      icon: Icons.cancel_rounded,
      container: colors.errorContainer,
      foreground: colors.onErrorContainer,
      accent: colors.onErrorContainer,
    ),
    ToastType.warning => _ToastVisualStyle(
      icon: Icons.warning_rounded,
      container: dark ? const Color(0xFF3D2E08) : const Color(0xFFFFF8E1),
      foreground: dark ? const Color(0xFFFFE082) : const Color(0xFF6D4C00),
      accent: dark ? const Color(0xFFFFE082) : const Color(0xFF6D4C00),
    ),
    ToastType.info => _ToastVisualStyle(
      icon: Icons.info_rounded,
      container: dark ? const Color(0xFF102F4A) : const Color(0xFFE3F2FD),
      foreground: dark ? const Color(0xFF90CAF9) : const Color(0xFF0D47A1),
      accent: dark ? const Color(0xFF90CAF9) : const Color(0xFF0D47A1),
    ),
    ToastType.progress => _ToastVisualStyle(
      icon: Icons.downloading_rounded,
      container: colors.surfaceContainerHigh,
      foreground: colors.onSurface,
      accent: colors.onSurfaceVariant,
    ),
  };
}

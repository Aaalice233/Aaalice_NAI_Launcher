import 'dart:io';

import 'package:flutter/material.dart';

/// Toast 类型
enum ToastType {
  success,
  error,
  warning,
  info,
  progress,
}

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
/// 桌面端显示右上角可堆叠toast，移动端显示底部SnackBar
class AppToast {
  static OverlayEntry? _progressEntry;
  static final List<_ActiveToast> _activeToasts = [];

  /// 判断是否为桌面端
  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// 显示成功通知
  static void success(BuildContext context, String message) {
    _show(context, message, ToastType.success);
  }

  /// 显示错误通知
  static void error(BuildContext context, String message) {
    _show(context, message, ToastType.error);
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
    // 如果已有进度 Toast，先移除
    _progressEntry?.remove();
    _progressEntry = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      // 如果没有 Overlay，返回一个空操作的控制器
      return _NoOpToastController();
    }

    // 创建一个同步可用的控制器
    final proxyController = _ProxyToastController();

    _progressEntry = OverlayEntry(
      builder: (context) => _ProgressToastWidget(
        initialMessage: message,
        initialProgress: progress,
        initialSubtitle: subtitle,
        onControllerCreated: (c) => proxyController._setReal(c),
        onDismiss: () {
          _progressEntry?.remove();
          _progressEntry = null;
        },
      ),
    );

    overlay.insert(_progressEntry!);
    return proxyController;
  }

  static void _show(BuildContext context, String message, ToastType type) {
    if (_isDesktop) {
      _showDesktopToast(context, message, type);
    } else {
      _showMobileSnackBar(context, message, type);
    }
  }

  /// 用于生成唯一 toast ID 的计数器
  static int _toastIdCounter = 0;

  /// 桌面端：右上角堆叠toast
  static void _showDesktopToast(
    BuildContext context,
    String message,
    ToastType type,
  ) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    // 使用递增计数器确保 ID 唯一，避免同一毫秒内创建的 toast 有相同 ID
    final id = _toastIdCounter++;

    // 先创建 ActiveToast，entry 先为占位符
    final activeToast = _ActiveToast(
      id: id,
      entry: OverlayEntry(builder: (_) => const SizedBox.shrink()),
    );
    _activeToasts.add(activeToast);

    // 创建真正的 entry
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        // 动态计算当前 index，确保在 markNeedsBuild 后位置能正确更新
        final currentIndex = _activeToasts.indexWhere((t) => t.id == id);
        return _SingleToastWidget(
          key: ValueKey(id),
          message: message,
          type: type,
          index: currentIndex,
          onDismiss: () {
            entry.remove();
            _activeToasts.remove(activeToast);
            // 更新其他 toast 的位置
            for (final toast in _activeToasts) {
              toast.entry.markNeedsBuild();
            }
          },
        );
      },
    );

    // 更新 ActiveToast 的 entry
    activeToast.entry = entry;

    overlay.insert(entry);
  }

  /// 移动端：底部SnackBar
  static void _showMobileSnackBar(
    BuildContext context,
    String message,
    ToastType type,
  ) {
    final (icon, color) = _getTypeStyle(Theme.of(context), type);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _ActiveToast {
  final int id;
  OverlayEntry entry;

  _ActiveToast({required this.id, required this.entry});
}

/// 单个 Toast Widget（桌面端纯色背景样式）
class _SingleToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;
  final int index;

  const _SingleToastWidget({
    super.key,
    required this.message,
    required this.type,
    required this.onDismiss,
    required this.index,
  });

  @override
  State<_SingleToastWidget> createState() => _SingleToastWidgetState();
}

class _SingleToastWidgetState extends State<_SingleToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

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
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();

    // 自动消失
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _getTypeStyle(Theme.of(context), widget.type);
    final topOffset = 16.0 + (widget.index >= 0 ? widget.index : 0) * 64.0;

    return Positioned(
      top: topOffset,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _dismiss,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
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

  late String _message;
  double? _progress;
  String? _subtitle;
  ToastType _type = ToastType.progress;
  bool _autoClose = false;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
    _progress = widget.initialProgress;
    _subtitle = widget.initialSubtitle;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();

    // 创建控制器
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onControllerCreated(_RealToastController._(this));
    });
  }

  void _updateProgress(double? progress, {String? message, String? subtitle}) {
    if (!mounted) return;
    setState(() {
      _progress = progress;
      if (message != null) _message = message;
      if (subtitle != null) _subtitle = subtitle;
    });
  }

  void _complete({String? message}) {
    if (!mounted) return;
    setState(() {
      _type = ToastType.success;
      _progress = 1.0;
      if (message != null) _message = message;
      _autoClose = true;
    });
    Future.delayed(const Duration(seconds: 2), _dismiss);
  }

  void _fail({String? message}) {
    if (!mounted) return;
    setState(() {
      _type = ToastType.error;
      _progress = null;
      _subtitle = null;
      if (message != null) _message = message;
      _autoClose = true;
    });
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _getTypeStyle(theme, _type);

    return Positioned(
      bottom: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360, minWidth: 240),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _type == ToastType.progress
                    ? theme.colorScheme.surfaceContainerHigh
                    : color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (_type == ToastType.progress ? Colors.black : color)
                        .withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: 2,
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
                      if (_type == ToastType.progress)
                        Icon(Icons.downloading_rounded, color: color, size: 20)
                      else
                        Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          _message,
                          style: TextStyle(
                            color: _type == ToastType.progress
                                ? theme.colorScheme.onSurface
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (!_autoClose) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _dismiss,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: _type == ToastType.progress
                                  ? theme.colorScheme.onSurfaceVariant
                                  : Colors.white70,
                            ),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: _type == ToastType.progress
                              ? theme.colorScheme.onSurfaceVariant
                              : Colors.white70,
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
                        backgroundColor: color.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
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

/// 获取类型对应的图标和颜色
(IconData, Color) _getTypeStyle(ThemeData theme, ToastType type) {
  switch (type) {
    case ToastType.success:
      return (Icons.check_circle_rounded, const Color(0xFF4CAF50));
    case ToastType.error:
      return (Icons.cancel_rounded, const Color(0xFFE53935));
    case ToastType.warning:
      return (Icons.warning_rounded, const Color(0xFFFF9800));
    case ToastType.info:
      return (Icons.info_rounded, const Color(0xFF2196F3));
    case ToastType.progress:
      return (Icons.hourglass_empty_rounded, theme.colorScheme.primary);
  }
}

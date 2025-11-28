import 'package:flutter/material.dart';

/// Toast 类型
enum ToastType {
  success,
  error,
  warning,
  info,
}

/// 全局 Toast 通知服务
class AppToast {
  static OverlayEntry? _currentEntry;
  static final List<_ToastData> _queue = [];
  static bool _isShowing = false;

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

  static void _show(BuildContext context, String message, ToastType type) {
    _queue.add(_ToastData(context: context, message: message, type: type));
    _processQueue();
  }

  static void _processQueue() {
    if (_isShowing || _queue.isEmpty) return;

    _isShowing = true;
    final data = _queue.removeAt(0);

    final overlay = Overlay.of(data.context, rootOverlay: true);
    _currentEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: data.message,
        type: data.type,
        onDismiss: () {
          _currentEntry?.remove();
          _currentEntry = null;
          _isShowing = false;
          // 处理队列中的下一个
          Future.delayed(const Duration(milliseconds: 100), _processQueue);
        },
      ),
    );

    overlay.insert(_currentEntry!);
  }
}

class _ToastData {
  final BuildContext context;
  final String message;
  final ToastType type;

  _ToastData({
    required this.context,
    required this.message,
    required this.type,
  });
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
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
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

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
    final theme = Theme.of(context);
    final (icon, color) = _getTypeStyle(theme);

    return Positioned(
      top: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360, minWidth: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color.withOpacity(0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _dismiss,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
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

  (IconData, Color) _getTypeStyle(ThemeData theme) {
    switch (widget.type) {
      case ToastType.success:
        return (Icons.check_circle_outline, const Color(0xFF4CAF50));
      case ToastType.error:
        return (Icons.error_outline, theme.colorScheme.error);
      case ToastType.warning:
        return (Icons.warning_amber_outlined, const Color(0xFFFF9800));
      case ToastType.info:
        return (Icons.info_outline, theme.colorScheme.primary);
    }
  }
}

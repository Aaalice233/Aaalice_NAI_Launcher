import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'dart:async';

import 'package:flutter/material.dart';

/// 进度通知状态
enum ProgressNotificationState {
  pending,
  running,
  completed,
  failed,
}

/// 进度通知数据
class ProgressNotificationData {
  final String id;
  final String title;
  final String? subtitle;
  final double? progress;
  final ProgressNotificationState state;
  final DateTime startTime;
  final DateTime? endTime;
  final String? error;

  const ProgressNotificationData({
    required this.id,
    required this.title,
    this.subtitle,
    this.progress,
    this.state = ProgressNotificationState.pending,
    required this.startTime,
    this.endTime,
    this.error,
  });

  ProgressNotificationData copyWith({
    String? id,
    String? title,
    String? subtitle,
    double? progress,
    ProgressNotificationState? state,
    DateTime? startTime,
    DateTime? endTime,
    String? error,
  }) {
    return ProgressNotificationData(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      progress: progress ?? this.progress,
      state: state ?? this.state,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      error: error ?? this.error,
    );
  }

  /// 格式化的进度文本
  String? get progressText {
    if (progress == null) return null;
    return '${(progress! * 100).toInt()}%';
  }

  /// 运行时长
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }
}

/// 进度通知控制器
abstract class ProgressNotificationController {
  /// 更新进度 (0.0-1.0)
  void updateProgress(double progress, {String? subtitle});

  /// 更新副标题
  void updateSubtitle(String subtitle);

  /// 标记为完成
  void complete({String? title});

  /// 标记为失败
  void fail({String? title, String? error});

  /// 关闭通知
  void dismiss();
}

/// 进度通知管理器
/// 用于管理右下角进度通知队列
class ProgressNotificationManager extends ChangeNotifier {
  static final ProgressNotificationManager _instance =
      ProgressNotificationManager._internal();

  factory ProgressNotificationManager() => _instance;

  ProgressNotificationManager._internal();

  final Map<String, ProgressNotificationData> _notifications = {};
  final Map<String, _ProgressNotificationControllerImpl> _controllers = {};

  /// 所有通知
  List<ProgressNotificationData> get notifications =>
      _notifications.values.toList();

  /// 活动通知数量
  int get activeCount => _notifications.length;

  /// 是否有活动通知
  bool get hasActiveNotifications => _notifications.isNotEmpty;

  /// 创建新通知
  ProgressNotificationController show({
    required String id,
    required String title,
    String? subtitle,
    double? initialProgress,
  }) {
    // 如果已存在同ID通知，先移除
    if (_notifications.containsKey(id)) {
      dismiss(id);
    }

    final notification = ProgressNotificationData(
      id: id,
      title: title,
      subtitle: subtitle,
      progress: initialProgress,
      state: ProgressNotificationState.running,
      startTime: DateTime.now(),
    );

    _notifications[id] = notification;
    notifyListeners();

    final controller = _ProgressNotificationControllerImpl(this, id);
    _controllers[id] = controller;
    return controller;
  }

  /// 更新进度
  void updateProgress(String id, double progress, {String? subtitle}) {
    final notification = _notifications[id];
    if (notification == null) return;

    _notifications[id] = notification.copyWith(
      progress: progress,
      subtitle: subtitle,
      state: ProgressNotificationState.running,
    );
    notifyListeners();
  }

  /// 更新副标题
  void updateSubtitle(String id, String subtitle) {
    final notification = _notifications[id];
    if (notification == null) return;

    _notifications[id] = notification.copyWith(subtitle: subtitle);
    notifyListeners();
  }

  /// 标记为完成
  void complete(String id, {String? title}) {
    final notification = _notifications[id];
    if (notification == null) return;

    _notifications[id] = notification.copyWith(
      title: title ?? notification.title,
      progress: 1.0,
      state: ProgressNotificationState.completed,
      endTime: DateTime.now(),
    );
    notifyListeners();

    // 自动移除
    Timer(const Duration(seconds: 2), () => dismiss(id));
  }

  /// 标记为失败
  void fail(String id, {String? title, String? error}) {
    final notification = _notifications[id];
    if (notification == null) return;

    _notifications[id] = notification.copyWith(
      title: title ?? notification.title,
      state: ProgressNotificationState.failed,
      endTime: DateTime.now(),
      error: error,
    );
    notifyListeners();

    // 自动移除
    Timer(const Duration(seconds: 3), () => dismiss(id));
  }

  /// 关闭通知
  void dismiss(String id) {
    _controllers.remove(id);
    if (_notifications.remove(id) != null) {
      notifyListeners();
    }
  }

  /// 关闭所有通知
  void dismissAll() {
    _controllers.clear();
    _notifications.clear();
    notifyListeners();
  }
}

/// 控制器实现
class _ProgressNotificationControllerImpl
    implements ProgressNotificationController {
  final ProgressNotificationManager _manager;
  final String _id;

  _ProgressNotificationControllerImpl(this._manager, this._id);

  @override
  void updateProgress(double progress, {String? subtitle}) {
    _manager.updateProgress(_id, progress, subtitle: subtitle);
  }

  @override
  void updateSubtitle(String subtitle) {
    _manager.updateSubtitle(_id, subtitle);
  }

  @override
  void complete({String? title}) {
    _manager.complete(_id, title: title);
  }

  @override
  void fail({String? title, String? error}) {
    _manager.fail(_id, title: title, error: error);
  }

  @override
  void dismiss() {
    _manager.dismiss(_id);
  }
}

/// 全局进度通知覆盖层
/// 放置在应用顶层，监听 ProgressNotificationManager
class GlobalProgressNotificationOverlay extends StatefulWidget {
  final Widget child;

  const GlobalProgressNotificationOverlay({
    super.key,
    required this.child,
  });

  @override
  State<GlobalProgressNotificationOverlay> createState() =>
      _GlobalProgressNotificationOverlayState();
}

class _GlobalProgressNotificationOverlayState
    extends State<GlobalProgressNotificationOverlay> {
  late ProgressNotificationManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = ProgressNotificationManager();
    _manager.addListener(_onManagerChanged);
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerChanged);
    super.dispose();
  }

  void _onManagerChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_manager.hasActiveNotifications)
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _manager.notifications.reversed.map((notification) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ProgressNotificationCard(
                    data: notification,
                    onDismiss: () => _manager.dismiss(notification.id),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

/// 单个进度通知卡片
class _ProgressNotificationCard extends StatelessWidget {
  final ProgressNotificationData data;
  final VoidCallback onDismiss;

  const _ProgressNotificationCard({
    required this.data,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = data.state == ProgressNotificationState.failed;
    final isSuccess = data.state == ProgressNotificationState.completed;
    final isRunning = data.state == ProgressNotificationState.running;

    final backgroundColor = isError
        ? const Color(0xFFE53935)
        : isSuccess
            ? const Color(0xFF4CAF50)
            : theme.colorScheme.surfaceContainerHigh;

    final textColor =
        isError || isSuccess ? Colors.white : theme.colorScheme.onSurface;

    final iconColor =
        isError || isSuccess ? Colors.white : theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360, minWidth: 240),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (isError || isSuccess ? backgroundColor : Colors.black)
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
                if (isRunning)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: data.progress != null
                        ? CircularProgressIndicator(
                            value: data.progress,
                            strokeWidth: 2,
                            color: iconColor,
                          )
                        : CircularProgressIndicator(
                            strokeWidth: 2,
                            color: iconColor,
                          ),
                  )
                else
                  Icon(
                    isError ? Icons.cancel_rounded : Icons.check_circle_rounded,
                    color: iconColor,
                    size: 20,
                  ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    data.title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (!isSuccess && !isError) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onDismiss,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: isError || isSuccess
                            ? Colors.white70
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (data.subtitle != null && isRunning) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(
                  data.subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isError || isSuccess
                        ? Colors.white70
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (isRunning && data.progress != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: data.progress,
                  backgroundColor: iconColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  data.progressText ?? '',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isError || isSuccess
                        ? Colors.white70
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 便捷扩展方法
extension ProgressNotificationManagerExtension on BuildContext {
  /// 显示进度通知
  ProgressNotificationController showProgressNotification({
    required String id,
    required String title,
    String? subtitle,
    double? initialProgress,
  }) {
    return ProgressNotificationManager().show(
      id: id,
      title: title,
      subtitle: subtitle,
      initialProgress: initialProgress,
    );
  }

  /// 显示带操作的进度通知（带取消按钮等）
  ProgressNotificationController showCancellableProgress({
    required String id,
    required String title,
    String? subtitle,
    double? initialProgress,
    VoidCallback? onCancel,
  }) {
    final controller = ProgressNotificationManager().show(
      id: id,
      title: title,
      subtitle: subtitle,
      initialProgress: initialProgress,
    );

    // TODO: 如果需要取消按钮，可以扩展通知卡片
    return controller;
  }
}

/// 异步任务包装器，自动处理进度通知
class ProgressTaskWrapper<T> {
  final String id;
  final String title;
  final BuildContext context;
  ProgressNotificationController? _controller;

  ProgressTaskWrapper({
    required this.id,
    required this.title,
    required this.context,
  });

  /// 执行任务
  Future<T?> run(
      Future<T> Function(ProgressNotificationController) task) async {
    // 在异步操作前获取本地化字符串
    final l10n = context.l10n;

    _controller = context.showProgressNotification(
      id: id,
      title: title,
    );

    try {
      final result = await task(_controller!);
      _controller!.complete(
        title: l10n.download_completed(title),
      );
      return result;
    } catch (e) {
      _controller!.fail(
        title: l10n.download_failed(title),
        error: e.toString(),
      );
      return null;
    }
  }

  /// 更新进度
  void updateProgress(double progress, {String? subtitle}) {
    _controller?.updateProgress(progress, subtitle: subtitle);
  }

  /// 取消通知
  void cancel() {
    _controller?.dismiss();
  }
}

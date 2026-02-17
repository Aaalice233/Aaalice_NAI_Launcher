import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage_service.dart';
import '../../providers/floating_button_position_provider.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../router/app_router.dart';
import 'floating_button_long_press_menu.dart';

/// 队列悬浮球组件 - 精致现代风格设计
///
/// 特性:
/// - 现代化玻璃质感球体设计
/// - 动态播放/暂停图标动画
/// - 多状态颜色和动画指示
/// - 圆形进度环显示执行进度
/// - 拖拽移动并记住位置
/// - 悬停效果和平滑交互反馈
/// - 兼容所有主题系统
class FloatingQueueButton extends ConsumerStatefulWidget {
  /// 点击回调（打开队列管理页面）
  final VoidCallback? onTap;

  /// 容器大小（用于计算悬浮球位置）
  final Size? containerSize;

  const FloatingQueueButton({
    super.key,
    this.onTap,
    this.containerSize,
  });

  @override
  ConsumerState<FloatingQueueButton> createState() =>
      _FloatingQueueButtonState();
}

class _FloatingQueueButtonState extends ConsumerState<FloatingQueueButton>
    with TickerProviderStateMixin {
  bool _isDragging = false;
  bool _isHovering = false;
  bool _isInitialized = false;
  Offset _dragOffset = Offset.zero;

  // 悬浮球尺寸常量
  static const double _ballSize = 56.0;
  static const double _totalSize = 80.0;
  static const double _progressStrokeWidth = 3.0;

  // 动画控制器
  late final AnimationController _pulseController;
  late final AnimationController _glowController;
  late final AnimationController _hoverController;
  late final AnimationController _rotationController;

  // 动画
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _hoverAnimation;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    // 脉冲动画 - 运行时的波纹效果
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // 发光强度动画
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // 悬停缩放动画
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _hoverAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );

    // 旋转动画 - 运行时的loading环
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    _isInitialized = true;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _hoverController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final screenSize = MediaQuery.of(context).size;
        ref
            .read(floatingButtonPositionNotifierProvider.notifier)
            .initializePosition(screenSize);
      } catch (e) {
        // Provider 尚未初始化
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const SizedBox.shrink();

    final positionState = _watchState(
      floatingButtonPositionNotifierProvider,
      const FloatingButtonPositionState(),
    );
    final queueState = _watchState(
      replicationQueueNotifierProvider,
      const ReplicationQueueState(),
    );
    // queueState 不会为 null，因为 _watchState 返回默认值

    final executionState = _watchState(
      queueExecutionNotifierProvider,
      const QueueExecutionState(),
    );
    final isManuallyClosed = ref.watch(floatingButtonClosedProvider);

    if (_shouldHide(queueState, executionState, isManuallyClosed)) {
      _stopAnimations();
      return const SizedBox.shrink();
    }

    _updateAnimations(executionState);

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final containerSize = widget.containerSize ?? MediaQuery.of(context).size;
    final (x, y) = _calculatePosition(positionState, containerSize);

    return Positioned(
      left: x,
      top: y,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _onHoverEnter(),
        onExit: (_) => _onHoverExit(),
        child: Tooltip(
          richMessage:
              _buildTooltipMessage(l10n, queueState, executionState, theme),
          preferBelow: false,
          verticalOffset: _ballSize / 2 + 12,
          decoration: _tooltipDecoration(theme),
          waitDuration: const Duration(milliseconds: 400),
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onTap: _onTap,
            onDoubleTap: _onDoubleTap,
            onLongPress: _onLongPress,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _pulseAnimation,
                _glowAnimation,
                _hoverAnimation,
                _rotationAnimation,
              ]),
              builder: (context, child) => Transform.scale(
                scale: _hoverAnimation.value,
                child: _buildFloatingButton(
                  context: context,
                  theme: theme,
                  queueState: queueState,
                  executionState: executionState,
                  glowIntensity: executionState.isRunning
                      ? _glowAnimation.value
                      : (_isHovering ? 0.8 : 0.4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 安全地 watch provider 状态
  T _watchState<T>(ProviderListenable<T> provider, T defaultValue) {
    try {
      return ref.watch(provider);
    } catch (e) {
      return defaultValue;
    }
  }

  /// 判断是否隐藏悬浮球
  bool _shouldHide(
    ReplicationQueueState queueState,
    QueueExecutionState executionState,
    bool isManuallyClosed,
  ) {
    return isManuallyClosed ||
        (queueState.isEmpty &&
            queueState.failedTasks.isEmpty &&
            executionState.isIdle &&
            !executionState.hasFailedTasks);
  }

  /// 计算悬浮球位置
  (double x, double y) _calculatePosition(
    FloatingButtonPositionState positionState,
    Size containerSize,
  ) {
    if (_isDragging) {
      return (_dragOffset.dx, _dragOffset.dy);
    }

    if (!positionState.isInitialized ||
        (positionState.x == 0 && positionState.y == 0)) {
      return (
        containerSize.width - _totalSize - 12,
        containerSize.height - _totalSize - 120,
      );
    }

    return (
      positionState.x.clamp(0, containerSize.width - _totalSize),
      positionState.y.clamp(0, containerSize.height - _totalSize),
    );
  }

  /// Tooltip 装饰
  BoxDecoration _tooltipDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.colorScheme.inverseSurface.withOpacity(0.92),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// 构建悬浮球主体
  Widget _buildFloatingButton({
    required BuildContext context,
    required ThemeData theme,
    required ReplicationQueueState queueState,
    required QueueExecutionState executionState,
    required double glowIntensity,
  }) {
    final statusColors = _getStatusColors(executionState, queueState, theme);
    final progress = executionState.progress;
    final count = queueState.count;
    final isRunning = executionState.isRunning;
    final isReady = executionState.isReady;
    final isPaused = executionState.isPaused;
    final hasError = executionState.hasFailedTasks || queueState.hasFailedTasks;

    // 获取自定义背景图片
    final storage = ref.watch(localStorageServiceProvider);
    final bgImagePath = storage.getFloatingButtonBackgroundImage();
    final hasBgImage = bgImagePath != null && File(bgImagePath).existsSync();

    return SizedBox(
      width: _totalSize,
      height: _totalSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 层1: 外层光晕
          _buildOuterGlow(statusColors, glowIntensity),

          // 层2: 运行时脉冲波纹
          if (isRunning) _buildPulseRipple(statusColors),

          // 层3: 运行时旋转光环
          if (isRunning) _buildRotatingRing(statusColors, glowIntensity),

          // 层4: 进度环
          _buildProgressRing(progress, statusColors, glowIntensity),

          // 层5: 主体球
          _buildMainSphere(
            statusColors: statusColors,
            glowIntensity: glowIntensity,
            hasBgImage: hasBgImage,
            bgImagePath: bgImagePath,
            isRunning: isRunning,
            isReady: isReady,
            isPaused: isPaused,
            hasError: hasError,
            theme: theme,
          ),

          // 层6: 悬停光环
          if (_isHovering && !isRunning) _buildHoverRing(statusColors.primary),

          // 层7: 任务数量徽章
          if (count > 0)
            Positioned(
              top: 2,
              right: 2,
              child: _buildCountBadge(count, statusColors, theme),
            ),
        ],
      ),
    );
  }

  /// 构建外层光晕
  Widget _buildOuterGlow(_StatusColors colors, double intensity) {
    return Container(
      width: _totalSize - 4,
      height: _totalSize - 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            colors.primary.withOpacity(0.25 * intensity),
            colors.primary.withOpacity(0.08 * intensity),
            Colors.transparent,
          ],
          stops: const [0.2, 0.5, 1.0],
        ),
      ),
    );
  }

  /// 构建脉冲波纹
  Widget _buildPulseRipple(_StatusColors colors) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final value = _pulseAnimation.value;
        return Container(
          width: _ballSize + 24 * value,
          height: _ballSize + 24 * value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.primary.withOpacity(0.6 * (1 - value)),
              width: 2.5 * (1 - value),
            ),
          ),
        );
      },
    );
  }

  /// 构建旋转光环
  Widget _buildRotatingRing(_StatusColors colors, double intensity) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value,
          child: CustomPaint(
            size: const Size(_ballSize + 10, _ballSize + 10),
            painter: _RotatingRingPainter(
              primaryColor: colors.primary,
              secondaryColor: colors.secondary,
              intensity: intensity,
            ),
          ),
        );
      },
    );
  }

  /// 构建进度环
  Widget _buildProgressRing(
    double progress,
    _StatusColors colors,
    double intensity,
  ) {
    return CustomPaint(
      size: const Size(_ballSize + 4, _ballSize + 4),
      painter: _ProgressRingPainter(
        progress: progress,
        progressColor: colors.primary,
        trackColor: colors.primary.withOpacity(0.15),
        strokeWidth: _progressStrokeWidth,
        glowIntensity: intensity,
      ),
    );
  }

  /// 构建主体球
  Widget _buildMainSphere({
    required _StatusColors statusColors,
    required double glowIntensity,
    required bool hasBgImage,
    required String? bgImagePath,
    required bool isRunning,
    required bool isReady,
    required bool isPaused,
    required bool hasError,
    required ThemeData theme,
  }) {
    return Container(
      width: _ballSize,
      height: _ballSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasBgImage
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(statusColors.primary, Colors.white, 0.28)!,
                  statusColors.primary,
                  Color.lerp(statusColors.secondary, Colors.black, 0.12)!,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
        boxShadow: [
          // 主发光
          BoxShadow(
            color: statusColors.primary.withOpacity(0.5 * glowIntensity),
            blurRadius: 18 * glowIntensity,
            spreadRadius: 1,
          ),
          // 底部阴影
          BoxShadow(
            color: statusColors.secondary.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 背景图片
            if (hasBgImage && bgImagePath != null)
              Image.file(
                File(bgImagePath),
                width: _ballSize,
                height: _ballSize,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),

            // 玻璃高光
            if (!hasBgImage) ...[
              // 顶部高光
              Positioned(
                top: 5,
                left: 8,
                child: Container(
                  width: _ballSize * 0.4,
                  height: _ballSize * 0.2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(_isHovering ? 0.5 : 0.35),
                        Colors.white.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
              // 底部反光
              Positioned(
                bottom: 7,
                right: 9,
                child: Container(
                  width: _ballSize * 0.22,
                  height: _ballSize * 0.1,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0),
                        Colors.white.withOpacity(0.12),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // 中心图标
            _buildCenterIcon(isRunning, isReady, isPaused, hasError),
          ],
        ),
      ),
    );
  }

  /// 构建中心图标
  Widget _buildCenterIcon(
    bool isRunning,
    bool isReady,
    bool isPaused,
    bool hasError,
  ) {
    if (hasError) {
      return Icon(
        Icons.warning_rounded,
        size: 26,
        color: Colors.white.withOpacity(0.95),
      );
    }

    // 运行中或就绪状态显示暂停图标，其他状态显示播放图标
    final showPauseIcon = isRunning || isReady;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Icon(
        showPauseIcon ? Icons.pause_rounded : Icons.play_arrow_rounded,
        key: ValueKey(showPauseIcon),
        size: 28,
        color: Colors.white.withOpacity(0.95),
      ),
    );
  }

  /// 构建悬停光环
  Widget _buildHoverRing(Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 180),
      builder: (context, value, child) {
        return Container(
          width: _ballSize + 6,
          height: _ballSize + 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.45 * value),
              width: 1.5,
            ),
          ),
        );
      },
    );
  }

  /// 构建数量徽章
  Widget _buildCountBadge(int count, _StatusColors colors, ThemeData theme) {
    final displayText = count > 99 ? '99+' : count.toString();
    final badgeSize = displayText.length > 2 ? 22.0 : 18.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: displayText.length > 2 ? 5 : 0,
      ),
      constraints: BoxConstraints(
        minWidth: badgeSize,
        minHeight: badgeSize,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.secondary],
        ),
        borderRadius: BorderRadius.circular(badgeSize / 2),
        border: Border.all(
          color: Colors.white.withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.4),
            blurRadius: 5,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          displayText,
          style: TextStyle(
            color: Colors.white,
            fontSize: displayText.length > 2 ? 9 : 10,
            fontWeight: FontWeight.bold,
            height: 1,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取状态颜色
  _StatusColors _getStatusColors(
    QueueExecutionState executionState,
    ReplicationQueueState queueState,
    ThemeData theme,
  ) {
    // 有失败任务 - 红色系
    if (executionState.hasFailedTasks || queueState.hasFailedTasks) {
      return const _StatusColors(
        primary: Color(0xFFFF5252),
        secondary: Color(0xFFD32F2F),
      );
    }

    switch (executionState.status) {
      case QueueExecutionStatus.idle:
        // 空闲 - 主题色系（柔和紫蓝）
        return _StatusColors(
          primary: theme.colorScheme.primary,
          secondary: theme.colorScheme.primaryContainer,
        );
      case QueueExecutionStatus.ready:
      case QueueExecutionStatus.running:
        // 运行中 - 青蓝色系
        return const _StatusColors(
          primary: Color(0xFF00D4FF),
          secondary: Color(0xFF7C3AED),
        );
      case QueueExecutionStatus.paused:
        // 暂停 - 橙色系
        return const _StatusColors(
          primary: Color(0xFFFFB347),
          secondary: Color(0xFFFF8C00),
        );
      case QueueExecutionStatus.completed:
        // 完成 - 绿色系
        return const _StatusColors(
          primary: Color(0xFF4CAF50),
          secondary: Color(0xFF2E7D32),
        );
    }
  }

  void _updateAnimations(QueueExecutionState state) {
    if (!_isInitialized) return;

    if (state.isRunning) {
      if (!_pulseController.isAnimating) _pulseController.repeat();
      if (!_glowController.isAnimating) _glowController.repeat(reverse: true);
      if (!_rotationController.isAnimating) _rotationController.repeat();
    } else {
      _stopAnimations();
    }
  }

  void _stopAnimations() {
    if (!_isInitialized) return;
    if (_pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
    if (_glowController.isAnimating) {
      _glowController.stop();
      _glowController.value = 0.5;
    }
    if (_rotationController.isAnimating) {
      _rotationController.stop();
      _rotationController.reset();
    }
  }

  InlineSpan _buildTooltipMessage(
    AppLocalizations l10n,
    ReplicationQueueState queueState,
    QueueExecutionState executionState,
    ThemeData theme,
  ) {
    final normalStyle = TextStyle(
      color: theme.colorScheme.onInverseSurface,
      fontSize: 12,
      height: 1.5,
    );
    final accentStyle = TextStyle(
      color: theme.colorScheme.primary,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      height: 1.8,
    );

    final spans = <InlineSpan>[];

    // 状态
    spans.add(
      TextSpan(
        text: '${_getStatusText(l10n, executionState.status)}\n',
        style: normalStyle,
      ),
    );

    // 任务数量
    if (queueState.count > 0) {
      spans.add(
        TextSpan(
          text: '${l10n.queue_tooltipTasksTotal(queueState.count)}\n',
          style: normalStyle,
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: '${l10n.queue_tooltipNoTasks}\n',
          style: normalStyle,
        ),
      );
    }

    // 已完成/失败数量
    if (executionState.completedCount > 0) {
      spans.add(
        TextSpan(
          text:
              '${l10n.queue_tooltipCompleted(executionState.completedCount)}\n',
          style: normalStyle,
        ),
      );
    }
    final failedCount = executionState.failedCount + queueState.failedCount;
    if (failedCount > 0) {
      spans.add(
        TextSpan(
          text: '${l10n.queue_tooltipFailed(failedCount)}\n',
          style: normalStyle,
        ),
      );
    }

    // 当前任务
    if (executionState.currentTaskId != null && queueState.tasks.isNotEmpty) {
      final currentTask = queueState.tasks.firstWhere(
        (t) => t.id == executionState.currentTaskId,
        orElse: () => queueState.tasks.first,
      );
      final preview = currentTask.prompt.length > 28
          ? '${currentTask.prompt.substring(0, 28)}...'
          : currentTask.prompt;
      spans.add(
        TextSpan(
          text: '${l10n.queue_tooltipCurrentTask(preview)}\n',
          style: normalStyle,
        ),
      );
    }

    spans.add(const TextSpan(text: '\n'));

    // 双击打开队列管理 - 强调样式
    spans.add(
      TextSpan(
        text: '${l10n.queue_tooltipDoubleClickToOpen}\n',
        style: accentStyle,
      ),
    );

    // 其他操作提示
    spans.add(
      TextSpan(
        text: '${l10n.queue_tooltipClickToToggle}\n',
        style: normalStyle,
      ),
    );
    spans.add(
      TextSpan(
        text: l10n.queue_tooltipDragToMove,
        style: normalStyle,
      ),
    );

    return TextSpan(children: spans);
  }

  String _getStatusText(AppLocalizations l10n, QueueExecutionStatus status) {
    switch (status) {
      case QueueExecutionStatus.idle:
        return l10n.queue_statusIdle;
      case QueueExecutionStatus.ready:
        return l10n.queue_statusReady;
      case QueueExecutionStatus.running:
        return l10n.queue_statusRunning;
      case QueueExecutionStatus.paused:
        return l10n.queue_statusPaused;
      case QueueExecutionStatus.completed:
        return l10n.queue_statusCompleted;
    }
  }

  void _onHoverEnter() {
    setState(() => _isHovering = true);
    _hoverController.forward();
  }

  void _onHoverExit() {
    setState(() => _isHovering = false);
    _hoverController.reverse();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      final positionState = ref.read(floatingButtonPositionNotifierProvider);
      _dragOffset = Offset(positionState.x, positionState.y);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
    ref.read(floatingButtonPositionNotifierProvider.notifier).updatePosition(
          _dragOffset.dx,
          _dragOffset.dy,
        );
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    final screenSize = MediaQuery.of(context).size;
    ref
        .read(floatingButtonPositionNotifierProvider.notifier)
        .snapToEdgeAndSave(screenSize);
  }

  void _onTap() {
    // 单击打开队列管理页面
    widget.onTap?.call();
  }

  void _onDoubleTap() {
    // 双击切换开始/暂停
    final executionState = ref.read(queueExecutionNotifierProvider);
    final queueState = ref.read(replicationQueueNotifierProvider);

    if (queueState.isEmpty) {
      return;
    }

    if (executionState.isRunning || executionState.isReady) {
      // 运行中/就绪 → 暂停
      ref.read(queueExecutionNotifierProvider.notifier).pause();
    } else if (executionState.isPaused) {
      // 暂停 → 恢复
      ref.read(queueExecutionNotifierProvider.notifier).resume();
    } else {
      // 空闲/完成 → 开始执行
      ref.read(queueExecutionNotifierProvider.notifier).prepareNextTask();
    }
  }

  void _onLongPress() {
    showModalBottomSheet(
      context: context,
      builder: (context) => FloatingButtonLongPressMenu(
        onOpenManagement: widget.onTap,
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }
}

/// 状态颜色配置
class _StatusColors {
  final Color primary;
  final Color secondary;

  const _StatusColors({
    required this.primary,
    required this.secondary,
  });
}

/// 进度环绘制器
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color trackColor;
  final double strokeWidth;
  final double glowIntensity;

  _ProgressRingPainter({
    required this.progress,
    required this.progressColor,
    required this.trackColor,
    required this.strokeWidth,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth * 2) / 2;

    // 绘制轨道
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // 绘制进度
    if (progress > 0) {
      // 发光
      final glowPaint = Paint()
        ..color = progressColor.withOpacity(0.35 * glowIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        glowPaint,
      );

      // 主进度
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.glowIntensity != glowIntensity;
}

/// Loading环绘制器 - 单弧渐变拖尾效果
class _RotatingRingPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final double intensity;

  _RotatingRingPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // 绘制底层轨道（半透明）
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = primaryColor.withOpacity(0.15 * intensity);

    canvas.drawCircle(center, radius, trackPaint);

    // Loading弧长度（约270度）
    const arcLength = math.pi * 1.5;

    // 发光层
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: arcLength,
        colors: [
          primaryColor.withOpacity(0),
          primaryColor.withOpacity(0.3 * intensity),
          secondaryColor.withOpacity(0.5 * intensity),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      arcLength,
      false,
      glowPaint,
    );

    // 主体弧 - 渐变拖尾效果
    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: arcLength,
        colors: [
          primaryColor.withOpacity(0),
          primaryColor.withOpacity(0.6 * intensity),
          secondaryColor.withOpacity(0.95 * intensity),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      arcLength,
      false,
      mainPaint,
    );

    // 头部高亮点
    final headX = center.dx + radius * math.cos(arcLength);
    final headY = center.dy + radius * math.sin(arcLength);

    final headGlowPaint = Paint()
      ..color = secondaryColor.withOpacity(0.6 * intensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(headX, headY), 4, headGlowPaint);

    final headPaint = Paint()
      ..color = Colors.white.withOpacity(0.9 * intensity);
    canvas.drawCircle(Offset(headX, headY), 2.5, headPaint);
  }

  @override
  bool shouldRepaint(covariant _RotatingRingPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.intensity != intensity;
}

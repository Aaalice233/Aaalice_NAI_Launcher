import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/localization_extension.dart';
import '../../providers/floating_button_position_provider.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
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
  late final AnimationController _iconController;
  late final AnimationController _rotationController;
  late final AnimationController _breathController;

  // 动画
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _hoverAnimation;
  late final Animation<double> _rotationAnimation;
  late final Animation<double> _breathAnimation;

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

    // 图标动画（播放/暂停切换）
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 旋转动画 - 运行时的光环旋转
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    // 呼吸动画 - 空闲时的柔和缩放
    _breathController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _breathAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    // 启动空闲呼吸动画
    _breathController.repeat(reverse: true);

    _isInitialized = true;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _hoverController.dispose();
    _iconController.dispose();
    _rotationController.dispose();
    _breathController.dispose();
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

    // 安全获取状态
    FloatingButtonPositionState positionState =
        const FloatingButtonPositionState();
    ReplicationQueueState queueState = const ReplicationQueueState();
    QueueExecutionState executionState = const QueueExecutionState();

    try {
      positionState = ref.watch(floatingButtonPositionNotifierProvider);
    } catch (e) {
      // Provider 未初始化
    }

    try {
      queueState = ref.watch(replicationQueueNotifierProvider);
    } catch (e) {
      return const SizedBox.shrink();
    }

    try {
      executionState = ref.watch(queueExecutionNotifierProvider);
    } catch (e) {
      // 使用默认执行状态
    }

    // 队列为空且未在执行时不显示
    final shouldHide = queueState.isEmpty &&
        queueState.failedTasks.isEmpty &&
        executionState.isIdle &&
        !executionState.hasFailedTasks;

    if (shouldHide) {
      _stopAnimations();
      return const SizedBox.shrink();
    }

    // 根据状态控制动画
    _updateAnimations(executionState);

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final containerSize = widget.containerSize ?? MediaQuery.of(context).size;

    // 计算位置
    double x, y;
    if (_isDragging) {
      x = _dragOffset.dx;
      y = _dragOffset.dy;
    } else if (!positionState.isInitialized ||
        (positionState.x == 0 && positionState.y == 0)) {
      x = containerSize.width - _totalSize - 12;
      y = containerSize.height - _totalSize - 120;
    } else {
      x = positionState.x.clamp(0, containerSize.width - _totalSize);
      y = positionState.y.clamp(0, containerSize.height - _totalSize);
    }

    final tooltipMessage =
        _buildTooltipMessage(l10n, queueState, executionState);

    return Positioned(
      left: x,
      top: y,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _onHoverEnter(),
        onExit: (_) => _onHoverExit(),
        child: Tooltip(
          message: tooltipMessage,
          preferBelow: false,
          verticalOffset: _ballSize / 2 + 12,
          decoration: BoxDecoration(
            color: theme.colorScheme.inverseSurface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          textStyle: TextStyle(
            color: theme.colorScheme.onInverseSurface,
            fontSize: 12,
            height: 1.5,
          ),
          waitDuration: const Duration(milliseconds: 400),
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onTap: _onTap,
            onLongPress: _onLongPress,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _pulseAnimation,
                _glowAnimation,
                _hoverAnimation,
                _rotationAnimation,
                _breathAnimation,
                _iconController,
              ]),
              builder: (context, child) {
                final glowIntensity = executionState.isRunning
                    ? _glowAnimation.value
                    : (_isHovering ? 0.8 : 0.4);
                final hoverScale = _hoverAnimation.value;
                final breathScale =
                    !executionState.isRunning ? _breathAnimation.value : 1.0;
                final scale = hoverScale * breathScale;

                return Transform.scale(
                  scale: scale,
                  child: _buildFloatingButton(
                    context: context,
                    theme: theme,
                    queueState: queueState,
                    executionState: executionState,
                    glowIntensity: glowIntensity,
                  ),
                );
              },
            ),
          ),
        ),
      ),
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
            size: Size(_ballSize + 10, _ballSize + 10),
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
      double progress, _StatusColors colors, double intensity) {
    return CustomPaint(
      size: Size(_ballSize + 4, _ballSize + 4),
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
            _buildCenterIcon(isRunning, isPaused, hasError),
          ],
        ),
      ),
    );
  }

  /// 构建中心图标
  Widget _buildCenterIcon(bool isRunning, bool isPaused, bool hasError) {
    // 根据状态控制动画
    if (isRunning) {
      _iconController.forward();
    } else {
      _iconController.reverse();
    }

    return AnimatedBuilder(
      animation: _iconController,
      builder: (context, child) {
        if (hasError) {
          return Icon(
            Icons.warning_rounded,
            size: 26,
            color: Colors.white.withOpacity(0.95),
          );
        }

        return AnimatedIcon(
          icon: AnimatedIcons.play_pause,
          progress: _iconController,
          size: 26,
          color: Colors.white.withOpacity(0.95),
        );
      },
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
      if (_breathController.isAnimating) {
        _breathController.stop();
        _breathController.value = 0.5;
      }
    } else {
      _stopAnimations();
      if (!_breathController.isAnimating) {
        _breathController.repeat(reverse: true);
      }
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

  String _buildTooltipMessage(
    AppLocalizations l10n,
    ReplicationQueueState queueState,
    QueueExecutionState executionState,
  ) {
    final lines = <String>[];

    // 状态
    lines.add(_getStatusText(l10n, executionState.status));

    // 任务数量
    if (queueState.count > 0) {
      lines.add(l10n.queue_tooltipTasksTotal(queueState.count));
    } else {
      lines.add(l10n.queue_tooltipNoTasks);
    }

    // 已完成/失败数量
    if (executionState.completedCount > 0) {
      lines.add(l10n.queue_tooltipCompleted(executionState.completedCount));
    }
    final failedCount = executionState.failedCount + queueState.failedCount;
    if (failedCount > 0) {
      lines.add(l10n.queue_tooltipFailed(failedCount));
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
      lines.add(l10n.queue_tooltipCurrentTask(preview));
    }

    lines.add('');
    lines.add(l10n.queue_tooltipClickToOpen);
    lines.add(l10n.queue_tooltipDragToMove);

    return lines.join('\n');
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
    widget.onTap?.call();
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

/// 旋转光环绘制器
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

    const segments = 3;
    const gapAngle = math.pi / 5;
    final arcLength = (2 * math.pi - segments * gapAngle) / segments;

    for (int i = 0; i < segments; i++) {
      final startAngle = i * (arcLength + gapAngle);

      // 发光层
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + arcLength,
          colors: [
            primaryColor.withOpacity(0.1 * intensity),
            primaryColor.withOpacity(0.5 * intensity),
            secondaryColor.withOpacity(0.5 * intensity),
            secondaryColor.withOpacity(0.1 * intensity),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcLength,
        false,
        glowPaint,
      );

      // 主体层
      final mainPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + arcLength,
          colors: [
            primaryColor.withOpacity(0.2 * intensity),
            primaryColor.withOpacity(0.85 * intensity),
            secondaryColor.withOpacity(0.85 * intensity),
            secondaryColor.withOpacity(0.2 * intensity),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arcLength,
        false,
        mainPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RotatingRingPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.intensity != intensity;
}

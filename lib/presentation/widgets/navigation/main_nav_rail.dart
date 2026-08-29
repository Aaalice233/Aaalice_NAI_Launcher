import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_version.dart';
import '../../../core/constants/community_links.dart';
import '../../../data/models/auth/saved_account.dart';
import '../../providers/account_manager_provider.dart';
import '../../providers/auth_mode_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/layout_state_provider.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../providers/update_provider.dart';
import '../../router/app_branch.dart';
import '../../router/app_routes.dart';
import '../../themes/theme_extension.dart';
import '../auth/account_avatar.dart';
import '../auth/login_form_container.dart';

import '../common/app_toast.dart';

Duration _boundedMotionDuration(
  BuildContext context,
  Duration source, {
  required int minMilliseconds,
  required int maxMilliseconds,
}) {
  if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
  return Duration(
    milliseconds: source.inMilliseconds.clamp(minMilliseconds, maxMilliseconds),
  );
}

class MainNavRail extends ConsumerWidget {
  static const double collapsedWidth = 60;
  static const double expandedWidth = 196;

  static const List<AppBranch> _railBranches = [
    AppBranch.generation,
    AppBranch.localGallery,
    AppBranch.onlineGallery,
    AppBranch.vibeLibrary,
    AppBranch.preciseRefLibrary,
    AppBranch.promptConfig,
    AppBranch.tagLibrary,
    AppBranch.statistics,
    AppBranch.settings,
  ];

  final StatefulNavigationShell navigationShell;
  final bool isAgentVisible;
  final bool isAgentRunning;
  final bool isQueueVisible;
  final FocusNode? agentFocusNode;
  final FocusNode? queueFocusNode;
  final ValueChanged<bool> onAgentVisibilityChanged;
  final ValueChanged<bool> onQueueVisibilityChanged;

  const MainNavRail({
    super.key,
    required this.navigationShell,
    this.isAgentVisible = false,
    this.isAgentRunning = false,
    this.isQueueVisible = false,
    this.agentFocusNode,
    this.queueFocusNode,
    this.onAgentVisibilityChanged = _ignorePanelVisibilityChange,
    this.onQueueVisibilityChanged = _ignorePanelVisibilityChange,
  });

  static void _ignorePanelVisibilityChange(bool _) {}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isExpanded = ref.watch(
      layoutStateNotifierProvider.select((state) => state.mainNavRailExpanded),
    );

    final showUpdateBadge = ref.watch(
      updateStateProvider.select((state) => state.hasNewVersion),
    );
    final queueCount = ref.watch(
      replicationQueueNotifierProvider.select((state) => state.count),
    );
    final queueExecutionStatus = ref.watch(
      queueExecutionNotifierProvider.select((state) => state.status),
    );
    final currentIndex = navigationShell.currentIndex;
    final selectedIndex = _railBranches.indexWhere(
      (branch) => branch.index == currentIndex,
    );
    final motion = theme.appTheme;
    final animationDuration = _boundedMotionDuration(
      context,
      motion.normalDuration,
      minMilliseconds: 120,
      maxMilliseconds: 180,
    );

    return _NavRailWidthTransition(
      isExpanded: isExpanded,
      duration: animationDuration,
      curve: motion.standardCurve,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(right: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // 账户头像区域
          _AccountAvatarButton(ref: ref),

          Expanded(
            child: SingleChildScrollView(
              key: const Key('main-nav-primary-scroll'),
              child: Column(
                children: [
                  // Navigation Items
                  _NavIcon(
                    icon: Icons.brush, // Canvas/Edit
                    label: context.l10n.nav_canvas,
                    isSelected: selectedIndex == 0,
                    onTap: () =>
                        navigationShell.goBranch(AppBranch.generation.index),
                  ),

                  // 本地图库（App生成的图片）
                  _NavIcon(
                    icon: Icons.folder, // Local Generated Images
                    label: context.l10n.nav_localGallery,
                    isSelected: selectedIndex == 1,
                    onTap: () =>
                        navigationShell.goBranch(AppBranch.localGallery.index),
                  ),

                  // 在线画廊
                  _NavIcon(
                    icon: Icons.photo_library, // Online Gallery
                    label: context.l10n.nav_onlineGallery,
                    isSelected: selectedIndex == 2,
                    onTap: () =>
                        navigationShell.goBranch(AppBranch.onlineGallery.index),
                  ),

                  // Vibe库
                  _NavIcon(
                    icon: Icons.auto_awesome, // Vibe Library
                    label: context.l10n.vibeLibrary_title,
                    isSelected: selectedIndex == 3,
                    onTap: () =>
                        navigationShell.goBranch(AppBranch.vibeLibrary.index),
                  ),

                  // 精准参考库
                  _NavIcon(
                    icon: Icons.center_focus_strong,
                    label: context.l10n.nav_preciseRefLibrary,
                    isSelected: selectedIndex == 4,
                    onTap: () => navigationShell.goBranch(
                      AppBranch.preciseRefLibrary.index,
                    ),
                  ),

                  // 随机配置
                  _NavIcon(
                    icon: Icons.casino, // Random prompt config
                    label: context.l10n.nav_randomConfig,
                    isSelected: selectedIndex == 5,
                    onTap: () =>
                        navigationShell.goBranch(AppBranch.promptConfig.index),
                  ),

                  // 词库
                  _NavIcon(
                    icon: Icons.book,
                    label: context.l10n.nav_dictionary,
                    isSelected: selectedIndex == 6,
                    onTap: () =>
                        navigationShell.goBranch(AppBranch.tagLibrary.index),
                  ),

                  // 统计
                  _NavIcon(
                    icon: Icons.bar_chart, // Gallery Statistics
                    label: context.l10n.nav_statistics,
                    isSelected: selectedIndex == 7,
                    onTap: () =>
                        navigationShell.goBranch(AppBranch.statistics.index),
                  ),
                ],
              ),
            ),
          ),

          // Discord 社群
          _ExternalLinkIcon(
            icon: Icons.discord,
            label: context.l10n.nav_discordCommunity,
            color: const Color(0xFF5865F2), // Discord 紫色
            url: CommunityLinks.discord,
          ),

          // GitHub 仓库
          _GitHubIcon(
            url: CommunityLinks.github,
            label: context.l10n.nav_githubRepo,
          ),

          _NavIcon(
            key: const Key('agent-nav-item'),
            focusNode: agentFocusNode,
            icon: isAgentRunning
                ? Icons.smart_toy_rounded
                : Icons.smart_toy_outlined,
            label: context.l10n.nav_agent,
            isSelected: isAgentVisible,
            showBadge: isAgentRunning,
            onTap: () => onAgentVisibilityChanged(!isAgentVisible),
          ),

          _NavIcon(
            key: const Key('queue-nav-item'),
            focusNode: queueFocusNode,
            icon: switch (queueExecutionStatus) {
              QueueExecutionStatus.running => Icons.play_arrow_rounded,
              QueueExecutionStatus.paused => Icons.pause_rounded,
              _ => Icons.playlist_play_rounded,
            },
            label: context.l10n.queue_management,
            isSelected: isQueueVisible,
            badgeLabel: queueCount > 0
                ? (queueCount > 99 ? '99+' : queueCount.toString())
                : null,
            onTap: () => onQueueVisibilityChanged(!isQueueVisible),
          ),

          // Bottom Settings
          _NavIcon(
            icon: Icons.settings,
            label: context.l10n.nav_settings,
            isSelected: selectedIndex == 8,
            showBadge: showUpdateBadge,
            onTap: () => navigationShell.goBranch(AppBranch.settings.index),
          ),
          const SizedBox(height: 2),
          _NavRailToggle(
            isExpanded: isExpanded,
            onTap: () {
              ref
                  .read(layoutStateNotifierProvider.notifier)
                  .toggleMainNavRail();
            },
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _NavRailWidthTransition extends StatefulWidget {
  const _NavRailWidthTransition({
    required this.isExpanded,
    required this.duration,
    required this.curve,
    required this.decoration,
    required this.child,
  });

  final bool isExpanded;
  final Duration duration;
  final Curve curve;
  final Decoration decoration;
  final Widget child;

  @override
  State<_NavRailWidthTransition> createState() =>
      _NavRailWidthTransitionState();
}

// 宽度与所有标签共享同一时间轴，避免高频切换同时启动多组 ticker。
class _NavRailWidthTransitionState extends State<_NavRailWidthTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late CurvedAnimation _expansion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: widget.isExpanded ? 1 : 0,
      duration: widget.duration,
    );
    _updateCurve();
  }

  @override
  void didUpdateWidget(_NavRailWidthTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (oldWidget.curve != widget.curve) {
      _expansion.dispose();
      _updateCurve();
    }
    if (oldWidget.isExpanded != widget.isExpanded ||
        oldWidget.duration != widget.duration) {
      _animateToTarget();
    }
  }

  void _updateCurve() {
    final curve = _ClampedCurve(widget.curve);
    _expansion = CurvedAnimation(
      parent: _controller,
      curve: curve,
      reverseCurve: curve,
    );
  }

  void _animateToTarget() {
    if (widget.duration == Duration.zero) {
      _controller.value = widget.isExpanded ? 1 : 0;
      return;
    }
    if (widget.isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _expansion.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _expansion,
      builder: (context, child) {
        final width =
            MainNavRail.collapsedWidth +
            (MainNavRail.expandedWidth - MainNavRail.collapsedWidth) *
                _expansion.value;
        return Container(
          key: const Key('main-nav-rail'),
          width: width,
          height: double.infinity,
          clipBehavior: Clip.hardEdge,
          decoration: widget.decoration,
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: MainNavRail.expandedWidth,
            maxWidth: MainNavRail.expandedWidth,
            child: RepaintBoundary(
              child: SizedBox(
                key: const Key('main-nav-rail-content'),
                width: MainNavRail.expandedWidth,
                height: double.infinity,
                child: child,
              ),
            ),
          ),
        );
      },
      child: _NavRailExpansionScope(
        isExpanded: widget.isExpanded,
        expansion: _expansion,
        child: widget.child,
      ),
    );
  }
}

class _ClampedCurve extends Curve {
  const _ClampedCurve(this.curve);

  final Curve curve;

  @override
  double transformInternal(double t) => curve.transform(t).clamp(0.0, 1.0);
}

class _NavRailExpansionScope extends InheritedWidget {
  const _NavRailExpansionScope({
    required this.isExpanded,
    required this.expansion,
    required super.child,
  });

  final bool isExpanded;
  final Animation<double> expansion;

  static _NavRailExpansionScope of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_NavRailExpansionScope>()!;
  }

  static bool isExpandedOf(BuildContext context) => of(context).isExpanded;

  @override
  bool updateShouldNotify(_NavRailExpansionScope oldWidget) {
    return isExpanded != oldWidget.isExpanded ||
        expansion != oldWidget.expansion;
  }
}

class _ExpandedRailContent extends StatelessWidget {
  const _ExpandedRailContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = _NavRailExpansionScope.of(context);
    return FadeTransition(opacity: scope.expansion, child: child);
  }
}

class _NavRailToggle extends StatelessWidget {
  const _NavRailToggle({required this.isExpanded, required this.onTap});

  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = isExpanded
        ? context.l10n.nav_collapseSidebar
        : context.l10n.nav_expandSidebar;

    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  SizedBox(
                    key: const Key('main-nav-toggle'),
                    width: 48,
                    height: 48,
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_double_arrow_left
                          : Icons.keyboard_double_arrow_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ExpandedRailContent(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  _ExpandedRailContent(
                    child: Text(
                      'v${AppVersion.versionName}',
                      key: const Key('main-nav-version'),
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.72,
                        ),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// GitHub 图标（自定义绘制）
class _GitHubIcon extends StatefulWidget {
  final String url;
  final String label;

  const _GitHubIcon({required this.url, required this.label});

  @override
  State<_GitHubIcon> createState() => _GitHubIconState();
}

class _GitHubIconState extends State<_GitHubIcon> {
  bool _isHovering = false;
  bool _isPressed = false;

  Future<void> _launchUrl() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF24292E);

    return _RailLinkItem(
      label: widget.label,
      color: color,
      isHovering: _isHovering,
      isPressed: _isPressed,
      onTap: _launchUrl,
      onHover: (value) => setState(() => _isHovering = value),
      onTapDown: () => setState(() => _isPressed = true),
      onTapEnd: () => setState(() => _isPressed = false),
      icon: GitHubLogo(
        size: 24,
        color: color.withValues(alpha: _isHovering ? 1.0 : 0.7),
      ),
    );
  }
}

/// 可复用的 GitHub 品牌图标。
class GitHubLogo extends StatelessWidget {
  const GitHubLogo({super.key, required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GitHubLogoPainter(color: color),
    );
  }
}

class _GitHubLogoPainter extends CustomPainter {
  final Color color;

  _GitHubLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final scale = size.width / 24;

    // GitHub Octocat 简化路径
    path.moveTo(12 * scale, 0.5 * scale);
    path.cubicTo(
      5.37 * scale,
      0.5 * scale,
      0 * scale,
      5.87 * scale,
      0 * scale,
      12.5 * scale,
    );
    path.cubicTo(
      0 * scale,
      17.83 * scale,
      3.44 * scale,
      22.31 * scale,
      8.21 * scale,
      23.75 * scale,
    );
    path.cubicTo(
      8.81 * scale,
      23.86 * scale,
      9.02 * scale,
      23.5 * scale,
      9.02 * scale,
      23.18 * scale,
    );
    path.cubicTo(
      9.02 * scale,
      22.9 * scale,
      9.01 * scale,
      22.21 * scale,
      9.01 * scale,
      21.29 * scale,
    );
    path.cubicTo(
      5.67 * scale,
      22.03 * scale,
      4.97 * scale,
      19.68 * scale,
      4.97 * scale,
      19.68 * scale,
    );
    path.cubicTo(
      4.42 * scale,
      18.42 * scale,
      3.63 * scale,
      18.05 * scale,
      3.63 * scale,
      18.05 * scale,
    );
    path.cubicTo(
      2.55 * scale,
      17.33 * scale,
      3.71 * scale,
      17.35 * scale,
      3.71 * scale,
      17.35 * scale,
    );
    path.cubicTo(
      4.91 * scale,
      17.43 * scale,
      5.54 * scale,
      18.55 * scale,
      5.54 * scale,
      18.55 * scale,
    );
    path.cubicTo(
      6.61 * scale,
      20.31 * scale,
      8.36 * scale,
      19.79 * scale,
      9.05 * scale,
      19.49 * scale,
    );
    path.cubicTo(
      9.16 * scale,
      18.77 * scale,
      9.46 * scale,
      18.25 * scale,
      9.79 * scale,
      17.96 * scale,
    );
    path.cubicTo(
      7.14 * scale,
      17.67 * scale,
      4.34 * scale,
      16.72 * scale,
      4.34 * scale,
      12.18 * scale,
    );
    path.cubicTo(
      4.34 * scale,
      10.99 * scale,
      4.78 * scale,
      10.02 * scale,
      5.56 * scale,
      9.25 * scale,
    );
    path.cubicTo(
      5.44 * scale,
      8.96 * scale,
      5.04 * scale,
      7.85 * scale,
      5.67 * scale,
      6.35 * scale,
    );
    path.cubicTo(
      5.67 * scale,
      6.35 * scale,
      6.68 * scale,
      6.04 * scale,
      8.99 * scale,
      7.44 * scale,
    );
    path.cubicTo(
      9.87 * scale,
      7.19 * scale,
      10.94 * scale,
      7.06 * scale,
      12 * scale,
      7.06 * scale,
    );
    path.cubicTo(
      13.06 * scale,
      7.06 * scale,
      14.13 * scale,
      7.19 * scale,
      15.01 * scale,
      7.44 * scale,
    );
    path.cubicTo(
      17.32 * scale,
      6.04 * scale,
      18.33 * scale,
      6.35 * scale,
      18.33 * scale,
      6.35 * scale,
    );
    path.cubicTo(
      18.96 * scale,
      7.85 * scale,
      18.56 * scale,
      8.96 * scale,
      18.44 * scale,
      9.25 * scale,
    );
    path.cubicTo(
      19.22 * scale,
      10.02 * scale,
      19.66 * scale,
      10.99 * scale,
      19.66 * scale,
      12.18 * scale,
    );
    path.cubicTo(
      19.66 * scale,
      16.73 * scale,
      16.86 * scale,
      17.67 * scale,
      14.21 * scale,
      17.96 * scale,
    );
    path.cubicTo(
      14.62 * scale,
      18.31 * scale,
      15 * scale,
      19 * scale,
      15 * scale,
      20.04 * scale,
    );
    path.cubicTo(
      15 * scale,
      21.51 * scale,
      14.99 * scale,
      22.7 * scale,
      14.99 * scale,
      23.18 * scale,
    );
    path.cubicTo(
      14.99 * scale,
      23.5 * scale,
      15.19 * scale,
      23.87 * scale,
      15.81 * scale,
      23.75 * scale,
    );
    path.cubicTo(
      20.57 * scale,
      22.31 * scale,
      24 * scale,
      17.83 * scale,
      24 * scale,
      12.5 * scale,
    );
    path.cubicTo(
      24 * scale,
      5.87 * scale,
      18.63 * scale,
      0.5 * scale,
      12 * scale,
      0.5 * scale,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GitHubLogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// 外部链接图标
class _ExternalLinkIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String url;

  const _ExternalLinkIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.url,
  });

  @override
  State<_ExternalLinkIcon> createState() => _ExternalLinkIconState();
}

class _ExternalLinkIconState extends State<_ExternalLinkIcon> {
  bool _isHovering = false;
  bool _isPressed = false;

  Future<void> _launchUrl() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _RailLinkItem(
      label: widget.label,
      color: widget.color,
      isHovering: _isHovering,
      isPressed: _isPressed,
      onTap: _launchUrl,
      onHover: (value) => setState(() => _isHovering = value),
      onTapDown: () => setState(() => _isPressed = true),
      onTapEnd: () => setState(() => _isPressed = false),
      icon: Icon(
        widget.icon,
        color: widget.color.withValues(alpha: _isHovering ? 1.0 : 0.7),
        size: 24,
      ),
    );
  }
}

class _RailLinkItem extends StatelessWidget {
  const _RailLinkItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.isHovering,
    required this.isPressed,
    required this.onTap,
    required this.onHover,
    required this.onTapDown,
    required this.onTapEnd,
  });

  final Widget icon;
  final String label;
  final Color color;
  final bool isHovering;
  final bool isPressed;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;
  final VoidCallback onTapDown;
  final VoidCallback onTapEnd;

  @override
  Widget build(BuildContext context) {
    final isExpanded = _NavRailExpansionScope.isExpandedOf(context);
    final theme = Theme.of(context);

    return Tooltip(
      message: isExpanded ? '' : label,
      preferBelow: false,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        height: 48,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onHover: onHover,
            onTapDown: (_) => onTapDown(),
            onTapUp: (_) => onTapEnd(),
            onTapCancel: onTapEnd,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedScale(
              scale: isPressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isHovering
                      ? color.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 48, height: 48, child: Center(child: icon)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ExpandedRailContent(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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

class _NavIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showBadge;
  final String? badgeLabel;
  final FocusNode? focusNode;

  const _NavIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.showBadge = false,
    this.badgeLabel,
    this.focusNode,
  });

  @override
  State<_NavIcon> createState() => _NavIconState();
}

class _NavIconState extends State<_NavIcon> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpanded = _NavRailExpansionScope.isExpandedOf(context);
    final color = widget.isSelected
        ? theme.colorScheme.primary
        : theme.iconTheme.color?.withValues(alpha: 0.7);

    // 计算背景色：选中状态优先，其次是 Hover 状态
    Color backgroundColor = Colors.transparent;
    if (widget.isSelected) {
      backgroundColor = theme.colorScheme.primary.withValues(alpha: 0.16);
    } else if (_isHovering) {
      backgroundColor = theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.5,
      );
    }

    return Tooltip(
      message: isExpanded ? '' : widget.label,
      preferBelow: false,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        height: 48,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            focusNode: widget.focusNode,
            focusColor: Colors.transparent,
            onTap: widget.onTap,
            onHover: (val) => setState(() => _isHovering = val),
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedScale(
              scale: _isPressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Badge(
                          isLabelVisible:
                              widget.showBadge || widget.badgeLabel != null,
                          smallSize: 7,
                          label: widget.badgeLabel == null
                              ? null
                              : Text(widget.badgeLabel!),
                          child: Icon(widget.icon, color: color, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ExpandedRailContent(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: widget.isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                            fontWeight: widget.isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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

/// 账户头像按钮组件
class _AccountAvatarButton extends StatefulWidget {
  final WidgetRef ref;

  const _AccountAvatarButton({required this.ref});

  @override
  State<_AccountAvatarButton> createState() => _AccountAvatarButtonState();
}

class _AccountAvatarButtonState extends State<_AccountAvatarButton> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = widget.ref.watch(authNotifierProvider);
    final accounts = widget.ref.watch(accountManagerNotifierProvider).accounts;

    // 获取当前账户
    SavedAccount? currentAccount;
    if (authState.isAuthenticated && authState.accountId != null) {
      try {
        currentAccount = accounts.firstWhere(
          (a) => a.id == authState.accountId,
        );
      } catch (_) {
        currentAccount = null;
      }
    }

    final avatar = currentAccount != null
        ? AccountAvatarSmall(account: currentAccount, size: 40)
        : Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          );

    return Container(
      margin: const EdgeInsets.fromLTRB(6, 0, 6, 12),
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('main-nav-account-menu-button'),
          onTap: () => _showAccountMenu(context, currentAccount),
          onHover: (val) => setState(() => _isHovering = val),
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          borderRadius: BorderRadius.circular(22),
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: _isHovering
                    ? theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      )
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  SizedBox(width: 48, height: 48, child: Center(child: avatar)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ExpandedRailContent(
                      child: Text(
                        currentAccount?.displayName ?? context.l10n.auth_login,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  _ExpandedRailContent(
                    child: Icon(
                      Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 显示账户菜单
  Future<void> _showAccountMenu(
    BuildContext context,
    SavedAccount? currentAccount,
  ) async {
    final theme = Theme.of(context);
    final authState = widget.ref.read(authNotifierProvider);
    final accounts = authState.isAuthenticated
        ? widget.ref.read(accountManagerNotifierProvider).accounts
        : const <SavedAccount>[];
    final menuCurrentAccount = authState.isAuthenticated
        ? currentAccount
        : null;

    // 获取按钮的位置用于定位菜单
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    // 使用 Rect 定义菜单弹出的锚点位置
    final railWidth = _NavRailExpansionScope.isExpandedOf(context)
        ? MainNavRail.expandedWidth
        : MainNavRail.collapsedWidth;
    final menuAnchor = Rect.fromLTWH(
      railWidth + 8,
      offset.dy,
      1,
      button.size.height,
    );

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(menuAnchor, Offset.zero & screenSize),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        if (!authState.isAuthenticated)
          PopupMenuItem<String>(
            value: 'login',
            child: Row(
              children: [
                Icon(Icons.login, color: theme.colorScheme.onSurface, size: 20),
                const SizedBox(width: 12),
                Text(context.l10n.auth_login),
              ],
            ),
          ),

        // 当前账号标题
        if (menuCurrentAccount != null)
          PopupMenuItem<String>(
            enabled: false,
            height: 40,
            child: Text(
              '${context.l10n.auth_currentAccount}: ${menuCurrentAccount.displayName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),

        // 分割线
        if (menuCurrentAccount != null && accounts.length > 1)
          const PopupMenuDivider(),

        // 账号列表
        ...accounts.map(
          (account) => PopupMenuItem<String>(
            value: 'switch_${account.id}',
            child: Row(
              children: [
                AccountAvatarSmall(account: account, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    account.displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (account.id == authState.accountId)
                  Icon(Icons.check, color: theme.colorScheme.primary, size: 20),
              ],
            ),
          ),
        ),

        if (authState.isAuthenticated) const PopupMenuDivider(),

        // 添加账号
        if (authState.isAuthenticated)
          PopupMenuItem<String>(
            value: 'add',
            child: Row(
              children: [
                Icon(Icons.add, color: theme.colorScheme.onSurface, size: 20),
                const SizedBox(width: 12),
                Text(context.l10n.auth_addAccount),
              ],
            ),
          ),

        // 退出登录
        if (authState.isAuthenticated)
          PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout, color: theme.colorScheme.error, size: 20),
                const SizedBox(width: 12),
                Text(
                  context.l10n.auth_logout,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ),
          ),
      ],
    );

    if (value == null || !mounted) return;

    if (value == 'login') {
      // ignore: use_build_context_synchronously
      context.push(AppRoutes.login);
    } else if (value == 'add') {
      if (mounted) {
        // ignore: use_build_context_synchronously
        _showAddAccountDialog(context);
      }
    } else if (value == 'logout') {
      // Use SchedulerBinding.endOfFrame to ensure logout happens AFTER the menu is fully disposed
      // This prevents the "ref.listen can only be used within build method" error that occurs when
      // The router auth listener can run during menu disposal. endOfFrame is more reliable
      // than addPostFrameCallback because it waits for the entire frame to complete, including all
      // post-frame callbacks and microtasks, ensuring the widget tree is stable.
      SchedulerBinding.instance.endOfFrame.then((_) {
        if (mounted) {
          widget.ref.read(authNotifierProvider.notifier).logout();
        }
      });
    } else if (value.startsWith('switch_')) {
      final accountId = value.substring(7);
      _switchAccount(accountId);
    }
  }

  /// 切换账号
  Future<void> _switchAccount(String accountId) async {
    final accounts = widget.ref.read(accountManagerNotifierProvider).accounts;
    final account = accounts.firstWhere((a) => a.id == accountId);

    // 获取 Token
    final token = await widget.ref
        .read(accountManagerNotifierProvider.notifier)
        .getAccountToken(account.id);

    if (token == null) {
      if (mounted) {
        AppToast.info(context, context.l10n.auth_tokenNotFound);
      }
      return;
    }

    // 使用 switchAccount（根据账号类型选择验证方式）
    final success = await widget.ref
        .read(authNotifierProvider.notifier)
        .switchAccount(
          account.id,
          token,
          displayName: account.displayName,
          accountType: account.accountType,
        );

    if (success) {
      // 更新最后使用时间
      widget.ref
          .read(accountManagerNotifierProvider.notifier)
          .updateLastUsed(account.id);
    } else {
      // 切换失败，显示错误提示并停留在当前账号
      if (mounted) {
        final authState = widget.ref.read(authNotifierProvider);
        String errorMessage;

        switch (authState.errorCode) {
          case AuthErrorCode.networkTimeout:
            errorMessage = context.l10n.auth_error_networkTimeout;
            break;
          case AuthErrorCode.networkError:
            errorMessage = context.l10n.auth_error_networkError;
            break;
          case AuthErrorCode.authFailed:
          case AuthErrorCode.tokenInvalid:
            errorMessage = context.l10n.auth_error_authFailed;
            break;
          case AuthErrorCode.credentialsLoginUnavailable:
            errorMessage = context.l10n.auth_error_credentialsLoginUnavailable;
            break;
          case AuthErrorCode.serverError:
            errorMessage = context.l10n.auth_error_serverError;
            break;
          default:
            errorMessage = context.l10n.auth_loginFailed;
        }

        AppToast.error(context, errorMessage);
      }
    }
  }

  /// 显示添加账号对话框
  void _showAddAccountDialog(BuildContext context) {
    // 重置 AuthMode 为当前默认登录模式
    widget.ref.read(authModeNotifierProvider.notifier).reset();
    // 立即清除之前的登录错误状态（无延迟）
    widget.ref.read(authNotifierProvider.notifier).clearError(delayMs: 0);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Row(
                  children: [
                    const SizedBox(width: 16),
                    Text(
                      context.l10n.auth_addAccount,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                // 登录表单容器（支持账号密码和Token两种方式）
                LoginFormContainer(
                  onLoginSuccess: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

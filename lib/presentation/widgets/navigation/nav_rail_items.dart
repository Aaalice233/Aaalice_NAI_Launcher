import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_version.dart';
import '../../themes/theme_extension.dart';
import 'github_logo.dart';
import 'nav_rail_expansion.dart';
import 'nav_rail_metrics.dart';

class NavRailToggle extends StatelessWidget {
  const NavRailToggle({
    super.key,
    required this.isExpanded,
    required this.onTap,
  });

  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = isExpanded
        ? context.l10n.nav_collapseSidebar
        : context.l10n.nav_expandSidebar;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: navRailItemMinHeight(context)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Tooltip(
                  message: label,
                  preferBelow: false,
                  verticalOffset: 24,
                  child: SizedBox(
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
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ExpandedRailContent(
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
                ExpandedRailContent(
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
    );
  }
}

/// GitHub 图标（自定义绘制）
class NavRailGitHubIcon extends StatefulWidget {
  final String url;
  final String label;

  const NavRailGitHubIcon({super.key, required this.url, required this.label});

  @override
  State<NavRailGitHubIcon> createState() => _NavRailGitHubIconState();
}

class _NavRailGitHubIconState extends State<NavRailGitHubIcon> {
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

    return NavRailLinkItem(
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

/// 外部链接图标
class NavRailExternalLinkIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String url;

  const NavRailExternalLinkIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.url,
  });

  @override
  State<NavRailExternalLinkIcon> createState() =>
      _NavRailExternalLinkIconState();
}

class _NavRailExternalLinkIconState extends State<NavRailExternalLinkIcon> {
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
    return NavRailLinkItem(
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

class NavRailLinkItem extends StatelessWidget {
  const NavRailLinkItem({
    super.key,
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
    final theme = Theme.of(context);
    final pressDuration = boundedNavRailMotionDuration(
      context,
      theme.appTheme.fastDuration,
      minMilliseconds: 100,
      maxMilliseconds: 140,
    );
    final hoverDuration = boundedNavRailMotionDuration(
      context,
      theme.appTheme.normalDuration,
      minMilliseconds: 120,
      maxMilliseconds: 180,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      constraints: BoxConstraints(minHeight: navRailItemMinHeight(context)),
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
            duration: pressDuration,
            curve: theme.appTheme.standardCurve,
            child: AnimatedContainer(
              duration: hoverDuration,
              decoration: BoxDecoration(
                color: isHovering
                    ? color.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Tooltip(
                    message: label,
                    preferBelow: false,
                    verticalOffset: 24,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(child: icon),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ExpandedRailContent(
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
    );
  }
}

class NavRailIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showBadge;
  final String? badgeLabel;
  final FocusNode? focusNode;

  const NavRailIcon({
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
  State<NavRailIcon> createState() => _NavRailIconState();
}

class _NavRailIconState extends State<NavRailIcon> {
  bool _isHovering = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pressDuration = boundedNavRailMotionDuration(
      context,
      theme.appTheme.fastDuration,
      minMilliseconds: 100,
      maxMilliseconds: 140,
    );
    final hoverDuration = boundedNavRailMotionDuration(
      context,
      theme.appTheme.normalDuration,
      minMilliseconds: 120,
      maxMilliseconds: 180,
    );
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      constraints: BoxConstraints(minHeight: navRailItemMinHeight(context)),
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
            duration: pressDuration,
            curve: theme.appTheme.standardCurve,
            child: AnimatedContainer(
              duration: hoverDuration,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Tooltip(
                    message: widget.label,
                    preferBelow: false,
                    verticalOffset: 24,
                    child: SizedBox(
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
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ExpandedRailContent(
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
    );
  }
}

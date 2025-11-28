import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';
import '../../themes/theme_extension.dart';

class MainNavRail extends ConsumerWidget {
  const MainNavRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).matchedLocation;
    final appThemeExtension = theme.extension<AppThemeExtension>();

    int selectedIndex = 0;
    if (location == AppRoutes.gallery) selectedIndex = 1;
    if (location == AppRoutes.promptConfig) selectedIndex = 2;
    if (location == AppRoutes.onlineGallery) selectedIndex = 3;
    if (location == AppRoutes.settings) selectedIndex = 5;

    return Container(
      width: 60,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Logo area or top spacer
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          
          // Navigation Items
          _NavIcon(
            icon: Icons.brush, // Canvas/Edit
            label: '画布',
            isSelected: selectedIndex == 0,
            onTap: () => context.go(AppRoutes.home),
          ),
          _NavIcon(
            icon: Icons.image, // Local Gallery
            label: '图库',
            isSelected: selectedIndex == 1,
            onTap: () => context.go(AppRoutes.gallery),
          ),

          // 在线画廊
          _NavIcon(
            icon: Icons.photo_library, // Online Gallery
            label: '画廊',
            isSelected: selectedIndex == 3,
            onTap: () => context.go(AppRoutes.onlineGallery),
          ),

          // 随机配置
          _NavIcon(
            icon: Icons.casino, // Random prompt config
            label: '随机配置',
            isSelected: selectedIndex == 2,
            onTap: () => context.go(AppRoutes.promptConfig),
          ),

          // 词库（未来功能）
          _NavIcon(
            icon: Icons.book, // Tags/Dictionary placeholder
            label: '词库 (WIP)',
            isSelected: false,
            onTap: () {}, // TODO
            isDisabled: true,
          ),

          const Spacer(),
          
          // Bottom Settings
          _NavIcon(
            icon: Icons.settings,
            label: '设置',
            isSelected: selectedIndex == 2,
            onTap: () => context.go(AppRoutes.settings),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NavIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDisabled;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isDisabled = false,
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
    final color = widget.isSelected
        ? theme.colorScheme.primary
        : (widget.isDisabled ? theme.disabledColor : theme.iconTheme.color?.withOpacity(0.7));

    // 计算背景色：选中状态优先，其次是 Hover 状态
    Color backgroundColor = Colors.transparent;
    if (widget.isSelected) {
      backgroundColor = theme.colorScheme.primary.withOpacity(0.1);
    } else if (_isHovering && !widget.isDisabled) {
      backgroundColor = theme.colorScheme.surfaceContainerHighest.withOpacity(0.5);
    }

    return Tooltip(
      message: widget.label,
      preferBelow: false,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        width: 48,
        height: 48,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isDisabled ? null : widget.onTap,
            onHover: (val) {
              if (!widget.isDisabled) {
                setState(() => _isHovering = val);
              }
            },
            onTapDown: (_) {
              if (!widget.isDisabled) {
                setState(() => _isPressed = true);
              }
            },
            onTapUp: (_) {
              if (!widget.isDisabled) {
                setState(() => _isPressed = false);
              }
            },
            onTapCancel: () {
              if (!widget.isDisabled) {
                setState(() => _isPressed = false);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: AnimatedScale(
              scale: _isPressed ? 0.92 : (_isHovering ? 1.1 : 1.0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: widget.isSelected 
                    ? Border.all(color: theme.colorScheme.primary.withOpacity(0.5), width: 1) 
                    : null,
                ),
                child: Icon(
                  widget.icon,
                  color: color,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


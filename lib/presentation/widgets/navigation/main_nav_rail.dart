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
    if (location == AppRoutes.settings) selectedIndex = 2;

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
            icon: Icons.image, // Gallery
            label: '图库',
            isSelected: selectedIndex == 1,
            onTap: () => context.go(AppRoutes.gallery),
          ),
          
          // Placeholders for future features
          _NavIcon(
            icon: Icons.cloud_download, // Danbooru placeholder
            label: 'Danbooru (WIP)',
            isSelected: false,
            onTap: () {}, // TODO
            isDisabled: true,
          ),
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

class _NavIcon extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.colorScheme.primary
        : (isDisabled ? theme.disabledColor : theme.iconTheme.color?.withOpacity(0.7));

    return Tooltip(
      message: label,
      preferBelow: false,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected 
              ? Border.all(color: theme.colorScheme.primary.withOpacity(0.5), width: 1) 
              : null,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
      ),
    );
  }
}


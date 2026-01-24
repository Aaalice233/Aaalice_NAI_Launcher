import 'dart:ui';
import 'package:flutter/material.dart';

class ProMenuItem {
  final String id;
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const ProMenuItem({
    required this.id,
    required this.label,
    this.icon,
    this.onTap,
  });
}

class ProContextMenu extends StatelessWidget {
  final Offset position;
  final List<ProMenuItem> items;
  final void Function(ProMenuItem) onSelect;

  const ProContextMenu({
    super.key,
    required this.position,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 200,
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.95),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children:
                  items.map((item) => _buildMenuItem(context, item)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, ProMenuItem item) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          item.onTap?.call();
          onSelect(item);
        },
        hoverColor: colorScheme.primary.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (item.icon != null) ...[
                Icon(
                  item.icon,
                  size: 18,
                  color: colorScheme.onSurface,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

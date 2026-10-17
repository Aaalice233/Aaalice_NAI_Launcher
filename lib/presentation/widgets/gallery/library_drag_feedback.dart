import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../themes/core/layered_surface_style.dart';

/// 资料库拖动时跟随指针的标签，多项一起拖动时显示数量
class LibraryDragFeedback extends StatelessWidget {
  const LibraryDragFeedback({
    super.key,
    required this.icon,
    required this.label,
    this.count = 1,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final chip = Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: overlaySurfaceColor(Theme.of(context).colorScheme),
      child: SizedBox(
        width: math.min(240, MediaQuery.sizeOf(context).width - 32),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (count < 2) return chip;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        chip,
        Positioned(top: -6, right: -6, child: Badge.count(count: count)),
      ],
    );
  }
}

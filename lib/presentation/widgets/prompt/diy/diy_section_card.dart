import 'package:flutter/material.dart';

import '../../common/elevated_card.dart';
import 'diy_panel_header.dart';

/// DIY 面板中的分组卡片：分组标题与所属内容在同一色面内
class DiySectionCard extends StatelessWidget {
  const DiySectionCard({
    super.key,
    required this.icon,
    required this.accent,
    required this.accentContainer,
    required this.title,
    required this.child,
    this.trailing,
    this.hoverable = false,
  });

  final IconData icon;
  final Color accent;
  final Color accentContainer;
  final String title;
  final Widget? trailing;
  final Widget child;
  final bool hoverable;

  @override
  Widget build(BuildContext context) {
    return ElevatedCard(
      elevation: CardElevation.level1,
      hoverElevation: hoverable ? CardElevation.level2 : null,
      enableHoverEffect: hoverable,
      borderRadius: 12,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DiySectionTitle(
            icon: icon,
            accent: accent,
            container: accentContainer,
            title: title,
            trailing: trailing,
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

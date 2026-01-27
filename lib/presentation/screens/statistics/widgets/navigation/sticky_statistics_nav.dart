import 'package:flutter/material.dart';
import 'dart:ui';

import 'nav_chip.dart';

/// Sticky navigation bar for statistics sections
/// Supports smooth scrolling and auto-highlighting
class StickyStatisticsNav extends StatelessWidget {
  final List<NavSection> sections;
  final int activeIndex;
  final ValueChanged<int> onSectionTap;
  final ScrollController scrollController;

  const StickyStatisticsNav({
    super.key,
    required this.sections,
    required this.activeIndex,
    required this.onSectionTap,
    required this.scrollController,
  });

  void _scrollToSection(int index) {
    final section = sections[index];
    final context = section.sectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        alignment: 0.0,
      );
    }
    onSectionTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.85),
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 16,
              vertical: 8,
            ),
            child: isMobile || isTablet
                ? _buildScrollableNav(context, isMobile)
                : _buildCenteredNav(context),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableNav(BuildContext context, bool isMobile) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: sections.length,
      separatorBuilder: (_, __) => const SizedBox(width: 4),
      itemBuilder: (context, index) {
        return NavChip(
          section: sections[index],
          isActive: activeIndex == index,
          onTap: () => _scrollToSection(index),
          compactMode: isMobile,
        );
      },
    );
  }

  Widget _buildCenteredNav(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: sections.asMap().entries.map((entry) {
            final index = entry.key;
            final section = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: NavChip(
                section: section,
                isActive: activeIndex == index,
                onTap: () => _scrollToSection(index),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Mixin to help with scroll position tracking
mixin StatisticsScrollMixin<T extends StatefulWidget> on State<T> {
  late ScrollController scrollController;
  final ValueNotifier<int> activeSection = ValueNotifier(0);
  List<GlobalKey> sectionKeys = [];

  void initScrollTracking(int sectionCount) {
    scrollController = ScrollController();
    sectionKeys = List.generate(sectionCount, (_) => GlobalKey());
    scrollController.addListener(_onScroll);
  }

  void disposeScrollTracking() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    activeSection.dispose();
  }

  void _onScroll() {
    _updateActiveSection();
  }

  void _updateActiveSection() {
    const headerOffset = 120.0; // AppBar + Nav height

    for (int i = sectionKeys.length - 1; i >= 0; i--) {
      final key = sectionKeys[i];
      final ctx = key.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox?;
        if (box != null) {
          final position = box.localToGlobal(Offset.zero);
          if (position.dy <= headerOffset + 50) {
            if (activeSection.value != i) {
              activeSection.value = i;
            }
            return;
          }
        }
      }
    }

    if (activeSection.value != 0) {
      activeSection.value = 0;
    }
  }
}

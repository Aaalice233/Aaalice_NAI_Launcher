import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/platform_capabilities.dart';
import '../../providers/generation_layout_mode_provider.dart';
import '../../providers/layout_state_provider.dart';
import '../../widgets/drop/global_drop_handler.dart';
import 'desktop_layout.dart';
import 'mobile_layout.dart';
import 'web_style_layout.dart';
import 'widgets/fixed_tags_sidebar.dart';

/// 图像生成页面
class GenerationScreen extends ConsumerWidget {
  const GenerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        // 桌面端布局 (宽度 >= 1000)
        if (constraints.maxWidth >= 1000 &&
            PlatformCapabilities.current.hasPrecisePointer) {
          final layoutMode = ref.watch(generationLayoutModeNotifierProvider);
          return layoutMode == GenerationLayoutMode.webStyle
              ? const WebStyleGenerationLayout()
              : const DesktopGenerationLayout();
        }

        final layoutState = ref.watch(layoutStateNotifierProvider);
        const mobileLayout = MobileGenerationLayout();
        if (!layoutState.fixedTagsSidebarExpanded) {
          return mobileLayout;
        }

        if (constraints.maxWidth < 900) {
          final overlayWidth = math.max(
            160.0,
            math.min(360.0, constraints.maxWidth - 48),
          );
          return Stack(
            children: [
              const Positioned.fill(child: mobileLayout),
              Positioned.fill(
                child: ModalBarrier(
                  key: const Key('generation-fixed-tags-barrier'),
                  color: Colors.black.withValues(alpha: 0.24),
                  dismissible: true,
                  onDismiss: () => ref
                      .read(layoutStateNotifierProvider.notifier)
                      .setFixedTagsSidebarExpanded(false),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                width: overlayWidth,
                child: Material(
                  key: const Key('generation-fixed-tags-overlay'),
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  elevation: 12,
                  child: const SafeArea(child: FixedTagsSidebar()),
                ),
              ),
            ],
          );
        }

        final maxSidebarWidth = (constraints.maxWidth * 0.45).clamp(
          240.0,
          400.0,
        );
        final sidebarWidth = layoutState.fixedTagsSidebarWidth
            .clamp(240.0, maxSidebarWidth)
            .toDouble();

        return Row(
          children: [
            const Expanded(child: mobileLayout),
            Container(
              width: sidebarWidth,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  left: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: const FixedTagsSidebar(),
            ),
          ],
        );
      },
    );

    if (!PlatformCapabilities.current.supportsExternalFileDrop) {
      return content;
    }
    return GlobalDropHandler(child: content);
  }
}

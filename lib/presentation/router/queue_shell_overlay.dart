import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/queue/queue_management_page.dart';

/// 队列管理面板显示状态 Provider
final queueManagementVisibleProvider = StateProvider<bool>((ref) => false);

/// 带背景遮罩、滑动动画和队列管理页面的 Shell 级队列面板。
class QueueShellOverlay extends ConsumerWidget {
  final bool isVisible;
  final bool desktop;
  final VoidCallback onQueueStarted;

  const QueueShellOverlay({
    super.key,
    required this.isVisible,
    required this.desktop,
    required this.onQueueStarted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            if (isVisible)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () =>
                      ref.read(queueManagementVisibleProvider.notifier).state =
                          false,
                  child: ColoredBox(
                    color: theme.colorScheme.scrim.withValues(
                      alpha: desktop ? 0.28 : 0.36,
                    ),
                  ),
                ),
              ),
            TweenAnimationBuilder<Offset>(
              tween: Tween(
                begin: desktop ? const Offset(1, 0) : const Offset(0, 1),
                end: isVisible
                    ? Offset.zero
                    : (desktop ? const Offset(1, 0) : const Offset(0, 1)),
              ),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, offset, child) {
                final hidden = desktop ? offset.dx >= 0.5 : offset.dy >= 0.5;
                return ExcludeSemantics(
                  excluding: hidden,
                  child: IgnorePointer(
                    ignoring: hidden,
                    child: FractionalTranslation(
                      translation: offset,
                      child: child,
                    ),
                  ),
                );
              },
              child: Align(
                alignment: desktop
                    ? Alignment.centerRight
                    : Alignment.bottomCenter,
                child: SizedBox(
                  width: desktop ? 460 : constraints.maxWidth,
                  child: Material(
                    color: theme.scaffoldBackgroundColor,
                    elevation: 18,
                    shadowColor: Colors.black.withValues(alpha: 0.28),
                    borderRadius: desktop
                        ? const BorderRadius.horizontal(
                            left: Radius.circular(16),
                          )
                        : const BorderRadius.vertical(top: Radius.circular(16)),
                    clipBehavior: Clip.antiAlias,
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        height: desktop
                            ? constraints.maxHeight
                            : constraints.maxHeight * 0.85,
                        child: QueueManagementPage(
                          onClose: () =>
                              ref
                                      .read(
                                        queueManagementVisibleProvider.notifier,
                                      )
                                      .state =
                                  false,
                          onQueueStarted: onQueueStarted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

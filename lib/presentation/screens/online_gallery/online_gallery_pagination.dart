import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/online_gallery_provider.dart';
import '../../widgets/common/themed_input.dart';
import 'online_gallery_screen_controller.dart';

class OnlineGalleryPagination extends StatelessWidget {
  const OnlineGalleryPagination({
    super.key,
    required this.state,
    required this.controller,
    required this.notifier,
    required this.onGoToPage,
  });

  final OnlineGalleryState state;
  final OnlineGalleryScreenController controller;
  final OnlineGalleryNotifier notifier;
  final Future<void> Function(int page) onGoToPage;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildBar(context),
    );
  }

  Widget _buildBar(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 400;
    if (state.randomEnabled) {
      return Container(
        key: const ValueKey('online-gallery-random-status-bar'),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (state.isLoading || state.isLoadingMore) ...[
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(context.l10n.onlineGallery_randomDrawing),
            ] else if (state.randomSession.exhausted) ...[
              Text(context.l10n.onlineGallery_randomExhausted),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: notifier.restartRandom,
                icon: const Icon(Icons.replay, size: 18),
                label: Text(context.l10n.onlineGallery_randomRestart),
              ),
            ] else
              Text(context.l10n.onlineGallery_imageCount(state.posts.length)),
          ],
        ),
      );
    }
    if (state.posts.isEmpty && !state.isLoading && !state.hasMore) {
      return const SizedBox.shrink();
    }

    return Container(
      key: const ValueKey('online-gallery-pagination-bar'),
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: state.page > 1 ? () => onGoToPage(state.page - 1) : null,
            icon: const Icon(Icons.chevron_left, size: 24),
            tooltip: context.l10n.onlineGallery_previousPage,
          ),
          SizedBox(width: isCompact ? 4 : 8),
          controller.isEditingPage
              ? _buildPageInput(context, theme)
              : _buildPageDisplay(context, theme),
          SizedBox(width: isCompact ? 4 : 8),
          IconButton(
            onPressed:
                (state.currentCache.boundaryForPage(state.page + 1) != null ||
                    state.hasMore)
                ? () => onGoToPage(state.page + 1)
                : null,
            icon: const Icon(Icons.chevron_right, size: 24),
            tooltip: context.l10n.onlineGallery_nextPage,
          ),
          SizedBox(width: isCompact ? 12 : 24),
          if (isCompact)
            Tooltip(
              message: context.l10n.onlineGallery_imageCount(
                state.posts.length.toString(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    state.posts.length.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              context.l10n.onlineGallery_imageCount(
                state.posts.length.toString(),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageDisplay(BuildContext context, ThemeData theme) {
    return InkWell(
      onTap: () => controller.beginPageEditing(state.page),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.onlineGallery_pageN(state.page.toString()),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit,
              size: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageInput(BuildContext context, ThemeData theme) {
    return SizedBox(
      width: 80,
      child: ThemedInput(
        controller: controller.pageController,
        focusNode: controller.pageFocusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5),
        ],
        onSubmitted: (_) {
          final page = controller.finishPageEditing();
          if (page != null && page != state.page) onGoToPage(page);
        },
      ),
    );
  }
}
